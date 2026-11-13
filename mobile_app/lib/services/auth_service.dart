import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._() {
    _initLocalSession();
  }
  static final AuthService instance = AuthService._();

  FirebaseAuth? get _auth {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  String? _localDisplayName;
  String? _localEmail;
  bool _isLocalLoggedIn = false;
  String _partnerTier = 'Free';
  final ValueNotifier<String> partnerTierNotifier = ValueNotifier<String>('Free');

  String get partnerTier => _partnerTier;
  bool get isPartner => _partnerTier != 'Free' && _partnerTier.trim().isNotEmpty;

  Future<void> setPartnerTier(String tier) async {
    final cleanTier = tier.trim();
    _partnerTier = cleanTier;
    partnerTierNotifier.value = cleanTier;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_partner_tier', cleanTier);
    } catch (_) {}
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _localDisplayName = prefs.getString('auth_user_name');
      _localEmail = prefs.getString('auth_user_email');
      _isLocalLoggedIn = prefs.getBool('auth_is_logged_in') ?? false;
      _partnerTier = prefs.getString('auth_partner_tier') ?? 'Free';
      partnerTierNotifier.value = _partnerTier;

      // Sync active Firebase user if present
      final fbUser = currentUser;
      if (fbUser != null) {
        _isLocalLoggedIn = true;
        await prefs.setBool('auth_is_logged_in', true);
        if (fbUser.displayName != null && fbUser.displayName!.trim().isNotEmpty) {
          _localDisplayName = fbUser.displayName!.trim();
          await prefs.setString('auth_user_name', _localDisplayName!);
        }
        if (fbUser.email != null && fbUser.email!.trim().isNotEmpty) {
          _localEmail = fbUser.email!.trim();
          await prefs.setString('auth_user_email', _localEmail!);
        }
      }
    } catch (e) {
      debugPrint("AuthService init error: $e");
    }
  }

  Future<void> _initLocalSession() async {
    await init();
  }

  User? get currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  String get currentDisplayName {
    final fbName = currentUser?.displayName;
    if (fbName != null && fbName.trim().isNotEmpty) return fbName.trim();
    if (_localDisplayName != null && _localDisplayName!.trim().isNotEmpty) return _localDisplayName!.trim();
    final email = currentEmail;
    if (email.contains('@')) {
      final handle = email.split('@').first;
      if (handle.isNotEmpty) {
        return handle[0].toUpperCase() + handle.substring(1);
      }
    }
    return 'Beloved';
  }

  String get currentEmail {
    final fbEmail = currentUser?.email;
    if (fbEmail != null && fbEmail.trim().isNotEmpty) return fbEmail.trim();
    if (_localEmail != null && _localEmail!.trim().isNotEmpty) return _localEmail!.trim();
    return '';
  }

  bool get isLoggedIn {
    if (currentUser != null) return true;
    return _isLocalLoggedIn;
  }

  Stream<User?> get authStateChanges {
    try {
      return _auth?.authStateChanges() ?? Stream.value(null);
    } catch (_) {
      return Stream.value(null);
    }
  }

  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();

    if (_auth != null) {
      final cred = await _auth!.signInWithEmailAndPassword(email: cleanEmail, password: cleanPassword);
      await _saveSession(name: cred.user?.displayName, email: cleanEmail);
      return cred;
    }

    // Desktop / Fallback mode
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }
    if (cleanPassword.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    await _saveSession(email: cleanEmail);
    return null;
  }

  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password, {String? displayName}) async {
    final cleanEmail = email.trim();
    final cleanPassword = password.trim();
    final cleanName = displayName?.trim();

    if (_auth != null) {
      final cred = await _auth!.createUserWithEmailAndPassword(email: cleanEmail, password: cleanPassword);
      if (cleanName != null && cleanName.isNotEmpty) {
        await cred.user?.updateDisplayName(cleanName);
        await cred.user?.reload();
      }
      await _saveSession(name: cleanName, email: cleanEmail);
      return cred;
    }

    // Desktop / Fallback mode
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }
    if (cleanPassword.length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    await _saveSession(name: cleanName, email: cleanEmail);
    return null;
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (_auth == null) {
      // On desktop, prompt user to use Email login
      throw const FormatException('Google Sign-In is available on mobile. On desktop, please sign in with your email.');
    }
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth!.signInWithCredential(credential);
      await _saveSession(name: cred.user?.displayName, email: cred.user?.email);
      return cred;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim();
    if (_auth != null) {
      await _auth!.sendPasswordResetEmail(email: cleanEmail);
      return;
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }
    // Succeeded for desktop local flow
  }

  Future<void> _saveSession({String? name, String? email}) async {
    if (name != null && name.trim().isNotEmpty) {
      _localDisplayName = name.trim();
    }
    if (email != null && email.trim().isNotEmpty) {
      _localEmail = email.trim();
    }
    _isLocalLoggedIn = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_localDisplayName != null && _localDisplayName!.isNotEmpty) {
        await prefs.setString('auth_user_name', _localDisplayName!);
      }
      if (_localEmail != null && _localEmail!.isNotEmpty) {
        await prefs.setString('auth_user_email', _localEmail!);
      }
      await prefs.setBool('auth_is_logged_in', true);
      await prefs.setBool('has_onboarded', true);
      await prefs.setBool('guest_mode', false);
    } catch (_) {}
  }

  Future<void> signOut() async {
    _isLocalLoggedIn = false;
    _localDisplayName = null;
    _localEmail = null;
    _partnerTier = 'Free';
    partnerTierNotifier.value = 'Free';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_user_name');
      await prefs.remove('auth_user_email');
      await prefs.remove('auth_partner_tier');
      await prefs.setBool('auth_is_logged_in', false);
      await prefs.remove('auth_is_logged_in');
      await prefs.setBool('guest_mode', false);
    } catch (_) {}

    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    if (_auth != null) {
      try {
        await _auth!.signOut();
      } catch (_) {}
    }
  }
}

