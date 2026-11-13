// ─────────────────────────────────────────────────────────────
// Imago Brand Design System
// Source of truth for all colors, text styles and shared painters
// ─────────────────────────────────────────────────────────────
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ── Palette (from INSPIRE.png) ─────────────────────────────
enum AppThemeMode { violet, gold, azure }

final ValueNotifier<AppThemeMode> appThemeNotifier = ValueNotifier(AppThemeMode.violet);

// ── Reader Day / Night / Sepia Themes ────────────────────────
enum ReaderThemeMode {
  night,     // Celestial Midnight (Dark)
  parchment, // Sacred Papyrus (Sepia)
  day,       // Alabaster Linen (Light)
}

class ReaderTheme {
  final ReaderThemeMode mode;
  final String label;
  final String description;
  final Color background;
  final Color surface;
  final Color primaryText;
  final Color secondaryText;
  final Color verseNumberColor;
  final Color accentColor;
  final Color borderColor;
  final Color cardBackground;
  final bool isDark;
  final IconData icon;

  const ReaderTheme({
    required this.mode,
    required this.label,
    required this.description,
    required this.background,
    required this.surface,
    required this.primaryText,
    required this.secondaryText,
    required this.verseNumberColor,
    required this.accentColor,
    required this.borderColor,
    required this.cardBackground,
    required this.isDark,
    required this.icon,
  });

  static const ReaderTheme night = ReaderTheme(
    mode: ReaderThemeMode.night,
    label: 'Midnight',
    description: 'Celestial Dark',
    background: Color(0xFF0B132B),
    surface: Color(0xFF0E0B24),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: Color(0xFF94A3B8),
    verseNumberColor: Color(0xFFFFC857),
    accentColor: Color(0xFF3D5AFE),
    borderColor: Color(0xFF1E293B),
    cardBackground: Color(0xFF131D33),
    isDark: true,
    icon: Icons.dark_mode_rounded,
  );

  static const ReaderTheme parchment = ReaderTheme(
    mode: ReaderThemeMode.parchment,
    label: 'Parchment',
    description: 'Sacred Papyrus',
    background: Color(0xFFF7F2E7),
    surface: Color(0xFFFFFDF8),
    primaryText: Color(0xFF2C241D),
    secondaryText: Color(0xFF6B5E54),
    verseNumberColor: Color(0xFF9A6B2F),
    accentColor: Color(0xFF9A6B2F),
    borderColor: Color(0xFFE5DAC6),
    cardBackground: Color(0xFFFFFDF8),
    isDark: false,
    icon: Icons.auto_stories_rounded,
  );

  static const ReaderTheme day = ReaderTheme(
    mode: ReaderThemeMode.day,
    label: 'Alabaster',
    description: 'Clean White / Light',
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    primaryText: Color(0xFF0F172A),
    secondaryText: Color(0xFF475569),
    verseNumberColor: Color(0xFF2563EB),
    accentColor: Color(0xFF4F46E5),
    borderColor: Color(0xFFE2E8F0),
    cardBackground: Color(0xFFFFFFFF),
    isDark: false,
    icon: Icons.light_mode_rounded,
  );

  static ReaderTheme get current => of(readerThemeNotifier.value);

  static ReaderTheme of(ReaderThemeMode mode) {
    switch (mode) {
      case ReaderThemeMode.parchment:
        return parchment;
      case ReaderThemeMode.day:
        return day;
      case ReaderThemeMode.night:
      default:
        return night;
    }
  }

  static ReaderTheme fromString(String? key) {
    switch (key?.toLowerCase()) {
      case 'parchment':
      case 'sepia':
        return parchment;
      case 'day':
      case 'light':
        return day;
      case 'night':
      case 'dark':
      default:
        return night;
    }
  }
}

final ValueNotifier<ReaderThemeMode> readerThemeNotifier = ValueNotifier(ReaderThemeMode.night);

class ImagoColors {
  ImagoColors._();

  static bool get isDark => ReaderTheme.current.isDark;

  static Color get deepSpace => ReaderTheme.current.background;
  static Color get surface => ReaderTheme.current.surface;
  static Color get primaryText => ReaderTheme.current.primaryText;
  static Color get secondaryText => ReaderTheme.current.secondaryText;
  static Color get cardBackground => ReaderTheme.current.cardBackground;
  static Color get borderColor => ReaderTheme.current.borderColor;
  static Color get accent => ReaderTheme.current.accentColor;
  
  static Color get nebula {
    if (!isDark) return ReaderTheme.current.surface;
    switch (appThemeNotifier.value) {
      case AppThemeMode.gold: return const Color(0xFF2A1F1D);
      case AppThemeMode.azure: return const Color(0xFF0D1B2A);
      default: return const Color(0xFF1B1147);
    }
  }

  static Color get violet {
    if (!isDark) return ReaderTheme.current.accentColor;
    switch (appThemeNotifier.value) {
      case AppThemeMode.gold: return const Color(0xFFD4AF37);
      case AppThemeMode.azure: return const Color(0xFF00B4D8);
      default: return const Color(0xFF3D5AFE);
    }
  }

  static Color get gold {
    if (!isDark) return ReaderTheme.current.verseNumberColor;
    return appThemeNotifier.value == AppThemeMode.gold ? const Color(0xFFFFD700) : const Color(0xFFFFC857);
  }

  static Color get cream {
    if (!isDark) return ReaderTheme.current.primaryText;
    return appThemeNotifier.value == AppThemeMode.azure ? const Color(0xFFE0FBFC) : const Color(0xFFFFF3D6);
  }

  static LinearGradient get bgGradient {
    switch (readerThemeNotifier.value) {
      case ReaderThemeMode.parchment:
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFAF6EE), Color(0xFFF2ECE0), Color(0xFFFAF6EE)],
          stops: [0.0, 0.55, 1.0],
        );
      case ReaderThemeMode.day:
        return const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC), Color(0xFFF8FAFC)],
          stops: [0.0, 0.55, 1.0],
        );
      case ReaderThemeMode.night:
      default:
        switch (appThemeNotifier.value) {
          case AppThemeMode.gold:
            return const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF1A1210), Color(0xFF2A1F1D), Color(0xFF1A1210)],
              stops: [0.0, 0.55, 1.0],
            );
          case AppThemeMode.azure:
            return const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF040A18), Color(0xFF0D1B2A), Color(0xFF040A18)],
              stops: [0.0, 0.55, 1.0],
            );
          default:
            return const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF0B132B), Color(0xFF1B1147), Color(0xFF0B132B)],
              stops: [0.0, 0.55, 1.0],
            );
        }
    }
  }

  static LinearGradient get goldGradient {
    if (!isDark) {
      return LinearGradient(
        colors: [accent, accent.withOpacity(0.7), accent],
        stops: const [0.0, 0.5, 1.0],
      );
    }
    return LinearGradient(
      colors: [gold, cream, gold],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  static LinearGradient get violetGradient {
    if (!isDark) {
      return LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [accent, accent.withOpacity(0.8)],
      );
    }
    switch (appThemeNotifier.value) {
      case AppThemeMode.gold:
        return const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFF1C40F), Color(0xFFD4AF37)],
        );
      case AppThemeMode.azure:
        return const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF90E0EF), Color(0xFF00B4D8)],
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
        );
    }
  }
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
      ..shader = LinearGradient(
        colors: [ImagoColors.gold, ImagoColors.cream, ImagoColors.gold],
        stops:  [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size * 5, size)),
  );

  static TextStyle tagline({double size = 13}) => TextStyle(
    fontFamily: 'Poppins',
    fontSize:    size,
    fontWeight:  FontWeight.w400,
    color:       ImagoColors.secondaryText,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static TextStyle get body => TextStyle(
    fontFamily: 'Poppins',
    color:      ImagoColors.primaryText,
    fontSize:   15,
    height:     1.45,
  );

  static TextStyle label({double size = 13, FontWeight weight = FontWeight.w500}) =>
    TextStyle(fontFamily: 'Poppins', fontSize: size, fontWeight: weight, color: ImagoColors.primaryText);
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
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(gradient: ImagoColors.bgGradient),
          child: Stack(children: children),
        );
      },
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
    final isDark = ImagoColors.isDark;
    final effectiveAlpha = isDark ? opacity : opacity * 0.45;
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: effectiveAlpha),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }
}
