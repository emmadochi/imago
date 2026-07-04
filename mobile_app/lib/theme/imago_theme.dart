// ─────────────────────────────────────────────────────────────
// Imago Brand Design System
// Source of truth for all colors, text styles and shared painters
// ─────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Palette (from INSPIRE.png) ─────────────────────────────
class ImagoColors {
  ImagoColors._();

  static const deepSpace   = Color(0xFF0B132B);
  static const nebula      = Color(0xFF1B1147);
  static const violet      = Color(0xFF3D5AFE);
  static const gold        = Color(0xFFFFC857);
  static const cream       = Color(0xFFFFF3D6);

  static const bgGradient  = LinearGradient(
    begin: Alignment.topCenter,
    end:   Alignment.bottomCenter,
    colors: [Color(0xFF0B132B), Color(0xFF1B1147), Color(0xFF0B132B)],
    stops:  [0.0, 0.55, 1.0],
  );

  static const goldGradient = LinearGradient(
    colors: [gold, cream, gold],
    stops:  [0.0, 0.5, 1.0],
  );

  static const violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end:   Alignment.bottomRight,
    colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
  );
}

// ── Text Styles ───────────────────────────────────────────
class ImagoText {
  ImagoText._();

  /// Used for "IMAGO" hero wordmark (Cinzel Semibold)
  static TextStyle wordmark({double size = 38}) => TextStyle(
    fontFamily: 'Cinzel',
    fontSize:    size,
    fontWeight:  FontWeight.w700,
    letterSpacing: 8,
    foreground: Paint()
      ..shader = const LinearGradient(
        colors: [ImagoColors.gold, ImagoColors.cream, ImagoColors.gold],
        stops:  [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size * 5, size)),
  );

  static TextStyle tagline({double size = 13}) => TextStyle(
    fontFamily: 'Poppins',
    fontSize:    size,
    fontWeight:  FontWeight.w300,
    color:       ImagoColors.cream.withOpacity(0.55),
    letterSpacing: 0.4,
    height: 1.5,
  );

  static const body = TextStyle(
    fontFamily: 'Poppins',
    color:      Colors.white,
    fontSize:   15,
    height:     1.45,
  );

  static TextStyle label({double size = 13, FontWeight weight = FontWeight.w500}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: Colors.white);
}

// ── Custom Painter: 3-Petal Glowing Lotus Logo ─────────────
class ImagoLogoPainter extends CustomPainter {
  final double glowPulse; // 0.0 → 1.0 for animated glow
  const ImagoLogoPainter({this.glowPulse = 0.5});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.36;

    // ── Outer glow halos ─────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final angle = (i * 120) * math.pi / 180;
      final ox = cx + r * 0.55 * math.cos(angle);
      final oy = cy + r * 0.55 * math.sin(angle);
      final haloPaint = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22)
        ..color = const Color(0xFF5C6BC0).withOpacity(0.28 + glowPulse * 0.12);
      canvas.drawCircle(Offset(ox, oy), r * 0.82, haloPaint);
    }

    // ── Three translucent petals ──────────────────────────
    final petalPaint = Paint()
      ..style       = PaintingStyle.fill
      ..color       = const Color(0xFF7986CB).withOpacity(0.28);
    final petalBorder = Paint()
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color       = const Color(0xFF9FA8DA).withOpacity(0.55);

    for (int i = 0; i < 3; i++) {
      final angle = (i * 120 - 90) * math.pi / 180;
      final ox = cx + r * 0.52 * math.cos(angle);
      final oy = cy + r * 0.52 * math.sin(angle);
      canvas.drawCircle(Offset(ox, oy), r * 0.78, petalPaint);
      canvas.drawCircle(Offset(ox, oy), r * 0.78, petalBorder);
    }

    // ── Centre star / divine light ────────────────────────
    // Soft core glow
    final coreGlow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18)
      ..color      = ImagoColors.gold.withOpacity(0.7 + glowPulse * 0.3);
    canvas.drawCircle(Offset(cx, cy), r * 0.25, coreGlow);

    // 4-pointed star
    final starPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = ImagoColors.cream;

    final starPath = Path();
    const pts = 8;
    for (int i = 0; i < pts; i++) {
      final a = (i * 360 / pts - 90) * math.pi / 180;
      final rad = (i.isEven) ? r * 0.22 : r * 0.09;
      final x = cx + rad * math.cos(a);
      final y = cy + rad * math.sin(a);
      if (i == 0) starPath.moveTo(x, y); else starPath.lineTo(x, y);
    }
    starPath.close();
    canvas.drawPath(starPath, starPaint);

    // Bright centre dot
    canvas.drawCircle(
      Offset(cx, cy), r * 0.07,
      Paint()..color = ImagoColors.cream,
    );
  }

  @override
  bool shouldRepaint(ImagoLogoPainter old) => old.glowPulse != glowPulse;
}

// ── Shared: Cosmic Background ─────────────────────────────
class CosmicBackground extends StatelessWidget {
  final List<Widget> children;
  const CosmicBackground({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: ImagoColors.bgGradient),
      child: Stack(children: children),
    );
  }
}

// ── Shared: Floating orb accent ───────────────────────────
class CosmicOrb extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;
  const CosmicOrb({
    super.key,
    required this.size,
    required this.color,
    this.opacity = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(opacity),
      ),
    );
  }
}
