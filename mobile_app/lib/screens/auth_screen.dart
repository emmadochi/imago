import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/imago_theme.dart';
import '../services/auth_service.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AnimationController _levitationController;
  late final Animation<double> _levitationAnimation;

  @override
  void initState() {
    super.initState();
    _levitationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _levitationAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _levitationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _levitationController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    try {
      final cred = await AuthService.instance.signInWithGoogle();
      if (cred != null) {
        _navigate();
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } on FormatException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage =
          'Google Sign-In failed. Please sign in with email and password.');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _submitEmailPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await AuthService.instance.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await AuthService.instance.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          displayName: _nameController.text.trim(),
        );
      }
      _navigate();
    } on FirebaseAuthException catch (e) {
      setState(() => _errorMessage = _friendlyError(e.code));
    } on FormatException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'weak-password':
        return 'Your password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using a different sign-in method.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _openForgotPasswordSheet(BuildContext context) {
    final resetEmailCtrl = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;
    String? resetError;
    bool isSent = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0F1226).withValues(alpha: 0.96),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 16,
                bottom: bottomInset + 28,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isSent) ...[
                      // Success View
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_email_read_rounded,
                          color: Color(0xFF10B981),
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Check Your Email',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We have sent password reset instructions to:\n${resetEmailCtrl.text.trim()}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you don\'t see the email within a couple of minutes, please check your spam or junk folder.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.45),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 26),
                      GestureDetector(
                        onTap: () => Navigator.pop(sheetContext),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text(
                              'Done',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Form View
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF3D5AFE).withValues(alpha: 0.15),
                          border: Border.all(color: const Color(0xFF3D5AFE).withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3D5AFE).withValues(alpha: 0.25),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your registered email address and we will send you a link to reset your password.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),

                      if (resetError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  resetError!,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.redAccent,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      TextField(
                        controller: resetEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                          hintText: 'Enter your email address',
                          hintStyle: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      GestureDetector(
                        onTap: isSubmitting
                            ? null
                            : () async {
                                final email = resetEmailCtrl.text.trim();
                                if (email.isEmpty) {
                                  setSheetState(() => resetError = 'Please enter your email address.');
                                  return;
                                }
                                if (!email.contains('@') || !email.contains('.')) {
                                  setSheetState(() => resetError = 'Please enter a valid email address.');
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                  resetError = null;
                                });

                                try {
                                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                  setSheetState(() {
                                    isSubmitting = false;
                                    isSent = true;
                                  });
                                } on FirebaseAuthException catch (e) {
                                  String msg = e.message ?? e.code;
                                  if (e.code == 'user-not-found') {
                                    msg = 'No account found with this email.';
                                  } else if (e.code == 'invalid-email') {
                                    msg = 'Please enter a valid email address.';
                                  } else if (e.code == 'too-many-requests') {
                                    msg = 'Too many attempts. Please try again in a few minutes.';
                                  }
                                  setSheetState(() {
                                    isSubmitting = false;
                                    resetError = msg;
                                  });
                                } catch (e) {
                                  setSheetState(() {
                                    isSubmitting = false;
                                    resetError = 'Failed to send reset link. Please check your connection.';
                                  });
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3D5AFE).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const CosmicBackground(children: []),

          // Top ambient glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5C6BC0).withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: SizedBox.shrink(),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: ImagoColors.gold.withOpacity(0.07),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    children: [
                      SizedBox(height: 30),

                      // Levitating logo
                      AnimatedBuilder(
                        animation: _levitationAnimation,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(0, _levitationAnimation.value),
                          child: child,
                        ),
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3D5AFE).withOpacity(0.5),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(Icons.church_rounded,
                              color: Colors.white, size: 32),
                        ),
                      ),

                      SizedBox(height: 20),

                      Text(
                        _isLogin ? 'Welcome Back' : 'Create Account',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      SizedBox(height: 6),

                      Text(
                        _isLogin
                            ? 'Continue your spiritual journey'
                            : 'Begin your journey with yo-ETS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 14,
                        ),
                      ),

                      SizedBox(height: 28),

                      // ── Google Sign-In Button ──
                      GestureDetector(
                        onTap: _isGoogleLoading ? null : _signInWithGoogle,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.white.withOpacity(0.12)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: _isGoogleLoading
                                  ? Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Google G logo built from colored blocks
                                        _GoogleIcon(),
                                        SizedBox(width: 10),
                                        Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 18),

                      // ── Divider ──
                      Row(
                        children: [
                          Expanded(
                              child: Divider(color: Colors.white.withOpacity(0.1))),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'or continue with email',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white.withOpacity(0.3),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(color: Colors.white.withOpacity(0.1))),
                        ],
                      ),

                      SizedBox(height: 18),

                      // ── Email / Password form ──
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(28),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    if (!_isLogin) ...[
                                      _buildField(
                                        controller: _nameController,
                                        hint: 'Your full name',
                                        icon: Icons.person_outline_rounded,
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Please enter your name'
                                                : null,
                                      ),
                                      SizedBox(height: 14),
                                    ],

                                    _buildField(
                                      controller: _emailController,
                                      hint: 'Email address',
                                      icon: Icons.mail_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) =>
                                          v == null || !v.contains('@')
                                              ? 'Enter a valid email'
                                              : null,
                                    ),

                                    SizedBox(height: 14),

                                    _buildField(
                                      controller: _passwordController,
                                      hint: 'Password',
                                      icon: Icons.lock_outline_rounded,
                                      obscure: _obscurePassword,
                                      suffixIcon: GestureDetector(
                                        onTap: () => setState(() =>
                                            _obscurePassword = !_obscurePassword),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.white38,
                                          size: 20,
                                        ),
                                      ),
                                      validator: (v) => v == null || v.length < 6
                                          ? 'Minimum 6 characters'
                                          : null,
                                    ),

                                    if (_isLogin) ...[
                                      const SizedBox(height: 6),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () => _openForgotPasswordSheet(context),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              color: Color(0xFF7986CB),
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],

                                    // Error banner
                                    if (_errorMessage != null) ...[
                                      SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                              color: Colors.redAccent
                                                  .withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded,
                                                color: Colors.redAccent, size: 18),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                _errorMessage!,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: Colors.redAccent,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    SizedBox(height: 24),

                                    // Submit button
                                    GestureDetector(
                                      onTap:
                                          _isLoading ? null : _submitEmailPassword,
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 18),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF5C6BC0),
                                              Color(0xFF3D5AFE)
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(22),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFF3D5AFE)
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _isLoading
                                              ? SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              : Text(
                                                  _isLogin
                                                      ? 'Sign In'
                                                      : 'Create Account',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Toggle login/register
                      GestureDetector(
                        onTap: () => setState(() {
                          _isLogin = !_isLogin;
                          _errorMessage = null;
                        }),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 14,
                            ),
                            children: [
                              TextSpan(
                                text: _isLogin
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                              ),
                              TextSpan(
                                text: _isLogin ? 'Register' : 'Sign In',
                                style: TextStyle(
                                  color: ImagoColors.gold,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 16),

                      // SHA-1 reminder (dev only note)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.amber.withOpacity(0.15)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: Colors.amber, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'For Google Sign-In on a physical device, add your SHA-1 fingerprint in Firebase Console → Project Settings → Your Android app.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.amber.withOpacity(0.7),
                                  fontSize: 11.5,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.3)),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: Color(0xFF5C6BC0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
        ),
        errorStyle: TextStyle(fontFamily: 'Poppins', color: Colors.redAccent, fontSize: 11.5),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      ),
    );
  }
}

// Custom Google G icon widget (no external image asset needed)
class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw a stylized letter G with quadrant colors
    final paintBlue = Paint()..color = const Color(0xFF4285F4);
    final paintRed = Paint()..color = const Color(0xFFEA4335);
    final paintYellow = Paint()..color = const Color(0xFFFBBC05);
    final paintGreen = Paint()..color = const Color(0xFF34A853);

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14 / 2,
        3.14 / 2,
        false,
        paintBlue..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14 / 2 * 0,
        3.14 / 2,
        false,
        paintGreen..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14 / 2,
        3.14 / 2,
        false,
        paintYellow..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18);
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        3.14,
        3.14 / 2,
        false,
        paintRed..style = PaintingStyle.stroke..strokeWidth = size.width * 0.18);

    // G horizontal bar (blue)
    canvas.drawRect(
      Rect.fromLTWH(center.dx, center.dy - size.height * 0.1,
          radius * 0.9, size.height * 0.2),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
