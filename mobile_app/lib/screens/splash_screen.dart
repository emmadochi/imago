import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/imago_theme.dart';
import 'onboarding_screen.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _levitateCtrl;
  late final AnimationController _fadeCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _dotCtrl;

  late final Animation<double> _levitate;
  late final Animation<double> _fade;
  late final Animation<double> _glow;
  late final Animation<double> _dotScale;

  @override
  void initState() {
    super.initState();

    _levitateCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    )..forward();

    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _dotCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _levitate  = Tween<double>(begin: -12, end: 12).animate(
        CurvedAnimation(parent: _levitateCtrl, curve: Curves.easeInOut));
    _fade      = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _glow      = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    _dotScale  = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _dotCtrl, curve: Curves.easeInOut));

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final hasOnboarded = prefs.getBool('has_onboarded') ?? false;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => hasOnboarded ? const MainShell() : const OnboardingScreen(),
    ));
  }

  @override
  void dispose() {
    _levitateCtrl.dispose();
    _fadeCtrl.dispose();
    _glowCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      body: CosmicBackground(children: [
        // ── Ambient orbs ──────────────────────────────────
        Positioned(top: -w * 0.35, left: -w * 0.2,
          child: const CosmicOrb(size: 340, color: Color(0xFF3D5AFE), opacity: 0.13)),
        Positioned(bottom: h * 0.08, right: -w * 0.25,
          child: const CosmicOrb(size: 300, color: Color(0xFF7C4DFF), opacity: 0.11)),
        Positioned(top: h * 0.35, left: w * 0.15,
          child: const CosmicOrb(size: 180, color: ImagoColors.gold, opacity: 0.04)),

        // ── Floating small orbs (decorative) ──────────────
        ..._buildFloatingOrbs(w, h),

        // ── Main content ──────────────────────────────────
        SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glowing lotus logo
                      AnimatedBuilder(
                        animation: Listenable.merge([_levitate, _glow]),
                        builder: (_, __) => Transform.translate(
                          offset: Offset(0, _levitate.value),
                          child: SizedBox(
                            width: 160,
                            height: 160,
                            child: CustomPaint(
                              painter: ImagoLogoPainter(glowPulse: _glow.value),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // IMAGO wordmark
                      Text('IMAGO', style: ImagoText.wordmark(size: 40)),

                      const SizedBox(height: 10),

                      // Tagline (2 lines like INSPIRE.png)
                      Text(
                        'Bringing out the best in you and\nmaking you discover the God in you',
                        textAlign: TextAlign.center,
                        style: ImagoText.tagline(size: 13),
                      ),
                    ],
                  ),
                ),

                // Bottom loading indicator
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _dotScale,
                        builder: (_, __) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(3, (i) {
                            final delay = i / 3.0;
                            final scale = ((_dotCtrl.value - delay).abs() < 0.33)
                                ? 0.5 + _dotScale.value * 0.5
                                : 0.5;
                            return Container(
                              width: 7 * scale.clamp(0.5, 1.0),
                              height: 7 * scale.clamp(0.5, 1.0),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: ImagoColors.gold.withOpacity(0.4 + 0.5 * scale.clamp(0.0, 1.0)),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  List<Widget> _buildFloatingOrbs(double w, double h) {
    final orbs = [
      [0.08, 0.22, 45.0, 0.18],
      [0.75, 0.18, 35.0, 0.14],
      [0.12, 0.65, 28.0, 0.16],
      [0.80, 0.55, 50.0, 0.12],
      [0.45, 0.12, 22.0, 0.20],
      [0.55, 0.80, 38.0, 0.13],
    ];
    return orbs.map((o) {
      return Positioned(
        left:   w * o[0],
        top:    h * o[1],
        child: Container(
          width:  o[2],
          height: o[2],
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF7986CB).withOpacity(o[3]), width: 1.2),
          ),
        ),
      );
    }).toList();
  }
}
