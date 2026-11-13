// lib/services/projector_broadcast_service.dart
// Real-time Presentation Broadcast Bus for yo-ETS Scripture Projector.
// Coordinates live slide frames, styling, themes, and blackout/clear states
// between the Operator Control Console and the Audience Stage Display Output Window.

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/bible_models.dart';

/// An immutable snapshot of the active broadcast frame displayed to the audience.
class ProjectorBroadcastFrame {
  final BibleVerse? verse;
  final String translation;
  final String bookName;
  final int chapter;
  final int verseNumber;
  final String themeId;
  final String bgMode;
  final String? customImagePath;
  final Color customBgColor;
  final String curatedPresetId;
  final double bgDimmerOpacity;
  final double bgBlur;
  final String fontFamily;
  final Color customTextColor;
  final String textTextureEffect;
  final double fontSize;
  final bool isUppercase;
  final TextAlign textAlign;
  final bool hasTextOutline;
  final double shadowBlur;
  final FontWeight fontWeight;
  final Color customBadgeColor;
  final Color customBadgeTextColor;
  final bool showTranslationInBadge;
  final bool isBlackout;
  final bool isCleared;
  final bool isFrozen;
  final bool isLowerThird;

  const ProjectorBroadcastFrame({
    this.verse,
    this.translation = 'KJV',
    this.bookName = 'John',
    this.chapter = 3,
    this.verseNumber = 16,
    this.themeId = 'midnight_gold',
    this.bgMode = 'preset',
    this.customImagePath,
    this.customBgColor = const Color(0xFF0F172A),
    this.curatedPresetId = 'sacred_gold',
    this.bgDimmerOpacity = 0.35,
    this.bgBlur = 0.0,
    this.fontFamily = 'Cinzel',
    this.customTextColor = const Color(0xFFF8FAFC),
    this.textTextureEffect = 'flat',
    this.fontSize = 42.0,
    this.isUppercase = true,
    this.textAlign = TextAlign.center,
    this.hasTextOutline = false,
    this.shadowBlur = 14.0,
    this.fontWeight = FontWeight.w600,
    this.customBadgeColor = const Color(0xFFF59E0B),
    this.customBadgeTextColor = const Color(0xFF0F172A),
    this.showTranslationInBadge = true,
    this.isBlackout = false,
    this.isCleared = false,
    this.isFrozen = false,
    this.isLowerThird = false,
  });

  ProjectorBroadcastFrame copyWith({
    BibleVerse? verse,
    String? translation,
    String? bookName,
    int? chapter,
    int? verseNumber,
    String? themeId,
    String? bgMode,
    String? customImagePath,
    Color? customBgColor,
    String? curatedPresetId,
    double? bgDimmerOpacity,
    double? bgBlur,
    String? fontFamily,
    Color? customTextColor,
    String? textTextureEffect,
    double? fontSize,
    bool? isUppercase,
    TextAlign? textAlign,
    bool? hasTextOutline,
    double? shadowBlur,
    FontWeight? fontWeight,
    Color? customBadgeColor,
    Color? customBadgeTextColor,
    bool? showTranslationInBadge,
    bool? isBlackout,
    bool? isCleared,
    bool? isFrozen,
    bool? isLowerThird,
  }) {
    return ProjectorBroadcastFrame(
      verse: verse ?? this.verse,
      translation: translation ?? this.translation,
      bookName: bookName ?? this.bookName,
      chapter: chapter ?? this.chapter,
      verseNumber: verseNumber ?? this.verseNumber,
      themeId: themeId ?? this.themeId,
      bgMode: bgMode ?? this.bgMode,
      customImagePath: customImagePath ?? this.customImagePath,
      customBgColor: customBgColor ?? this.customBgColor,
      curatedPresetId: curatedPresetId ?? this.curatedPresetId,
      bgDimmerOpacity: bgDimmerOpacity ?? this.bgDimmerOpacity,
      bgBlur: bgBlur ?? this.bgBlur,
      fontFamily: fontFamily ?? this.fontFamily,
      customTextColor: customTextColor ?? this.customTextColor,
      textTextureEffect: textTextureEffect ?? this.textTextureEffect,
      fontSize: fontSize ?? this.fontSize,
      isUppercase: isUppercase ?? this.isUppercase,
      textAlign: textAlign ?? this.textAlign,
      hasTextOutline: hasTextOutline ?? this.hasTextOutline,
      shadowBlur: shadowBlur ?? this.shadowBlur,
      fontWeight: fontWeight ?? this.fontWeight,
      customBadgeColor: customBadgeColor ?? this.customBadgeColor,
      customBadgeTextColor: customBadgeTextColor ?? this.customBadgeTextColor,
      showTranslationInBadge: showTranslationInBadge ?? this.showTranslationInBadge,
      isBlackout: isBlackout ?? this.isBlackout,
      isCleared: isCleared ?? this.isCleared,
      isFrozen: isFrozen ?? this.isFrozen,
      isLowerThird: isLowerThird ?? this.isLowerThird,
    );
  }
}

/// Singleton broadcast service connecting the Operator Console to any Stage Display Windows.
class ProjectorBroadcastService {
  ProjectorBroadcastService._();
  static final ProjectorBroadcastService instance = ProjectorBroadcastService._();

  ProjectorBroadcastFrame _currentFrame = const ProjectorBroadcastFrame();
  final StreamController<ProjectorBroadcastFrame> _streamController =
      StreamController<ProjectorBroadcastFrame>.broadcast();

  bool _isStageWindowOpen = false;

  /// Whether the dedicated audience stage display window is currently open.
  bool get isStageWindowOpen => _isStageWindowOpen;
  set isStageWindowOpen(bool value) {
    _isStageWindowOpen = value;
    if (!_windowStatusController.isClosed) {
      _windowStatusController.add(_isStageWindowOpen);
    }
  }

  final StreamController<bool> _windowStatusController =
      StreamController<bool>.broadcast();
  Stream<bool> get windowStatusStream => _windowStatusController.stream;

  /// The active frame state.
  ProjectorBroadcastFrame get currentFrame => _currentFrame;

  /// Real-time stream of frame updates for the Stage Window.
  Stream<ProjectorBroadcastFrame> get frameStream => _streamController.stream;

  /// Broadcasts a new slide state to all audience windows.
  void broadcast(ProjectorBroadcastFrame frame) {
    _currentFrame = frame;
    if (!_streamController.isClosed) {
      _streamController.add(_currentFrame);
    }
  }

  // Bidirectional command hooks (Stage window hotkeys dispatch back to console)
  VoidCallback? onNextVerse;
  VoidCallback? onPreviousVerse;
  VoidCallback? onToggleBlackout;
  VoidCallback? onToggleClear;
}
