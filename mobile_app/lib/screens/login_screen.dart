import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/imago_theme.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onContinue;
  const LoginScreen({super.key, required this.onContinue});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _isSignUp = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await AuthService.instance.signUpWithEmailAndPassword(email, password);
      } else {
        await AuthService.instance.signInWithEmailAndPassword(email, password);
      }
      widget.onContinue();
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? e.code;
      if (e.code == 'user-not-found') {
        msg = 'No account found with this email. Please click "Create Account".';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Incorrect email or password. Please check your credentials or click "Create Account".';
      } else if (e.code == 'email-already-in-use') {
        msg = 'An account already exists with this email. Please click "Sign In".';
      } else if (e.code == 'operation-not-allowed') {
        msg = 'Email/Password sign-in is disabled in Firebase Console.';
      } else if (e.code == 'invalid-email') {
        msg = 'Please enter a valid email address.';
      } else if (e.code == 'weak-password') {
        msg = 'Password should be at least 6 characters.';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      String errStr = e.toString();
      if (errStr.contains('Null check operator')) {
        errStr = 'Account not found or invalid credentials. If you don\'t have an account, click "Create Account".';
      }
      setState(() => _errorMessage = errStr.replaceAll('Exception:', '').trim());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitGoogleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cred = await AuthService.instance.signInWithGoogle();
      if (cred != null) {
        widget.onContinue();
      }
    } catch (e) {
      String errStr = e.toString();
      if (errStr.contains('10') || errStr.contains('ApiException')) {
        errStr = 'Google Sign-In requires SHA-1 fingerprint added in Firebase Console.';
      } else {
        errStr = 'Google Sign-In failed. Please try again or use Email sign in.';
      }
      setState(() => _errorMessage = errStr);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const CosmicBackground(children: []),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App Logo & Title
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF3D5AFE).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF3D5AFE).withOpacity(0.4)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF3D5AFE).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.church_rounded, color: Colors.white, size: 36),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'yo-ETS',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Your Intelligent Digital Ministry Platform',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Glassmorphic Auth Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                // Tab selector Sign In vs Sign Up
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isSignUp = false),
                                        child: Column(
                                          children: [
                                            Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.bold,
                                                color: !_isSignUp ? Colors.white : Colors.white38,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 2,
                                              color: !_isSignUp ? const Color(0xFF3D5AFE) : Colors.transparent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() => _isSignUp = true),
                                        child: Column(
                                          children: [
                                            Text(
                                              'Create Account',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontWeight: FontWeight.bold,
                                                color: _isSignUp ? Colors.white : Colors.white38,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              height: 2,
                                              color: _isSignUp ? const Color(0xFF3D5AFE) : Colors.transparent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(fontFamily: 'Poppins', color: Colors.redAccent, fontSize: 12.5),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Email input
                                TextField(
                                  controller: _emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.white54, size: 20),
                                    hintText: 'Email address',
                                    hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.35), fontSize: 14),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
                                ),

                                const SizedBox(height: 14),

                                // Password input
                                TextField(
                                  controller: _passwordCtrl,
                                  obscureText: true,
                                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white54, size: 20),
                                    hintText: 'Password',
                                    hintStyle: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.35), fontSize: 14),
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.05),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Email Submit Button
                                GestureDetector(
                                  onTap: _isLoading ? null : _submitEmailAuth,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)]),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(color: const Color(0xFF3D5AFE).withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6)),
                                      ],
                                    ),
                                    child: Center(
                                      child: _isLoading
                                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                          : Text(
                                              _isSignUp ? 'Sign Up' : 'Sign In',
                                              style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                            ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Or divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        'OR',
                                        style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.35), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.white.withOpacity(0.15))),
                                  ],
                                ),

                                const SizedBox(height: 18),

                                // Google Sign-In Button
                                GestureDetector(
                                  onTap: _isLoading ? null : _submitGoogleAuth,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.network(
                                          'https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg',
                                          height: 18,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Continue with Google',
                                          style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Skip for now (Guest mode option)
                    TextButton(
                      onPressed: widget.onContinue,
                      child: Text(
                        'Continue as Guest',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13.5,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
