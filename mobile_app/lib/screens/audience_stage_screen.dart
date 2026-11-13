// lib/screens/audience_stage_screen.dart
// Dedicated Dual-Monitor Audience Stage Display Window for yo-ETS Scripture Projector.
// Designed for secondary screens, projectors, sanctuary TVs, and HDMI outputs.
// Completely distraction-free: 0 sidebars, 0 omnibars, 0 operator controls.
// Syncs in real time (60 FPS) with the operator control console via ProjectorBroadcastService.

import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/bible_models.dart';
import '../services/projector_broadcast_service.dart';
import 'scripture_projector_screen.dart';

class AudienceStageScreen extends StatefulWidget {
  const AudienceStageScreen({super.key});

  @override
  State<AudienceStageScreen> createState() => _AudienceStageScreenState();
}

class _AudienceStageScreenState extends State<AudienceStageScreen> {
  late ProjectorBroadcastFrame _frame;
  StreamSubscription<ProjectorBroadcastFrame>? _sub;
  bool _isHovering = false;
  Timer? _hoverTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _frame = ProjectorBroadcastService.instance.currentFrame;
    ProjectorBroadcastService.instance.isStageWindowOpen = true;

    _sub = ProjectorBroadcastService.instance.frameStream.listen((frame) {
      if (!mounted) return;
      setState(() => _frame = frame);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _hoverTimer?.cancel();
    _focusNode.dispose();
    ProjectorBroadcastService.instance.isStageWindowOpen = false;
    super.dispose();
  }

  void _onPointerHover() {
    _hoverTimer?.cancel();
    setState(() => _isHovering = true);
    _hoverTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isHovering = false);
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Next verse: Right Arrow / Space / PageDown
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      ProjectorBroadcastService.instance.onNextVerse?.call();
      return KeyEventResult.handled;
    }

    // Previous verse: Left Arrow / PageUp
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      ProjectorBroadcastService.instance.onPreviousVerse?.call();
      return KeyEventResult.handled;
    }

    // Blackout: B / F2
    if (event.logicalKey == LogicalKeyboardKey.keyB ||
        event.logicalKey == LogicalKeyboardKey.f2) {
      ProjectorBroadcastService.instance.onToggleBlackout?.call();
      return KeyEventResult.handled;
    }

    // Clear Text: C / F3
    if (event.logicalKey == LogicalKeyboardKey.keyC ||
        event.logicalKey == LogicalKeyboardKey.f3) {
      ProjectorBroadcastService.instance.onToggleClear?.call();
      return KeyEventResult.handled;
    }

    // Close Stage Window: Escape
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MouseRegion(
        onHover: (_) => _onPointerHover(),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Live Slide Presentation Canvas
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: KeyedSubtree(
                  key: ValueKey('${_frame.verse?.chapter}_${_frame.verse?.verse}_${_frame.translation}_${_frame.isBlackout}_${_frame.isCleared}'),
                  child: _buildCanvas(),
                ),
              ),

              // 2. Auto-Hiding Stage Overlay HUD (Appears on mouse move)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                top: _isHovering ? 20 : -80,
                right: 24,
                child: _buildStageOverlayHud(),
              ),

              // 3. Multi-Monitor Setup Guide Banner (Briefly visible on hover)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                bottom: _isHovering ? 20 : -80,
                left: 24,
                child: _buildMultiMonitorHintBadge(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas() {
    // Blackout State
    if (_frame.isBlackout) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          '• BLACKOUT ACTIVE •',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      );
    }

    // Clear Text State
    if (_frame.isCleared) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundLayer(),
          Center(
            child: Text(
              '• TEXT CLEARED •',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.18),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      );
    }

    // Normal Slide
    final rawVerseText = _frame.verse?.text ??
        'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.';
    final verseText = _frame.isUppercase ? rawVerseText.toUpperCase() : rawVerseText;
    final bookName = _frame.verse?.bookName ?? _frame.bookName;
    final chapter = _frame.verse?.chapter ?? _frame.chapter;
    final verseNum = _frame.verse?.verse ?? _frame.verseNumber;

    double dynamicFontSize = _frame.fontSize;
    if (verseText.length > 300) {
      dynamicFontSize *= 0.72;
    } else if (verseText.length > 180) {
      dynamicFontSize *= 0.85;
    }

    TextStyle baseStyle;
    switch (_frame.fontFamily) {
      case 'Poppins':
        baseStyle = GoogleFonts.poppins(fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.35);
        break;
      case 'Merriweather':
        baseStyle = GoogleFonts.merriweather(fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.4);
        break;
      case 'Playfair Display':
        baseStyle = GoogleFonts.playfairDisplay(fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.35);
        break;
      case 'Montserrat':
        baseStyle = GoogleFonts.montserrat(fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.35);
        break;
      case 'Roboto':
        baseStyle = GoogleFonts.roboto(fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.35);
        break;
      case 'Cinzel':
      default:
        baseStyle = TextStyle(fontFamily: 'Cinzel', fontSize: dynamicFontSize, fontWeight: _frame.fontWeight, height: 1.35);
        break;
    }

    TextStyle effectiveStyle;
    if (_frame.textTextureEffect == 'gold_foil') {
      effectiveStyle = baseStyle.copyWith(
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFBEB), Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFFB45309), Color(0xFFFDE68A)],
            stops: [0.0, 0.25, 0.55, 0.8, 1.0],
          ).createShader(const Rect.fromLTWH(0, 0, 1920, 1080)),
        shadows: [Shadow(color: Colors.black.withOpacity(0.85), blurRadius: _frame.shadowBlur, offset: const Offset(2, 3))],
      );
    } else if (_frame.textTextureEffect == 'silver_foil') {
      effectiveStyle = baseStyle.copyWith(
        foreground: Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0), Color(0xFF94A3B8), Color(0xFFCBD5E1), Color(0xFFFFFFFF)],
            stops: [0.0, 0.3, 0.6, 0.85, 1.0],
          ).createShader(const Rect.fromLTWH(0, 0, 1920, 1080)),
        shadows: [Shadow(color: Colors.black.withOpacity(0.85), blurRadius: _frame.shadowBlur, offset: const Offset(2, 3))],
      );
    } else {
      effectiveStyle = baseStyle.copyWith(
        color: _frame.customTextColor,
        shadows: [Shadow(color: Colors.black.withOpacity(0.85), blurRadius: _frame.shadowBlur, offset: const Offset(2, 3))],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildBackgroundLayer(),

        // Foreground Content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
            child: Column(
              mainAxisAlignment: _frame.isLowerThird ? MainAxisAlignment.end : MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Scripture Reference Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
                  decoration: BoxDecoration(
                    color: _frame.customBadgeColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _frame.customBadgeColor.withOpacity(0.4),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$bookName $chapter:$verseNum',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _frame.customBadgeTextColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                      if (_frame.showTranslationInBadge) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _frame.customBadgeTextColor.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _frame.translation,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _frame.customBadgeTextColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Verse Text
                Expanded(
                  flex: _frame.isLowerThird ? 0 : 1,
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: Text(
                        verseText,
                        style: effectiveStyle,
                        textAlign: _frame.textAlign,
                      ),
                    ),
                  ),
                ),

                if (_frame.isLowerThird) const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundLayer() {
    Widget base;
    if (_frame.bgMode == 'image' && _frame.customImagePath != null && File(_frame.customImagePath!).existsSync()) {
      base = Image.file(
        File(_frame.customImagePath!),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_frame.bgMode == 'color') {
      base = Container(color: _frame.customBgColor);
    } else {
      // Find theme preset
      final theme = kProjectorThemes.firstWhere(
        (t) => t.id == _frame.themeId,
        orElse: () => kProjectorThemes.first,
      );
      base = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        // Dimmer overlay
        if (_frame.bgDimmerOpacity > 0)
          Container(
            color: Colors.black.withOpacity(_frame.bgDimmerOpacity),
          ),
        // Blur effect
        if (_frame.bgBlur > 0)
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: _frame.bgBlur, sigmaY: _frame.bgBlur),
            child: const SizedBox.expand(),
          ),
      ],
    );
  }

  Widget _buildStageOverlayHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Live Indicator Badge
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF22C55E),
              boxShadow: [BoxShadow(color: Color(0xFF22C55E), blurRadius: 6, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            'AUDIENCE STAGE OUTPUT',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 14),
          Container(width: 1, height: 18, color: Colors.white24),
          const SizedBox(width: 8),

          // Previous verse
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 18, color: Colors.white),
            tooltip: 'Previous Verse (Left Arrow)',
            onPressed: () => ProjectorBroadcastService.instance.onPreviousVerse?.call(),
          ),
          // Next verse
          IconButton(
            icon: const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
            tooltip: 'Next Verse (Right Arrow / Space)',
            onPressed: () => ProjectorBroadcastService.instance.onNextVerse?.call(),
          ),
          // Blackout
          IconButton(
            icon: Icon(
              _frame.isBlackout ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 18,
              color: _frame.isBlackout ? const Color(0xFFEF4444) : Colors.white,
            ),
            tooltip: 'Toggle Blackout (B)',
            onPressed: () => ProjectorBroadcastService.instance.onToggleBlackout?.call(),
          ),
          // Close Window
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
            tooltip: 'Close Stage Window (Esc)',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiMonitorHintBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withOpacity(0.90),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.tv_rounded, size: 16, color: Color(0xFF818CF8)),
          SizedBox(width: 8),
          Text(
            'Press Win + Shift + → to move this window to Sanctuary Projector Screen',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
