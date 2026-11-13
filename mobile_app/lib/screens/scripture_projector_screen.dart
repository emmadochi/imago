// lib/screens/scripture_projector_screen.dart
// World-class Native Scripture Projector & Presentation Studio for yo-ETS
// Optimized for church sanctuaries, second monitors/projectors, TVs, and live streaming.
// Supports custom background colors, local PC background images, curated church backgrounds,
// custom font families, font colors, and metallic gradient text shaders (Gold Foil / Silver / Bronze).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:record/record.dart' show InputDevice;

import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../services/projector_audio_listener_service.dart';
import '../services/projector_broadcast_service.dart';
import '../services/scripture_detection_service.dart';
import '../services/scripture_suggestion_service.dart';
import '../theme/imago_theme.dart';
import '../widgets/book_chapter_verse_picker_sheet.dart';
import 'audience_stage_screen.dart';

/// Supported visual themes for church projector output
class ProjectorTheme {
  final String id;
  final String name;
  final Color backgroundColor;
  final List<Color> gradientColors;
  final Color textColor;
  final Color accentColor;
  final Color referenceBadgeColor;
  final Color referenceTextColor;
  final String fontFamily;

  const ProjectorTheme({
    required this.id,
    required this.name,
    required this.backgroundColor,
    required this.gradientColors,
    required this.textColor,
    required this.accentColor,
    required this.referenceBadgeColor,
    required this.referenceTextColor,
    this.fontFamily = 'Cinzel',
  });
}

const List<ProjectorTheme> kProjectorThemes = [
  ProjectorTheme(
    id: 'midnight_gold',
    name: 'Midnight & Gold',
    backgroundColor: Color(0xFF0A0D14),
    gradientColors: [Color(0xFF0F172A), Color(0xFF090D16), Color(0xFF030712)],
    textColor: Color(0xFFF8FAFC),
    accentColor: Color(0xFFF59E0B),
    referenceBadgeColor: Color(0xFFF59E0B),
    referenceTextColor: Color(0xFF0F172A),
    fontFamily: 'Cinzel',
  ),
  ProjectorTheme(
    id: 'worship_navy',
    name: 'Worship Navy',
    backgroundColor: Color(0xFF081B33),
    gradientColors: [Color(0xFF0F2B48), Color(0xFF0A192F), Color(0xFF040D1A)],
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFF38BDF8),
    referenceBadgeColor: Color(0xFF0284C7),
    referenceTextColor: Color(0xFFFFFFFF),
    fontFamily: 'Poppins',
  ),
  ProjectorTheme(
    id: 'royal_crimson',
    name: 'Royal Crimson',
    backgroundColor: Color(0xFF1E0A12),
    gradientColors: [Color(0xFF38101E), Color(0xFF220813), Color(0xFF110309)],
    textColor: Color(0xFFFFF1F2),
    accentColor: Color(0xFFFB7185),
    referenceBadgeColor: Color(0xFFE11D48),
    referenceTextColor: Color(0xFFFFFFFF),
    fontFamily: 'Cinzel',
  ),
  ProjectorTheme(
    id: 'living_emerald',
    name: 'Living Hope Emerald',
    backgroundColor: Color(0xFF041C14),
    gradientColors: [Color(0xFF063325), Color(0xFF052319), Color(0xFF02100B)],
    textColor: Color(0xFFECFDF5),
    accentColor: Color(0xFF34D399),
    referenceBadgeColor: Color(0xFF059669),
    referenceTextColor: Color(0xFFFFFFFF),
    fontFamily: 'Poppins',
  ),
  ProjectorTheme(
    id: 'oled_black',
    name: 'Cinema OLED Black',
    backgroundColor: Color(0xFF000000),
    gradientColors: [Color(0xFF000000), Color(0xFF000000)],
    textColor: Color(0xFFFFFFFF),
    accentColor: Color(0xFFE2E8F0),
    referenceBadgeColor: Color(0xFF1E293B),
    referenceTextColor: Color(0xFFF8FAFC),
    fontFamily: 'Cinzel',
  ),
  ProjectorTheme(
    id: 'clean_ivory',
    name: 'Cathedral Ivory (Light)',
    backgroundColor: Color(0xFFF8FAFC),
    gradientColors: [Color(0xFFFFFFFF), Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
    textColor: Color(0xFF0F172A),
    accentColor: Color(0xFF4F46E5),
    referenceBadgeColor: Color(0xFF4F46E5),
    referenceTextColor: Color(0xFFFFFFFF),
    fontFamily: 'Poppins',
  ),
];

/// Curated church background presets with ambient procedural gradients
class CuratedChurchPreset {
  final String id;
  final String name;
  final String subtitle;
  final List<Color> colors;
  final Alignment begin;
  final Alignment end;

  const CuratedChurchPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
  });
}

const List<CuratedChurchPreset> kCuratedChurchPresets = [
  CuratedChurchPreset(
    id: 'sacred_gold',
    name: 'Sacred Sunburst',
    subtitle: 'Golden Heavenly Rays',
    colors: [Color(0xFF1C1304), Color(0xFF382305), Color(0xFF120C02), Color(0xFF050301)],
  ),
  CuratedChurchPreset(
    id: 'celestial_stars',
    name: 'Celestial Night',
    subtitle: 'Midnight Deep Sky',
    colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF050814)],
  ),
  CuratedChurchPreset(
    id: 'stained_glass',
    name: 'Cathedral Glass',
    subtitle: 'Ruby & Sapphire Ambient',
    colors: [Color(0xFF1A091E), Color(0xFF2E082D), Color(0xFF0B192C), Color(0xFF060D17)],
  ),
  CuratedChurchPreset(
    id: 'living_waters',
    name: 'Living Waters',
    subtitle: 'Peaceful Ocean Waters',
    colors: [Color(0xFF031525), Color(0xFF072B4A), Color(0xFF0B3B60), Color(0xFF020C17)],
  ),
  CuratedChurchPreset(
    id: 'holy_fire',
    name: 'Holy Spirit Flame',
    subtitle: 'Communion Amber & Crimson',
    colors: [Color(0xFF2B0A0A), Color(0xFF450A0A), Color(0xFF240404), Color(0xFF0F0101)],
  ),
  CuratedChurchPreset(
    id: 'emerald_grace',
    name: 'Emerald Grace',
    subtitle: 'Forest Haven of Hope',
    colors: [Color(0xFF021B12), Color(0xFF063524), Color(0xFF022016), Color(0xFF010E0A)],
  ),
];

// Note: ScriptureReferenceParser & ParsedScriptureRef are provided by ScriptureSuggestionService.

class ScriptureProjectorScreen extends StatefulWidget {
  final BibleBook? initialBook;
  final int? initialChapter;
  final int? initialVerse;
  final String? initialTranslation;

  const ScriptureProjectorScreen({
    super.key,
    this.initialBook,
    this.initialChapter,
    this.initialVerse,
    this.initialTranslation,
  });

  @override
  State<ScriptureProjectorScreen> createState() => _ScriptureProjectorScreenState();
}

class _ScriptureProjectorScreenState extends State<ScriptureProjectorScreen> {
  // Scripture Navigation State
  late BibleBook _currentBook;
  late int _currentChapter;
  late int _currentVerse;
  late String _currentTranslation;
  List<BibleVerse> _chapterVerses = [];
  BibleVerse? _activeVerse;
  bool _loading = false;
  int _chapterCount = 1;

  // Live Broadcast State
  bool _isBlackout = false;
  bool _isCleared = false;
  bool _isFrozen = false;
  BibleVerse? _frozenVerse;
  String? _frozenTranslation;

  // ── Custom Slide Styling & Engine State ──
  // Background Styling
  String _bgMode = 'preset'; // 'preset', 'color', 'image', 'curated'
  String _selectedThemeId = 'midnight_gold';
  Color _customBgColor = const Color(0xFF0F172A);
  String? _customImagePath;
  String _curatedPresetId = 'sacred_gold';
  double _bgDimmerOpacity = 0.35;
  double _bgBlur = 0.0;

  // Font & Typography Styling
  String _fontFamily = 'Cinzel'; // 'Cinzel', 'Poppins', 'Merriweather', 'Playfair Display', 'Montserrat', 'Roboto'
  Color _customTextColor = const Color(0xFFF8FAFC);
  String _textTextureEffect = 'flat'; // 'flat', 'gold_foil', 'silver_foil', 'bronze_fire', 'celestial_cyan'
  double _fontSize = 42.0;
  bool _isUppercase = true;
  TextAlign _textAlign = TextAlign.center;
  bool _hasTextOutline = false;
  double _shadowBlur = 14.0;
  FontWeight _fontWeight = FontWeight.w600;

  // Reference Badge Styling
  Color _customBadgeColor = const Color(0xFFF59E0B);
  Color _customBadgeTextColor = const Color(0xFF0F172A);
  bool _showTranslationInBadge = true;

  // Layout & Screen
  bool _isLowerThird = false;
  bool _isFullscreenStage = false;
  bool _isSidebarCollapsed = false;
  bool _isStageOutputLive = false;
  StreamSubscription<bool>? _stageWindowSub;

  // ── Live Projector Audio Listener State ─────────────────────────────────
  /// Current 3-way mode (manual / assist / auto)
  ProjectorListenerMode _listenerMode = ProjectorListenerMode.manual;
  /// Latest state snapshot from ProjectorAudioListenerService
  ListenerState _listenerState = const ListenerState();
  /// When operator taps "Edit" on a suggestion, they can correct the reference
  DetectedScripture? _editingSuggestion;
  /// Stream subscription for listener state updates
  StreamSubscription<ListenerState>? _listenerSub;
  /// Controllers for the inline suggestion editor
  final TextEditingController _suggestionEditController = TextEditingController();

  // Search & Omnibar
  final TextEditingController _omniSearchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();
  final ScrollController _translationScrollController = ScrollController();

  // Autocomplete & AI Scripture Suggestion Dropdown State
  List<ScriptureSearchSuggestion> _searchSuggestions = [];
  bool _isLoadingSuggestions = false;
  bool _showSuggestionsDropdown = false;
  int _selectedSuggestionIndex = -1;
  Timer? _suggestionDebounceTimer;

  // Sermon Service Queue
  List<Map<String, dynamic>> _sermonQueue = [];
  final String _queueStorageKey = 'imago_projector_sermon_queue';

  // Popular quick translations for church projection
  final List<String> _quickTranslations = [
    'KJV',
    'AMP',
    'NIV',
    'ESV',
    'NLT',
    'MSG',
    'TPT',
    'BSB',
    'ASV',
    'BBE',
    'GNB',
    'NCV',
    'ERV',
    'YLT',
  ];

  ProjectorTheme get _currentTheme => kProjectorThemes.firstWhere(
        (t) => t.id == _selectedThemeId,
        orElse: () => kProjectorThemes.first,
      );

  CuratedChurchPreset get _currentCuratedPreset => kCuratedChurchPresets.firstWhere(
        (p) => p.id == _curatedPresetId,
        orElse: () => kCuratedChurchPresets.first,
      );

  @override
  void initState() {
    super.initState();
    _currentBook = widget.initialBook ?? kBibleBooks.firstWhere((b) => b.number == 43, orElse: () => kBibleBooks.first); // John default
    _currentChapter = widget.initialChapter ?? 3;
    _currentVerse = widget.initialVerse ?? 16;
    _currentTranslation = widget.initialTranslation ?? BibleService.instance.currentTranslation;

    if (!_quickTranslations.contains(_currentTranslation)) {
      _quickTranslations.insert(0, _currentTranslation);
    }

    _loadSermonQueue();
    _loadStylingPreferences();
    _loadChapterAndActiveVerse();
    _initAudioListener();
    _initStageBroadcast();

    // Omnibar suggestion listeners
    _omniSearchController.addListener(_onSearchInputChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
  }

  void _initAudioListener() {
    final listener = ProjectorAudioListenerService.instance;
    listener.init();

    // Wire up callbacks
    listener.onAutoProject = (DetectedScripture detected) {
      if (!mounted) return;
      _jumpToVerse(detected.book, detected.chapter, detected.verse);
      // Briefly flash the auto-projected banner
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text('Auto-projected: ${detected.formattedRef}', style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
        ]),
        backgroundColor: const Color(0xFF7C3AED),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ));
    };

    listener.onSuggestion = (DetectedScripture detected) {
      // State stream update will drive the Co-Pilot dock rebuild
    };

    listener.onNextVerse = () {
      if (!mounted) return;
      _nextVerse();
    };

    listener.onPreviousVerse = () {
      if (!mounted) return;
      _previousVerse();
    };

    // Subscribe to state stream for UI updates
    _listenerSub?.cancel();
    _listenerSub = listener.stateStream.listen((state) {
      if (!mounted) return;
      setState(() => _listenerState = state);
    });

    // Update detection context whenever the projector verse changes
    ScriptureDetectionService.instance.updateContext(_currentBook, _currentChapter);
  }

  void _initStageBroadcast() {
    final broadcast = ProjectorBroadcastService.instance;
    broadcast.onNextVerse = _nextVerse;
    broadcast.onPreviousVerse = _previousVerse;
    broadcast.onToggleBlackout = () {
      if (!mounted) return;
      setState(() => _isBlackout = !_isBlackout);
      _broadcastCurrentFrame();
    };
    broadcast.onToggleClear = () {
      if (!mounted) return;
      setState(() => _isCleared = !_isCleared);
      _broadcastCurrentFrame();
    };

    _isStageOutputLive = broadcast.isStageWindowOpen;
    _stageWindowSub?.cancel();
    _stageWindowSub = broadcast.windowStatusStream.listen((isOpen) {
      if (!mounted) return;
      setState(() => _isStageOutputLive = isOpen);
    });
  }

  void _broadcastCurrentFrame() {
    final frame = ProjectorBroadcastFrame(
      verse: _isFrozen ? _frozenVerse : _activeVerse,
      translation: _isFrozen ? (_frozenTranslation ?? _currentTranslation) : _currentTranslation,
      bookName: _currentBook.name,
      chapter: _currentChapter,
      verseNumber: _currentVerse,
      themeId: _selectedThemeId,
      bgMode: _bgMode,
      customImagePath: _customImagePath,
      customBgColor: _customBgColor,
      curatedPresetId: _curatedPresetId,
      bgDimmerOpacity: _bgDimmerOpacity,
      bgBlur: _bgBlur,
      fontFamily: _fontFamily,
      customTextColor: _customTextColor,
      textTextureEffect: _textTextureEffect,
      fontSize: _fontSize,
      isUppercase: _isUppercase,
      textAlign: _textAlign,
      hasTextOutline: _hasTextOutline,
      shadowBlur: _shadowBlur,
      fontWeight: _fontWeight,
      customBadgeColor: _customBadgeColor,
      customBadgeTextColor: _customBadgeTextColor,
      showTranslationInBadge: _showTranslationInBadge,
      isBlackout: _isBlackout,
      isCleared: _isCleared,
      isFrozen: _isFrozen,
      isLowerThird: _isLowerThird,
    );
    ProjectorBroadcastService.instance.broadcast(frame);
  }

  void _openAudienceStageWindow() {
    _broadcastCurrentFrame();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AudienceStageScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _listenerSub?.cancel();
    _listenerSub = null;
    final listener = ProjectorAudioListenerService.instance;
    listener.onAutoProject = null;
    listener.onSuggestion = null;
    listener.onTranscript = null;
    listener.onNextVerse = null;
    listener.onPreviousVerse = null;
    // Stop the audio listener and release mic
    listener.setMode(ProjectorListenerMode.manual);
    ScriptureDetectionService.instance.clearContext();

    _stageWindowSub?.cancel();
    _stageWindowSub = null;
    final broadcast = ProjectorBroadcastService.instance;
    broadcast.onNextVerse = null;
    broadcast.onPreviousVerse = null;
    broadcast.onToggleBlackout = null;
    broadcast.onToggleClear = null;

    _suggestionDebounceTimer?.cancel();
    _omniSearchController.removeListener(_onSearchInputChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _omniSearchController.dispose();
    _searchFocusNode.dispose();
    _keyboardFocusNode.dispose();
    _translationScrollController.dispose();
    _suggestionEditController.dispose();
    super.dispose();
  }

  Future<void> _loadStylingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSidebarCollapsed = prefs.getBool('proj_sidebar_collapsed') ?? _isSidebarCollapsed;
      _bgMode = prefs.getString('proj_bg_mode') ?? _bgMode;
      _selectedThemeId = prefs.getString('proj_theme_id') ?? _selectedThemeId;
      final savedBgColor = prefs.getInt('proj_custom_bg_color');
      if (savedBgColor != null) _customBgColor = Color(savedBgColor);
      _customImagePath = prefs.getString('proj_custom_image_path');
      _curatedPresetId = prefs.getString('proj_curated_preset') ?? _curatedPresetId;
      _bgDimmerOpacity = prefs.getDouble('proj_bg_dimmer') ?? _bgDimmerOpacity;
      _bgBlur = prefs.getDouble('proj_bg_blur') ?? _bgBlur;

      _fontFamily = prefs.getString('proj_font_family') ?? _fontFamily;
      final savedTextColor = prefs.getInt('proj_custom_text_color');
      if (savedTextColor != null) _customTextColor = Color(savedTextColor);
      _textTextureEffect = prefs.getString('proj_text_texture') ?? _textTextureEffect;
      _fontSize = prefs.getDouble('proj_font_size') ?? _fontSize;
      _isUppercase = prefs.getBool('proj_is_uppercase') ?? _isUppercase;
      _hasTextOutline = prefs.getBool('proj_has_text_outline') ?? _hasTextOutline;
      _shadowBlur = prefs.getDouble('proj_shadow_blur') ?? _shadowBlur;

      final savedBadgeColor = prefs.getInt('proj_custom_badge_color');
      if (savedBadgeColor != null) _customBadgeColor = Color(savedBadgeColor);
      final savedBadgeTextColor = prefs.getInt('proj_custom_badge_text_color');
      if (savedBadgeTextColor != null) _customBadgeTextColor = Color(savedBadgeTextColor);
      _showTranslationInBadge = prefs.getBool('proj_show_trans_badge') ?? _showTranslationInBadge;
    });
  }

  Future<void> _saveStylingPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('proj_bg_mode', _bgMode);
    await prefs.setString('proj_theme_id', _selectedThemeId);
    await prefs.setInt('proj_custom_bg_color', _customBgColor.value);
    if (_customImagePath != null) {
      await prefs.setString('proj_custom_image_path', _customImagePath!);
    } else {
      await prefs.remove('proj_custom_image_path');
    }
    await prefs.setString('proj_curated_preset', _curatedPresetId);
    await prefs.setDouble('proj_bg_dimmer', _bgDimmerOpacity);
    await prefs.setDouble('proj_bg_blur', _bgBlur);

    await prefs.setString('proj_font_family', _fontFamily);
    await prefs.setInt('proj_custom_text_color', _customTextColor.value);
    await prefs.setString('proj_text_texture', _textTextureEffect);
    await prefs.setDouble('proj_font_size', _fontSize);
    await prefs.setBool('proj_is_uppercase', _isUppercase);
    await prefs.setBool('proj_has_text_outline', _hasTextOutline);
    await prefs.setDouble('proj_shadow_blur', _shadowBlur);

    await prefs.setInt('proj_custom_badge_color', _customBadgeColor.value);
    await prefs.setInt('proj_custom_badge_text_color', _customBadgeTextColor.value);
    await prefs.setBool('proj_show_trans_badge', _showTranslationInBadge);
    await prefs.setBool('proj_sidebar_collapsed', _isSidebarCollapsed);
    _broadcastCurrentFrame();
  }

  Future<void> _loadSermonQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_queueStorageKey);
    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw);
        setState(() {
          _sermonQueue = decoded.cast<Map<String, dynamic>>();
        });
      } catch (_) {}
    } else {
      // Default inspiring sermon starters only on fresh first install
      setState(() {
        _sermonQueue = [
          {'book': 43, 'chapter': 3, 'verse': 16, 'ref': 'John 3:16', 'trans': 'KJV', 'tag': 'Opening'},
          {'book': 45, 'chapter': 8, 'verse': 28, 'ref': 'Romans 8:28', 'trans': 'AMP', 'tag': 'Anchor'},
          {'book': 24, 'chapter': 29, 'verse': 11, 'ref': 'Jeremiah 29:11', 'trans': 'NIV', 'tag': 'Promise'},
          {'book': 58, 'chapter': 11, 'verse': 1, 'ref': 'Hebrews 11:1', 'trans': 'KJV', 'tag': 'Faith'},
        ];
      });
      _saveSermonQueue();
    }
  }

  Future<void> _saveSermonQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_queueStorageKey, jsonEncode(_sermonQueue));
  }

  Future<void> _loadChapterAndActiveVerse({bool keepFrozen = false}) async {
    setState(() => _loading = true);

    try {
      _chapterCount = await BibleService.instance.getChapterCount(_currentBook.number);
      final verses = await BibleService.instance.getVerses(
        _currentBook.number,
        _currentChapter,
        translationAbbreviation: _currentTranslation,
      );

      BibleVerse? foundVerse;
      if (verses.isNotEmpty) {
        foundVerse = verses.firstWhere(
          (v) => v.verse == _currentVerse,
          orElse: () => verses.first,
        );
      }

      setState(() {
        _chapterVerses = verses;
        _activeVerse = foundVerse;
        if (foundVerse != null) {
          _currentVerse = foundVerse.verse;
        }
        if (!keepFrozen && !_isFrozen) {
          _frozenVerse = foundVerse;
          _frozenTranslation = _currentTranslation;
        }
      });
      _broadcastCurrentFrame();
    } catch (e) {
      debugPrint("Error loading projector scripture: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --- Scripture Navigation ---

  void _nextVerse() {
    if (_chapterVerses.isEmpty) return;
    if (_currentVerse < _chapterVerses.length) {
      setState(() {
        _currentVerse++;
        _activeVerse = _chapterVerses.firstWhere((v) => v.verse == _currentVerse);
      });
      _broadcastCurrentFrame();
    } else if (_currentChapter < _chapterCount) {
      setState(() {
        _currentChapter++;
        _currentVerse = 1;
      });
      _loadChapterAndActiveVerse();
    }
    ScriptureDetectionService.instance.updateContext(_currentBook, _currentChapter);
  }

  void _previousVerse() {
    if (_chapterVerses.isEmpty) return;
    if (_currentVerse > 1) {
      setState(() {
        _currentVerse--;
        _activeVerse = _chapterVerses.firstWhere((v) => v.verse == _currentVerse);
      });
      _broadcastCurrentFrame();
    } else if (_currentChapter > 1) {
      setState(() {
        _currentChapter--;
      });
      BibleService.instance
          .getVerses(_currentBook.number, _currentChapter, translationAbbreviation: _currentTranslation)
          .then((verses) {
        if (!mounted) return;
        setState(() {
          _chapterVerses = verses;
          _currentVerse = verses.isNotEmpty ? verses.last.verse : 1;
          _activeVerse = verses.isNotEmpty ? verses.last : null;
        });
        _broadcastCurrentFrame();
      });
    }
    ScriptureDetectionService.instance.updateContext(_currentBook, _currentChapter);
  }

  void _setTranslation(String trans) {
    if (_currentTranslation == trans) return;
    setState(() {
      _currentTranslation = trans;
    });
    _loadChapterAndActiveVerse();
  }

  void _jumpToVerse(BibleBook book, int chapter, int verse) {
    setState(() {
      _currentBook = book;
      _currentChapter = chapter;
      _currentVerse = verse;
    });
    _loadChapterAndActiveVerse();
    // Keep context memory up to date for context-verse citations
    ScriptureDetectionService.instance.updateContext(book, chapter);
  }

  // ── Omnibar As-You-Type Suggestions & Autocomplete Logic ───────────────

  void _onSearchInputChanged() {
    final query = _omniSearchController.text.trim();
    _suggestionDebounceTimer?.cancel();

    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
          _isLoadingSuggestions = false;
          _showSuggestionsDropdown = false;
          _selectedSuggestionIndex = -1;
        });
      }
      return;
    }

    setState(() {
      _isLoadingSuggestions = true;
      _showSuggestionsDropdown = true;
    });

    _suggestionDebounceTimer = Timer(const Duration(milliseconds: 160), () async {
      try {
        final results = await ScriptureSuggestionService.instance.getSuggestions(
          query,
          translation: _currentTranslation,
          maxResults: 6,
        );
        if (mounted && _omniSearchController.text.trim() == query) {
          setState(() {
            _searchSuggestions = results;
            _isLoadingSuggestions = false;
            _selectedSuggestionIndex = results.isNotEmpty ? 0 : -1;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingSuggestions = false);
      }
    });
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 220), () {
        if (mounted && !_searchFocusNode.hasFocus) {
          setState(() => _showSuggestionsDropdown = false);
        }
      });
    } else if (_omniSearchController.text.trim().length >= 2) {
      setState(() => _showSuggestionsDropdown = true);
    }
  }

  void _applySuggestion(ScriptureSearchSuggestion suggestion) {
    _jumpToVerse(suggestion.book, suggestion.chapter, suggestion.verse);
    _omniSearchController.clear();
    setState(() {
      _showSuggestionsDropdown = false;
      _searchSuggestions = [];
      _selectedSuggestionIndex = -1;
    });
    _searchFocusNode.unfocus();
    _keyboardFocusNode.requestFocus();
  }

  void _handleOmniSearchSubmit(String query) {
    // If a suggestion is highlighted or available, apply it directly
    if (_selectedSuggestionIndex >= 0 && _selectedSuggestionIndex < _searchSuggestions.length) {
      _applySuggestion(_searchSuggestions[_selectedSuggestionIndex]);
      return;
    }
    if (_searchSuggestions.isNotEmpty) {
      _applySuggestion(_searchSuggestions.first);
      return;
    }

    final parsed = ScriptureReferenceParser.parse(query);
    if (parsed != null) {
      _jumpToVerse(parsed.book, parsed.chapter, parsed.verse);
      _omniSearchController.clear();
      setState(() {
        _showSuggestionsDropdown = false;
        _searchSuggestions = [];
        _selectedSuggestionIndex = -1;
      });
      _searchFocusNode.unfocus();
      _keyboardFocusNode.requestFocus();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Couldn't find scripture reference '$query'. Try 'Jn 3:16' or 'Rom 8 28'"),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _scrollTranslation(bool forward) {
    if (!_translationScrollController.hasClients) return;
    final delta = forward ? 180.0 : -180.0;
    final target = (_translationScrollController.offset + delta)
        .clamp(0.0, _translationScrollController.position.maxScrollExtent);
    _translationScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectAndActivateTranslation(String trans) {
    if (!_quickTranslations.contains(trans)) {
      setState(() {
        _quickTranslations.insert(0, trans);
      });
    }
    _setTranslation(trans);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_translationScrollController.hasClients) {
        final index = _quickTranslations.indexOf(trans);
        if (index != -1) {
          final targetOffset = (index * 60.0).clamp(0.0, _translationScrollController.position.maxScrollExtent);
          _translationScrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _addToSermonQueue() {
    if (_activeVerse == null) return;
    final item = {
      'book': _currentBook.number,
      'chapter': _currentChapter,
      'verse': _currentVerse,
      'ref': '${_currentBook.name} $_currentChapter:$_currentVerse',
      'trans': _currentTranslation,
      'tag': 'Point ${_sermonQueue.length + 1}',
    };
    setState(() {
      _sermonQueue.add(item);
    });
    _saveSermonQueue();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Added ${item['ref']} to Sermon Service Queue!"),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // --- File Picker for Background Image ---

  Future<void> _pickCustomBackgroundImage() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        setState(() {
          _customImagePath = file.path;
          _bgMode = 'image';
        });
        _saveStylingPreferences();
      }
    } catch (e) {
      debugPrint("Error picking background image: $e");
    }
  }

  // --- Keyboard Shortcuts Handling ---

  bool _isTextInputFocused() {
    if (_searchFocusNode.hasFocus) return true;
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    final widget = primaryFocus.context?.widget;
    if (widget is EditableText) return true;
    if (primaryFocus.context != null &&
        primaryFocus.context!.findAncestorWidgetOfExactType<EditableText>() != null) {
      return true;
    }
    return false;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // When typing inside the verse search box or any input area:
    if (_isTextInputFocused()) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        setState(() => _showSuggestionsDropdown = false);
        _searchFocusNode.unfocus();
        _keyboardFocusNode.requestFocus();
        return KeyEventResult.handled;
      }
      if (_showSuggestionsDropdown && _searchSuggestions.isNotEmpty) {
        if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          setState(() {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex + 1) % _searchSuggestions.length;
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          setState(() {
            _selectedSuggestionIndex =
                (_selectedSuggestionIndex - 1 + _searchSuggestions.length) %
                    _searchSuggestions.length;
          });
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          final targetIndex = _selectedSuggestionIndex >= 0 ? _selectedSuggestionIndex : 0;
          if (targetIndex < _searchSuggestions.length) {
            _applySuggestion(_searchSuggestions[targetIndex]);
            return KeyEventResult.handled;
          }
        }
      }
      return KeyEventResult.ignored;
    }

    // Assist Mode Co-Pilot: Project detected scripture (Enter / NumpadEnter)
    if ((event.logicalKey == LogicalKeyboardKey.enter ||
         event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        _listenerState.pendingSuggestion != null) {
      final s = _listenerState.pendingSuggestion!;
      _jumpToVerse(s.book, s.chapter, s.verse);
      setState(() => _editingSuggestion = null);
      ProjectorAudioListenerService.instance.dismissSuggestion();
      return KeyEventResult.handled;
    }

    // Assist Mode Co-Pilot: Dismiss suggestion (Escape)
    if (event.logicalKey == LogicalKeyboardKey.escape &&
        _listenerState.pendingSuggestion != null) {
      setState(() => _editingSuggestion = null);
      ProjectorAudioListenerService.instance.dismissSuggestion();
      return KeyEventResult.handled;
    }

    // Next verse: Arrow Right, Spacebar, PageDown
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _nextVerse();
      return KeyEventResult.handled;
    }

    // Previous verse: Arrow Left, PageUp
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _previousVerse();
      return KeyEventResult.handled;
    }

    // Blackout: Key B or F2
    if (event.logicalKey == LogicalKeyboardKey.keyB ||
        event.logicalKey == LogicalKeyboardKey.f2) {
      setState(() => _isBlackout = !_isBlackout);
      _broadcastCurrentFrame();
      return KeyEventResult.handled;
    }

    // Clear Text: Key C or F3
    if (event.logicalKey == LogicalKeyboardKey.keyC ||
        event.logicalKey == LogicalKeyboardKey.f3) {
      setState(() => _isCleared = !_isCleared);
      _broadcastCurrentFrame();
      return KeyEventResult.handled;
    }

    // Freeze Output: Key F or F4
    if (event.logicalKey == LogicalKeyboardKey.keyF ||
        event.logicalKey == LogicalKeyboardKey.f4) {
      setState(() {
        _isFrozen = !_isFrozen;
        if (_isFrozen) {
          _frozenVerse = _activeVerse;
          _frozenTranslation = _currentTranslation;
        }
      });
      _broadcastCurrentFrame();
      return KeyEventResult.handled;
    }

    // Fullscreen Toggle: F11
    if (event.logicalKey == LogicalKeyboardKey.f11) {
      setState(() => _isFullscreenStage = !_isFullscreenStage);
      return KeyEventResult.handled;
    }

    // Exit Fullscreen: Escape
    if (event.logicalKey == LogicalKeyboardKey.escape && _isFullscreenStage) {
      setState(() => _isFullscreenStage = false);
      return KeyEventResult.handled;
    }

    // Sidebar Collapse/Expand Toggle: Key S
    if (event.logicalKey == LogicalKeyboardKey.keyS) {
      setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
      _saveStylingPreferences();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;

        return Focus(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _handleKeyEvent,
          child: Scaffold(
            backgroundColor: isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9),
            body: _isFullscreenStage ? _buildFullscreenProjector() : _buildSplitPresenterConsole(isDark),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PRESENTER CONSOLE (Dual Screen / Operator Studio View)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSplitPresenterConsole(bool isDark) {
    return Column(
      children: [
        // Presenter Top Broadcast Control Bar
        _buildTopHeaderBar(isDark),

        // Main Studio Body: Left Operator Panel + Right Live Stage Canvas
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Operator Console (Width: ~440px or 0 when collapsed)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: _isSidebarCollapsed ? 0 : 440,
                child: ClipRect(
                  child: OverflowBox(
                    minWidth: 440,
                    maxWidth: 440,
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 440,
                              child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Column(
                            children: [
                              // Omnibar Search & Quick Picker
                              _buildOmnibarSection(isDark),

                              // Quick 1-Click Translation Selector Strip
                              _buildTranslationSelectorStrip(isDark),

                              // Primary Step Navigators (Prev / Next Large Touch Buttons)
                              _buildPrimaryStepperButtons(isDark),

                              // Tabs: Current Chapter Verses vs Sermon Service Queue
                              Expanded(
                                child: DefaultTabController(
                                  length: 2,
                                  child: Column(
                                    children: [
                                      TabBar(
                                        indicatorColor: const Color(0xFF6366F1),
                                        indicatorWeight: 3,
                                        labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                                        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 12),
                                        tabs: [
                                          Tab(
                                            icon: const Icon(Icons.format_list_numbered_rounded, size: 16),
                                            text: '${_currentBook.name} $_currentChapter (${_chapterVerses.length})',
                                          ),
                                          Tab(
                                            icon: const Icon(Icons.playlist_play_rounded, size: 18),
                                            text: 'Sermon Queue (${_sermonQueue.length})',
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: TabBarView(
                                          children: [
                                            _buildChapterVersesList(isDark),
                                            _buildSermonQueueList(isDark),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Floating AI Scripture Suggestion Dropdown
                          if (_showSuggestionsDropdown && (_searchSuggestions.isNotEmpty || _isLoadingSuggestions))
                            Positioned(
                              top: 60,
                              left: 16,
                              right: 16,
                              child: _buildSuggestionsOverlay(isDark),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Right Live Output Stage & Projection Monitor
              Expanded(
                child: Container(
                  color: isDark ? const Color(0xFF090D16) : const Color(0xFFE2E8F0),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Stage Header Bar: Live Badge + Resolution + Actions
                      _buildStageHeaderControls(isDark),
                      const SizedBox(height: 8),

                      // ── CO-PILOT SUGGESTION DOCK (Assist Mode) ──────────
                      _buildCoPilotSuggestionDock(isDark),

                      const SizedBox(height: 8),

                      // Live Stage Preview Aspect Ratio Box (16:9 Widescreen)
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  // The Live Canvas Slide
                                  Positioned.fill(
                                    child: _buildProjectorCanvas(
                                      verse: _isFrozen ? _frozenVerse : _activeVerse,
                                      translation: _isFrozen ? (_frozenTranslation ?? _currentTranslation) : _currentTranslation,
                                    ),
                                  ),

                                  // Floating Stage On-Hover Quick Stepper Chevrons
                                  Positioned(
                                    left: 12,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildFloatingChevronButton(
                                        icon: Icons.chevron_left_rounded,
                                        onPressed: _previousVerse,
                                        tooltip: 'Previous Verse (Left Arrow)',
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 12,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: _buildFloatingChevronButton(
                                        icon: Icons.chevron_right_rounded,
                                        onPressed: _nextVerse,
                                        tooltip: 'Next Verse (Right Arrow / Space)',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bottom Stage Settings: Themes, Slide Styling Studio & Font Size Slider
                      _buildStageBottomControls(isDark),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TOP BROADCAST CONTROL BAR
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTopHeaderBar(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B132B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Compact Sidebar Toggle Button
          Tooltip(
            message: _isSidebarCollapsed ? 'Expand Sidebar (S)' : 'Collapse Sidebar (S)',
            child: InkWell(
              onTap: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
                _saveStylingPreferences();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  ),
                ),
                child: Icon(
                  _isSidebarCollapsed ? Icons.view_sidebar_outlined : Icons.view_sidebar_rounded,
                  size: 16,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Active Scripture Reference Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Text(
                  '${_currentBook.name} $_currentChapter:$_currentVerse',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Change Translation',
                  child: InkWell(
                    onTap: _showTranslationPicker,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _currentTranslation,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_drop_down_rounded, size: 14, color: Color(0xFF6366F1)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── LIVE LISTENER MODE SWITCHER (Centered) ──────────────────
          _buildListenerModeSwitcher(isDark),

          const Spacer(),

          // Live Broadcast Switchers: Blackout, Clear, Freeze
          _buildActionButton(
            label: 'Blackout (B)',
            icon: Icons.brightness_1_rounded,
            activeColor: const Color(0xFFEF4444),
            isActive: _isBlackout,
            onTap: () {
              setState(() => _isBlackout = !_isBlackout);
              _broadcastCurrentFrame();
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Clear Text (C)',
            icon: Icons.layers_clear_rounded,
            activeColor: const Color(0xFFF59E0B),
            isActive: _isCleared,
            onTap: () {
              setState(() => _isCleared = !_isCleared);
              _broadcastCurrentFrame();
            },
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _buildActionButton(
            label: 'Freeze (F)',
            icon: Icons.pause_circle_filled_rounded,
            activeColor: const Color(0xFF06B6D4),
            isActive: _isFrozen,
            onTap: () {
              setState(() {
                _isFrozen = !_isFrozen;
                if (_isFrozen) {
                  _frozenVerse = _activeVerse;
                  _frozenTranslation = _currentTranslation;
                }
              });
              _broadcastCurrentFrame();
            },
            isDark: isDark,
          ),
          const SizedBox(width: 12),

          // Dedicated Audience Stage Display Window (Dual-Monitor / Projector / TV)
          ElevatedButton.icon(
            onPressed: _openAudienceStageWindow,
            icon: Icon(
              _isStageOutputLive ? Icons.cast_connected_rounded : Icons.cast_rounded,
              size: 18,
              color: _isStageOutputLive ? const Color(0xFF34D399) : Colors.white,
            ),
            label: Text(_isStageOutputLive ? 'Audience Output (LIVE)' : 'Audience Output'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isStageOutputLive ? const Color(0xFF065F46) : const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 2,
              side: BorderSide(
                color: _isStageOutputLive ? const Color(0xFF10B981) : const Color(0xFF475569),
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Launch True Fullscreen Presentation (F11)
          ElevatedButton.icon(
            onPressed: () => setState(() => _isFullscreenStage = true),
            icon: const Icon(Icons.fullscreen_rounded, size: 18),
            label: const Text('Fullscreen Stage (F11)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE LISTENER MODE SWITCHER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildListenerModeSwitcher(bool isDark) {
    final isListening = _listenerState.isListening;
    final isProcessing = _listenerState.isProcessing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live indicator: steady glowing green dot when listening + background AI indicator
        if (isListening) ...[
          Tooltip(
            message: _listenerMode == ProjectorListenerMode.auto
                ? 'Auto Mode: Steady live microphone listening'
                : 'Assist Mode: Steady live microphone listening',
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withOpacity(0.75),
                    blurRadius: 7,
                    spreadRadius: 1.5,
                  ),
                ],
              ),
            ),
          ),
          if (isProcessing) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: 'AI transcribing audio chunk in background...',
              child: const SizedBox(
                width: 9,
                height: 9,
                child: CircularProgressIndicator(
                  strokeWidth: 1.6,
                  color: Color(0xFF818CF8),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
        ],

        // 3-segment mode control
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModeSegment(
                label: 'Manual',
                icon: Icons.pan_tool_alt_rounded,
                mode: ProjectorListenerMode.manual,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                isDark: isDark,
              ),
              Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              _buildModeSegment(
                label: 'Assist',
                icon: Icons.support_agent_rounded,
                mode: ProjectorListenerMode.assist,
                color: const Color(0xFF6366F1),
                isDark: isDark,
              ),
              Container(width: 1, height: 28, color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              _buildModeSegment(
                label: 'Auto',
                icon: Icons.graphic_eq_rounded,
                mode: ProjectorListenerMode.auto,
                color: const Color(0xFF7C3AED),
                isDark: isDark,
              ),
            ],
          ),
        ),

        const SizedBox(width: 6),

        // Audio Listener Settings & Mic Device Button
        Tooltip(
          message: 'Audio Input & Detection Settings',
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () => _showAudioListenerSettingsModal(isDark),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: _listenerMode != ProjectorListenerMode.manual
                      ? const Color(0xFF6366F1).withOpacity(0.5)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 15,
                    color: _listenerMode != ProjectorListenerMode.manual
                        ? const Color(0xFF818CF8)
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  if (_listenerState.isListening) ...[
                    const SizedBox(width: 5),
                    Container(
                      width: 18,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black38 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _listenerState.audioLevel.clamp(0.05, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              const Color(0xFF22C55E),
                              const Color(0xFFEF4444),
                              _listenerState.audioLevel,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeSegment({
    required String label,
    required IconData icon,
    required ProjectorListenerMode mode,
    required Color color,
    required bool isDark,
  }) {
    final isActive = _listenerMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () async {
        setState(() => _listenerMode = mode);
        await ProjectorAudioListenerService.instance.setMode(mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? color : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8))),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? color : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUDIO LISTENER SETTINGS MODAL
  // ─────────────────────────────────────────────────────────────────────────

  void _showAudioListenerSettingsModal(bool isDark) {
    final listener = ProjectorAudioListenerService.instance;
    final testPhraseController = TextEditingController();
    InputDevice? activeDevice = listener.selectedDevice;
    double currentThreshold = listener.autoModeConfidenceThreshold;
    int currentCooldown = listener.autoModeCooldownSeconds;
    int currentChunkSeconds = listener.recordingChunkSeconds;
    final groqController = TextEditingController(text: listener.groqApiKey ?? '');
    String? testResultMsg;
    bool isSuccess = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
            final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subtextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
            final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

            return Dialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: borderColor, width: 1.5),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Modal Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Audio & Live Detection Settings',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Configure sanctuary audio interface, detection sensitivity, and rehearsal cues.',
                                    style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: subtextColor),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              color: subtextColor,
                              onPressed: () => Navigator.of(ctx).pop(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Section 1: Audio Input Device Selector
                        const Text('AUDIO INPUT DEVICE (SOUNDBOARD / MIC)', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8), letterSpacing: 1)),
                        const SizedBox(height: 8),
                        FutureBuilder<List<InputDevice>>(
                          future: listener.listInputDevices(),
                          builder: (context, snapshot) {
                            final devices = snapshot.data ?? [];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.mic_external_on_rounded, size: 18, color: Color(0xFF818CF8)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String?>(
                                        value: activeDevice?.id,
                                        isExpanded: true,
                                        dropdownColor: cardBg,
                                        hint: Text('Default System Microphone', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor)),
                                        items: [
                                          DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('Default System Microphone', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor)),
                                          ),
                                          ...devices.map((d) => DropdownMenuItem<String?>(
                                            value: d.id,
                                            child: Text(d.label.isNotEmpty ? d.label : 'Audio Device (${d.id})', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor)),
                                          )),
                                        ],
                                        onChanged: (String? newId) async {
                                          InputDevice? chosen;
                                          if (newId != null && devices.isNotEmpty) {
                                            chosen = devices.firstWhere((d) => d.id == newId, orElse: () => devices.first);
                                          }
                                          setModalState(() => activeDevice = chosen);
                                          await listener.setSelectedDevice(chosen);
                                        },
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    tooltip: 'Refresh USB Audio Devices',
                                    onPressed: () => setModalState(() {}),
                                    color: subtextColor,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 14),

                        // Section 2: Real-time Audio Level & VU Meter
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('LIVE SIGNAL METER', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: subtextColor, letterSpacing: 0.8)),
                            Text(
                              _listenerState.isListening ? 'Microphone Active' : 'Mic Inactive (Manual)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _listenerState.isListening ? const Color(0xFF22C55E) : subtextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 10,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (_listenerState.audioLevel).clamp(0.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(5),
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444)],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section 3: Audio Buffer & Real-time Responsiveness
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('AUDIO CAPTURE INTERVAL (SPEED)', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8), letterSpacing: 1)),
                            Text('${currentChunkSeconds}s buffer', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                          ],
                        ),
                        Slider(
                          value: currentChunkSeconds.toDouble(),
                          min: 2,
                          max: 5,
                          divisions: 3,
                          activeColor: const Color(0xFF22C55E),
                          inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setModalState(() => currentChunkSeconds = val.round());
                            listener.updateSettings(chunkSeconds: val.round());
                          },
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            {'label': '⚡ Rapid (2s)', 'val': 2},
                            {'label': '⚖️ Balanced (3s)', 'val': 3},
                            {'label': '📖 Deep (4s)', 'val': 4},
                          ].map((p) {
                            final val = p['val'] as int;
                            final isSel = currentChunkSeconds == val;
                            return ChoiceChip(
                              label: Text(p['label'] as String, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : textColor)),
                              selected: isSel,
                              selectedColor: const Color(0xFF22C55E),
                              backgroundColor: inputBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? const Color(0xFF22C55E) : borderColor)),
                              onSelected: (_) {
                                setModalState(() => currentChunkSeconds = val);
                                listener.updateSettings(chunkSeconds: val);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rapid (2s) projects instantly; Balanced (3s) fits full spoken citations smoothly.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: subtextColor),
                        ),

                        const SizedBox(height: 14),

                        // Direct Ultra-Fast Whisper Engine (Groq LPU) Card
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 16, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ULTRA-FAST SPEECH ENGINE (150ms)',
                                    style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 0.8),
                                  ),
                                  const Spacer(),
                                  if ((listener.groqApiKey ?? '').isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF22C55E).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('ACTIVE', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF22C55E))),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Enter an optional free Groq API key (console.groq.com) for instant 150ms Whisper transcription. Bypasses cloud servers completely.',
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: subtextColor),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: TextField(
                                        controller: groqController,
                                        obscureText: true,
                                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: textColor),
                                        decoration: InputDecoration(
                                          hintText: 'Groq API Key (gsk_...) — optional',
                                          hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: subtextColor),
                                          filled: true,
                                          fillColor: cardBg,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      listener.updateSettings(groqApiKey: groqController.text.trim());
                                      setModalState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Speech engine credentials updated!', style: TextStyle(fontFamily: 'Poppins')),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: const Text('Save', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Section 4: Detection Sensitivity & Auto-Project Hold
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('AUTO-PROJECT CONFIDENCE THRESHOLD', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8), letterSpacing: 1)),
                            Text('${(currentThreshold * 100).round()}%', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                          ],
                        ),
                        Slider(
                          value: currentThreshold,
                          min: 0.70,
                          max: 0.95,
                          divisions: 25,
                          activeColor: const Color(0xFF6366F1),
                          inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setModalState(() => currentThreshold = val);
                            listener.updateSettings(confidenceThreshold: val);
                          },
                        ),
                        Wrap(
                          spacing: 6,
                          children: [
                            {'label': '🎯 Sharp (75%)', 'val': 0.75},
                            {'label': '⚖️ Balanced (78%)', 'val': 0.78},
                            {'label': '🔒 Strict (88%)', 'val': 0.88},
                          ].map((p) {
                            final val = p['val'] as double;
                            final isSel = (currentThreshold - val).abs() < 0.02;
                            return ChoiceChip(
                              label: Text(p['label'] as String, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: isSel ? FontWeight.bold : FontWeight.normal, color: isSel ? Colors.white : textColor)),
                              selected: isSel,
                              selectedColor: const Color(0xFF6366F1),
                              backgroundColor: inputBg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: isSel ? const Color(0xFF6366F1) : borderColor)),
                              onSelected: (_) {
                                setModalState(() => currentThreshold = val);
                                listener.updateSettings(confidenceThreshold: val);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          currentThreshold >= 0.88
                              ? 'Strict: requires explicit book, chapter, and verse before projecting.'
                              : currentThreshold >= 0.78
                                  ? 'Balanced: ideal church preaching sensitivity.'
                                  : 'Sharp: projects swiftly on conversational and chapter-level mentions.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: subtextColor),
                        ),

                        const SizedBox(height: 16),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('AUTO-PROJECT HOLD TIME (COOLDOWN)', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF818CF8), letterSpacing: 1)),
                            Text('${currentCooldown}s hold', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF818CF8))),
                          ],
                        ),
                        Slider(
                          value: currentCooldown.toDouble(),
                          min: 2,
                          max: 10,
                          divisions: 8,
                          activeColor: const Color(0xFF7C3AED),
                          inactiveColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          onChanged: (val) {
                            setModalState(() => currentCooldown = val.round());
                            listener.updateSettings(cooldownSeconds: val.round());
                          },
                        ),
                        Text(
                          'Enforces a hold period between automatic slides so the congregation has time to read.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: subtextColor),
                        ),

                        const SizedBox(height: 20),

                        // Section 4: Live Rehearsal & Simulation Sandbox
                        const Text('REHEARSAL & TEST PHRASE SIMULATION', style: TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B), letterSpacing: 1)),
                        const SizedBox(height: 6),
                        Text(
                          'Test speech phrases without speaking into the microphone during pre-service checks.',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: subtextColor),
                        ),
                        const SizedBox(height: 10),

                        // Quick Test Chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            'Romans 8:28',
                            '1 Corinthians 13:4',
                            'John 3:16-18',
                            'Psalm 23:1',
                            'Matthew 6:33',
                          ].map((ref) => ActionChip(
                            label: Text(ref, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, fontWeight: FontWeight.w500)),
                            backgroundColor: inputBg,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: borderColor)),
                            onPressed: () async {
                              final phrase = 'Please turn with me to $ref';
                              final results = ScriptureDetectionService.instance.detect(phrase);
                              if (results.isNotEmpty) {
                                final hit = results.first;
                                setModalState(() {
                                  testResultMsg = 'Detected: ${hit.formattedRef} (${(hit.confidence * 100).round()}% confidence)';
                                  isSuccess = true;
                                });
                              }
                              await listener.simulateSpokenPhrase(phrase);
                            },
                          )).toList(),
                        ),

                        const SizedBox(height: 12),

                        // Custom phrase text field + run button
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: testPhraseController,
                                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'e.g. Turn with me to Ephesians chapter 2 verse 8',
                                  hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: subtextColor),
                                  isDense: true,
                                  filled: true,
                                  fillColor: inputBg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                                ),
                                onSubmitted: (val) async {
                                  if (val.trim().isEmpty) return;
                                  final results = ScriptureDetectionService.instance.detect(val);
                                  if (results.isNotEmpty) {
                                    final hit = results.first;
                                    setModalState(() {
                                      testResultMsg = 'Detected: ${hit.formattedRef} (${(hit.confidence * 100).round()}% confidence)';
                                      isSuccess = true;
                                    });
                                  } else {
                                    setModalState(() {
                                      testResultMsg = 'No scripture citation detected in snippet.';
                                      isSuccess = false;
                                    });
                                  }
                                  await listener.simulateSpokenPhrase(val);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final val = testPhraseController.text.trim();
                                if (val.isEmpty) return;
                                final results = ScriptureDetectionService.instance.detect(val);
                                if (results.isNotEmpty) {
                                  final hit = results.first;
                                  setModalState(() {
                                    testResultMsg = 'Detected: ${hit.formattedRef} (${(hit.confidence * 100).round()}% confidence)';
                                    isSuccess = true;
                                  });
                                } else {
                                  setModalState(() {
                                    testResultMsg = 'No scripture citation detected in snippet.';
                                    isSuccess = false;
                                  });
                                }
                                await listener.simulateSpokenPhrase(val);
                              },
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text('Test', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (testResultMsg != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSuccess ? const Color(0xFF10B981).withOpacity(0.15) : const Color(0xFFEF4444).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                            ),
                            child: Row(
                              children: [
                                Icon(isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 16, color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    testResultMsg!,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  // ─────────────────────────────────────────────────────────────────────────
  // CO-PILOT SUGGESTION DOCK (Assist / Auto Mode)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildCoPilotSuggestionDock(bool isDark) {
    final suggestion = _listenerState.pendingSuggestion;
    final isAutoMode = _listenerMode == ProjectorListenerMode.auto;
    final lastAuto = _listenerState.lastAutoProjected;
    final cooldownLeft = _listenerState.autoProjectCooldownSecondsLeft;
    final statusMsg = _listenerState.statusMessage;
    final isActive = _listenerMode != ProjectorListenerMode.manual;

    // In Manual mode, render nothing
    if (!isActive) return const SizedBox.shrink();

    // Auto mode: live status ribbon with real-time transcript + compact last-projected badge
    if (isAutoMode) {
      final liveStatus = statusMsg ?? (lastAuto != null ? null : 'Listening for scriptures...');
      final isHeard = statusMsg != null && statusMsg.startsWith('Heard:');
      final isNavigating = statusMsg != null && statusMsg.startsWith('Spoken navigation:');
      final isAutoProjected = statusMsg != null && statusMsg.startsWith('Auto-projected:');

      return AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              isAutoProjected
                  ? const Color(0xFF065F46).withOpacity(0.9)
                  : isHeard || isNavigating
                      ? const Color(0xFF1D4ED8).withOpacity(0.85)
                      : const Color(0xFF4C1D95).withOpacity(0.85),
              isAutoProjected
                  ? const Color(0xFF059669).withOpacity(0.7)
                  : const Color(0xFF7C3AED).withOpacity(0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isAutoProjected
                ? const Color(0xFF10B981).withOpacity(0.6)
                : const Color(0xFF7C3AED).withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            // Mic icon — switches to active mic when speech is heard
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isHeard ? Icons.mic_rounded : Icons.graphic_eq_rounded,
                key: ValueKey(isHeard),
                color: isAutoProjected ? const Color(0xFF6EE7B7) : const Color(0xFFC4B5FD),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'AUTO LISTEN',
              style: const TextStyle(
                fontFamily: 'Cinzel', fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC4B5FD), letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 12),

            // Live feed: always shows what the mic just heard or current state
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  liveStatus ?? (lastAuto != null ? 'Ready for next scripture...' : 'Listening for scriptures...'),
                  key: ValueKey(liveStatus),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: isAutoProjected
                        ? const Color(0xFF6EE7B7)
                        : isHeard ? Colors.white : Colors.white60,
                    fontWeight: isAutoProjected || isHeard ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

            // Compact "last projected" badge — so live status always wins center stage
            if (lastAuto != null && !isAutoProjected) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  lastAuto.formattedRef,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: Colors.white54, letterSpacing: 0.3),
                ),
              ),
            ],

            // Hold cooldown badge
            if (cooldownLeft != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Hold ${cooldownLeft}s',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFC4B5FD)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Assist mode: show nothing when no suggestion pending
    if (suggestion == null) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.support_agent_rounded, color: Color(0xFF6366F1), size: 16),
            const SizedBox(width: 8),
            Text(
              'ASSIST MODE',
              style: const TextStyle(fontFamily: 'Cinzel', fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1), letterSpacing: 1),
            ),
            const SizedBox(width: 12),
            Text(
              statusMsg ?? 'Listening for scripture references...',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: isDark ? Colors.white54 : const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    // Assist mode: suggestion card
    final isEditing = _editingSuggestion == suggestion;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E1B4B).withOpacity(0.95),
            const Color(0xFF312E81).withOpacity(0.90),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withOpacity(0.25),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          // Pulsing mic icon
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.5)),
            ),
            child: const Icon(Icons.mic_rounded, color: Color(0xFF818CF8), size: 16),
          ),
          const SizedBox(width: 10),

          // Detected reference + confidence
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('Detected:', style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: Color(0xFF94A3B8))),
                    const SizedBox(width: 6),
                    if (suggestion.chapterFromContext)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Context', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
                      ),
                    const Spacer(),
                    Text(
                      '${(suggestion.confidence * 100).round()}% confidence',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                if (isEditing)
                  // Inline editor
                  SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _suggestionEditController,
                      autofocus: true,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      decoration: const InputDecoration(
                        border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero,
                        hintText: 'e.g. Romans 8:28',
                        hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                      onSubmitted: (val) {
                        final parsed = ScriptureReferenceParser.parse(val);
                        if (parsed != null) {
                          _jumpToVerse(parsed.book, parsed.chapter, parsed.verse);
                        }
                        setState(() => _editingSuggestion = null);
                        ProjectorAudioListenerService.instance.dismissSuggestion();
                      },
                    ),
                  )
                else
                  Text(
                    suggestion.formattedRef,
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // PROJECT NOW (primary)
              Tooltip(
                message: 'Project this verse (Enter)',
                child: ElevatedButton(
                  onPressed: () {
                    _jumpToVerse(suggestion.book, suggestion.chapter, suggestion.verse);
                    ProjectorAudioListenerService.instance.dismissSuggestion();
                    setState(() => _editingSuggestion = null);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 11.5),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.present_to_all_rounded, size: 14),
                      SizedBox(width: 5),
                      Text('Project'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // ADD TO QUEUE
              Tooltip(
                message: 'Add to Sermon Queue',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final item = {
                      'book': suggestion.book.number,
                      'chapter': suggestion.chapter,
                      'verse': suggestion.verse,
                      'ref': suggestion.formattedRef,
                      'trans': _currentTranslation,
                      'tag': 'Detected',
                    };
                    setState(() => _sermonQueue.add(item));
                    _saveSermonQueue();
                    ProjectorAudioListenerService.instance.dismissSuggestion();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${suggestion.formattedRef} added to Sermon Queue'),
                      backgroundColor: const Color(0xFF10B981),
                      duration: const Duration(seconds: 1),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.playlist_add_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // EDIT
              Tooltip(
                message: 'Edit if reference was misheard',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    _suggestionEditController.text = suggestion.formattedRef;
                    setState(() => _editingSuggestion = suggestion);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // DISMISS
              Tooltip(
                message: 'Dismiss (Esc)',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() => _editingSuggestion = null);
                    ProjectorAudioListenerService.instance.dismissSuggestion();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withOpacity(0.2)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? activeColor : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive ? activeColor : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? activeColor : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // OMNIBAR SEARCH & QUICK PICKER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildOmnibarSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _showSuggestionsDropdown
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      width: _showSuggestionsDropdown ? 1.5 : 1.0,
                    ),
                  ),
                  child: TextField(
                    controller: _omniSearchController,
                    focusNode: _searchFocusNode,
                    onSubmitted: (val) {
                      if (_selectedSuggestionIndex >= 0 &&
                          _selectedSuggestionIndex < _searchSuggestions.length) {
                        _applySuggestion(_searchSuggestions[_selectedSuggestionIndex]);
                      } else if (_searchSuggestions.isNotEmpty) {
                        _applySuggestion(_searchSuggestions.first);
                      } else {
                        _handleOmniSearchSubmit(val);
                      }
                    },
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type: "Jn 3:16", "peace", "shepherd"',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: _isLoadingSuggestions
                          ? const Padding(
                              padding: EdgeInsets.all(11.0),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF6366F1),
                                ),
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF6366F1)),
                      suffixIcon: _omniSearchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              tooltip: 'Clear (Esc)',
                              onPressed: () {
                                _omniSearchController.clear();
                                setState(() {
                                  _searchSuggestions = [];
                                  _showSuggestionsDropdown = false;
                                  _selectedSuggestionIndex = -1;
                                });
                              },
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              color: const Color(0xFF6366F1),
                              tooltip: 'Jump (Enter)',
                              onPressed: () => _handleOmniSearchSubmit(_omniSearchController.text),
                            ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Unified Book/Chapter/Verse Sheet button
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: const Color(0xFF6366F1),
                tooltip: 'Select Book & Chapter',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  BookChapterVersePickerSheet.show(
                    context: context,
                    initialBook: _currentBook,
                    initialChapter: _currentChapter,
                    initialVerse: _currentVerse,
                    readerTheme: ReaderTheme.of(readerThemeNotifier.value),
                    onSelected: (book, chapter, verse) {
                      _jumpToVerse(book, chapter, verse);
                    },
                  );
                },
              ),
              const SizedBox(width: 6),
              // Collapse Sidebar button
              IconButton(
                icon: const Icon(Icons.first_page_rounded),
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                tooltip: 'Collapse Sidebar (S)',
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  setState(() => _isSidebarCollapsed = true);
                  _saveStylingPreferences();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FLOATING AI SCRIPTURE SUGGESTIONS OVERLAY
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSuggestionsOverlay(bool isDark) {
    final bgColor = isDark ? const Color(0xFF0F172A).withOpacity(0.97) : Colors.white.withOpacity(0.98);

    return Material(
      color: Colors.transparent,
      elevation: 20,
      borderRadius: BorderRadius.circular(14),
      shadowColor: Colors.black.withOpacity(0.45),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 380),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF6366F1).withOpacity(0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Bar with AI Sparkle and Keyboard Hints
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        'AI SCRIPTURE SUGGESTIONS',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '▲▼ Select • ⏎ Jump • Esc Close',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content: Loading or Suggestions List
                if (_isLoadingSuggestions && _searchSuggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Searching scriptures and topics...',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_searchSuggestions.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Center(
                      child: Text(
                        'No matching scripture found. Try a book ("Jn 3"), topic ("peace"), or quote ("shepherd").',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _searchSuggestions.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      ),
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        final isSelected = index == _selectedSuggestionIndex;

                        return InkWell(
                          onTap: () => _applySuggestion(suggestion),
                          onHover: (hovered) {
                            if (hovered && _selectedSuggestionIndex != index) {
                              setState(() => _selectedSuggestionIndex = index);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            color: isSelected
                                ? const Color(0xFF6366F1).withOpacity(isDark ? 0.22 : 0.12)
                                : Colors.transparent,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Match Badge Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: suggestion.badgeColor.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: suggestion.badgeColor.withOpacity(0.5),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    suggestion.badgeLabel,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: suggestion.badgeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Scripture Reference and Snippet
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            suggestion.reference,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? const Color(0xFF818CF8)
                                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _currentTranslation,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        suggestion.snippet,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          height: 1.3,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Jump Action Hint
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                                        SizedBox(width: 2),
                                        Text(
                                          'Project',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 11,
                                    color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FULL TRANSLATION PICKER MODAL
  // ─────────────────────────────────────────────────────────────────────────────

  void _showTranslationPicker() {
    String selectedLanguageFilter = 'All';
    String searchQuery = '';
    Map<String, double> downloadProgressMap = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setPickerState) {
          final mediaQuery = MediaQuery.of(ctx);

          // Filter translations
          final filtered = kBibleTranslations.where((t) {
            if (selectedLanguageFilter == 'Nigerian' && t.languageCategory != 'Nigerian Languages') {
              return false;
            }
            if (selectedLanguageFilter == 'English' && t.languageCategory != 'English') {
              return false;
            }
            if (selectedLanguageFilter == 'International' && t.languageCategory != 'International Languages') {
              return false;
            }
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              return t.abbreviation.toLowerCase().contains(q) ||
                  t.description.toLowerCase().contains(q) ||
                  t.language.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          // Group by category
          final Map<String, List<BibleTranslation>> grouped = {};
          for (final t in filtered) {
            grouped.putIfAbsent(t.languageCategory, () => []).add(t);
          }

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 680,
                maxHeight: mediaQuery.size.height * 0.85,
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: mediaQuery.viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.translate_rounded, color: ImagoColors.gold, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          'Choose Translation for Projector',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: ImagoColors.cream,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search field
                    TextField(
                      onChanged: (val) => setPickerState(() => searchQuery = val),
                      style: const TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Search translation or language (e.g. KJV, NIV, French, Igbo)...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.4), size: 20),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Language Filter Tabs
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildLanguageFilterChip('All', 'All Languages', selectedLanguageFilter, (f) {
                            setPickerState(() => selectedLanguageFilter = f);
                          }),
                          const SizedBox(width: 8),
                          _buildLanguageFilterChip('English', '🇬🇧 English', selectedLanguageFilter, (f) {
                            setPickerState(() => selectedLanguageFilter = f);
                          }),
                          const SizedBox(width: 8),
                          _buildLanguageFilterChip('Nigerian', '🇳🇬 Nigerian', selectedLanguageFilter, (f) {
                            setPickerState(() => selectedLanguageFilter = f);
                          }),
                          const SizedBox(width: 8),
                          _buildLanguageFilterChip('International', '🌍 International', selectedLanguageFilter, (f) {
                            setPickerState(() => selectedLanguageFilter = f);
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Translation List
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                'No translation found matching "$searchQuery"',
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontFamily: 'Poppins'),
                              ),
                            )
                          : ListView(
                              children: grouped.entries.expand((entry) {
                                final categoryName = entry.key;
                                final translationsInCat = entry.value;

                                String categoryHeaderTitle = '📖 BIBLE TRANSLATIONS';
                                if (categoryName == 'Nigerian Languages') {
                                  categoryHeaderTitle = '🇳🇬 NIGERIAN & LOCAL LANGUAGES';
                                } else if (categoryName == 'English') {
                                  categoryHeaderTitle = '🇬🇧 ENGLISH TRANSLATIONS';
                                } else if (categoryName == 'International Languages') {
                                  categoryHeaderTitle = '🌍 INTERNATIONAL & GLOBAL LANGUAGES';
                                }

                                return [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                                    child: Row(
                                      children: [
                                        Text(
                                          categoryHeaderTitle,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: ImagoColors.gold.withOpacity(0.85),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Divider(color: Colors.white.withOpacity(0.1)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ...translationsInCat.map((t) {
                                    final isSelected = t.abbreviation == _currentTranslation;
                                    final isDownloading = downloadProgressMap.containsKey(t.abbreviation);
                                    final progress = downloadProgressMap[t.abbreviation] ?? 0.0;

                                    return FutureBuilder<bool>(
                                      future: BibleService.instance.isTranslationDownloaded(t.abbreviation),
                                      builder: (ctx, snapshot) {
                                        final isDownloaded = snapshot.data ?? t.isBundled;

                                        return GestureDetector(
                                          onTap: () {
                                            if (!isDownloaded && !t.isBundled) return;
                                            Navigator.pop(ctx);
                                            _selectAndActivateTranslation(t.abbreviation);
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(bottom: 10),
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              gradient: isSelected ? ImagoColors.violetGradient : null,
                                              color: isSelected ? null : Colors.white.withOpacity(0.04),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.transparent
                                                    : Colors.white.withOpacity(0.08),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Text(
                                                  t.flagEmoji,
                                                  style: const TextStyle(fontSize: 20),
                                                ),
                                                const SizedBox(width: 10),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Colors.white.withOpacity(0.2)
                                                        : ImagoColors.gold.withOpacity(0.15),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    t.abbreviation,
                                                    style: TextStyle(
                                                      fontFamily: 'Cinzel',
                                                      color: isSelected ? Colors.white : ImagoColors.gold,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        t.description,
                                                        style: TextStyle(
                                                          fontFamily: 'Poppins',
                                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                                                          fontSize: 13.5,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            t.language,
                                                            style: TextStyle(
                                                              fontFamily: 'Poppins',
                                                              color: isSelected
                                                                  ? Colors.white.withOpacity(0.7)
                                                                  : Colors.white.withOpacity(0.45),
                                                              fontSize: 11,
                                                            ),
                                                          ),
                                                          if (isDownloaded || t.isBundled) ...[
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              '• Offline Ready',
                                                              style: TextStyle(
                                                                fontFamily: 'Poppins',
                                                                color: isSelected
                                                                    ? Colors.white70
                                                                    : Colors.greenAccent,
                                                                fontSize: 10.5,
                                                                fontWeight: FontWeight.w600,
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isDownloading)
                                                  SizedBox(
                                                    width: 80,
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        LinearProgressIndicator(
                                                          value: progress > 0 ? progress : null,
                                                          backgroundColor: Colors.white12,
                                                          color: ImagoColors.gold,
                                                        ),
                                                        const SizedBox(height: 4),
                                                        Text(
                                                          '${(progress * 100).toInt()}%',
                                                          style: const TextStyle(
                                                            fontFamily: 'Poppins',
                                                            color: Colors.white70,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                else if (!isDownloaded && !t.isBundled)
                                                  GestureDetector(
                                                    onTap: () async {
                                                      setPickerState(() {
                                                        downloadProgressMap[t.abbreviation] = 0.05;
                                                      });
                                                      final success = await BibleService.instance.downloadTranslation(
                                                        t.abbreviation,
                                                        onProgress: (p) {
                                                          setPickerState(() {
                                                            downloadProgressMap[t.abbreviation] = p;
                                                          });
                                                        },
                                                      );
                                                      setPickerState(() {
                                                        downloadProgressMap.remove(t.abbreviation);
                                                      });
                                                      if (success) {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('${t.description} downloaded for offline projection!'),
                                                            backgroundColor: ImagoColors.nebula,
                                                          ),
                                                        );
                                                      } else {
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(
                                                            content: Text('Download failed. Please check internet connection.'),
                                                            backgroundColor: Colors.redAccent,
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: ImagoColors.gold,
                                                        borderRadius: BorderRadius.circular(10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.download_rounded, color: Colors.black, size: 14),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            t.downloadSize,
                                                            style: const TextStyle(
                                                              fontFamily: 'Poppins',
                                                              color: Colors.black,
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  )
                                                else if (isSelected)
                                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20)
                                                else
                                                  Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  }),
                                ];
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLanguageFilterChip(
    String key,
    String label,
    String current,
    Function(String) onSelect,
  ) {
    final isSelected = key == current;
    return GestureDetector(
      onTap: () => onSelect(key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? ImagoColors.gold : Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? ImagoColors.gold : Colors.white.withOpacity(0.12),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 1-CLICK TRANSLATION SELECTOR STRIP
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTranslationSelectorStrip(bool isDark) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF090D16).withOpacity(0.5) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          // Left scroll arrow button
          Tooltip(
            message: 'Scroll left',
            child: InkWell(
              onTap: () => _scrollTranslation(false),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Horizontal scrollable translation chips with desktop drag support
          Expanded(
            child: ScrollConfiguration(
              behavior: const MaterialScrollBehavior().copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                },
              ),
              child: ListView.separated(
                controller: _translationScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _quickTranslations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final trans = _quickTranslations[index];
                  final isSelected = _currentTranslation == trans;

                  return InkWell(
                    onTap: () => _setTranslation(trans),
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          trans,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Right scroll arrow button
          Tooltip(
            message: 'Scroll right',
            child: InkWell(
              onTap: () => _scrollTranslation(true),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.6) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // "+ More" Button to browse all library translations
          Tooltip(
            message: 'Browse all translations',
            child: InkWell(
              onTap: _showTranslationPicker,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withOpacity(0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate_rounded, size: 14, color: Color(0xFF818CF8)),
                    SizedBox(width: 5),
                    Text(
                      '+ More',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF818CF8),
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

  // ─────────────────────────────────────────────────────────────────────────────
  // PRIMARY STEP NAVIGATORS (Prev / Next Large Buttons)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildPrimaryStepperButtons(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _previousVerse,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('Prev Verse (←)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.bookmark_add_rounded),
            color: const Color(0xFFF59E0B),
            tooltip: 'Add to Sermon Service Queue',
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _addToSermonQueue,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextVerse,
              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
              label: const Text('Next Verse (→)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                elevation: 1,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CHAPTER VERSES LIST
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildChapterVersesList(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_chapterVerses.isEmpty) {
      return Center(
        child: Text(
          'No verses found for $_currentTranslation',
          style: TextStyle(fontFamily: 'Poppins', color: isDark ? Colors.white54 : Colors.black54),
        ),
      );
    }

    return ListView.builder(
      itemCount: _chapterVerses.length,
      itemBuilder: (context, index) {
        final v = _chapterVerses[index];
        final isSelected = v.verse == _currentVerse;

        return InkWell(
          onTap: () {
            setState(() {
              _currentVerse = v.verse;
              _activeVerse = v;
            });
            _keyboardFocusNode.requestFocus();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withOpacity(0.15)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
                  width: 3.5,
                ),
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${v.verse}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    v.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? Colors.white : const Color(0xFF0F172A))
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                  ),
                ),
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 4),
                    child: Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SERMON SERVICE QUEUE LIST
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildSermonQueueList(bool isDark) {
    if (_sermonQueue.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.playlist_add_check_rounded, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
              const SizedBox(height: 10),
              Text(
                'No sermon verses queued',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Search any scripture or tap bookmark to add verses to your sermon queue',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _sermonQueue = [
                      {'book': 43, 'chapter': 3, 'verse': 16, 'ref': 'John 3:16', 'trans': 'KJV', 'tag': 'Opening'},
                      {'book': 45, 'chapter': 8, 'verse': 28, 'ref': 'Romans 8:28', 'trans': 'AMP', 'tag': 'Anchor'},
                      {'book': 24, 'chapter': 29, 'verse': 11, 'ref': 'Jeremiah 29:11', 'trans': 'NIV', 'tag': 'Promise'},
                      {'book': 58, 'chapter': 11, 'verse': 1, 'ref': 'Hebrews 11:1', 'trans': 'KJV', 'tag': 'Faith'},
                    ];
                  });
                  _saveSermonQueue();
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text('Restore Sample Starters', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Queue Header Toolbar: Count + Clear All
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withOpacity(0.35) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.playlist_play_rounded, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(
                '${_sermonQueue.length} ${_sermonQueue.length == 1 ? "Verse" : "Verses"} Queued',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showClearQueueDialog,
                icon: const Icon(Icons.delete_sweep_rounded, size: 14, color: Color(0xFFEF4444)),
                label: const Text(
                  'Clear All',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),

        // Queue Items List
        Expanded(
          child: ListView.builder(
            itemCount: _sermonQueue.length,
            itemBuilder: (context, index) {
              final item = _sermonQueue[index];
              final bookNum = item['book'] as int;
              final chap = item['chapter'] as int;
              final verse = item['verse'] as int;
              final ref = item['ref'] as String;
              final trans = item['trans'] as String? ?? 'KJV';
              final tag = item['tag'] as String? ?? 'Item ${index + 1}';

              final isCurrent = _currentBook.number == bookNum &&
                  _currentChapter == chap &&
                  _currentVerse == verse;

              return Dismissible(
                key: ValueKey('$ref-$index-${item.hashCode}'),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: const Color(0xFFEF4444),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 4),
                      Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                onDismissed: (_) {
                  final removed = _sermonQueue[index];
                  setState(() {
                    _sermonQueue.removeAt(index);
                  });
                  _saveSermonQueue();
                  _showUndoDeleteSnackBar(removed, index);
                },
                child: InkWell(
                  onTap: () {
                    final book = kBibleBooks.firstWhere((b) => b.number == bookNum, orElse: () => kBibleBooks.first);
                    _setTranslation(trans);
                    _jumpToVerse(book, chap, verse);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF10B981).withOpacity(0.15)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: isCurrent ? const Color(0xFF10B981) : Colors.transparent,
                          width: 3.5,
                        ),
                        bottom: BorderSide(
                          color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF1F5F9),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Tag Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Scripture Reference
                        Expanded(
                          child: Text(
                            ref,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),

                        // Translation Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            trans,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Direct Delete Icon Button
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 15),
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          hoverColor: const Color(0xFFEF4444).withOpacity(0.15),
                          tooltip: 'Remove $ref from queue',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                          splashRadius: 13,
                          onPressed: () {
                            final removed = _sermonQueue[index];
                            setState(() {
                              _sermonQueue.removeAt(index);
                            });
                            _saveSermonQueue();
                            _showUndoDeleteSnackBar(removed, index);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showUndoDeleteSnackBar(Map<String, dynamic> item, int index) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${item['ref']} from sermon queue'),
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF1E293B),
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFF818CF8),
          onPressed: () {
            setState(() {
              final insertIndex = index.clamp(0, _sermonQueue.length);
              _sermonQueue.insert(insertIndex, item);
            });
            _saveSermonQueue();
          },
        ),
      ),
    );
  }

  void _showClearQueueDialog() {
    if (_sermonQueue.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text(
              'Clear Sermon Queue',
              style: TextStyle(color: Colors.white, fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove all ${_sermonQueue.length} scriptures from your sermon queue?',
          style: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Poppins', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Poppins')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              final backup = List<Map<String, dynamic>>.from(_sermonQueue);
              Navigator.pop(ctx);
              setState(() {
                _sermonQueue.clear();
              });
              _saveSermonQueue();

              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Cleared ${backup.length} scriptures from queue'),
                  duration: const Duration(seconds: 4),
                  backgroundColor: const Color(0xFF1E293B),
                  action: SnackBarAction(
                    label: 'Undo',
                    textColor: const Color(0xFF818CF8),
                    onPressed: () {
                      setState(() {
                        _sermonQueue = backup;
                      });
                      _saveSermonQueue();
                    },
                  ),
                ),
              );
            },
            child: const Text('Clear All', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // QUICK BACKGROUND & FONT COLOR MODALS
  // ─────────────────────────────────────────────────────────────────────────────

  void _showQuickBackgroundModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.wallpaper_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Change Projector Background',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: Pick Custom Image from PC
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF10B981)),
                ),
                title: const Text('Choose Custom Image from PC', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: Text(_customImagePath != null ? 'Current: ${_customImagePath!.split(Platform.pathSeparator).last}' : 'Select any JPG, PNG, or WEBP image file', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                trailing: _customImagePath != null && _bgMode == 'image'
                    ? const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981))
                    : const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickCustomBackgroundImage();
                },
              ),

              if (_customImagePath != null && _bgMode == 'image')
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  ),
                  title: const Text('Remove Custom Image (Revert to Theme)', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFFEF4444))),
                  onTap: () {
                    setState(() {
                      _customImagePath = null;
                      _bgMode = 'preset';
                    });
                    _saveStylingPreferences();
                    Navigator.pop(ctx);
                  },
                ),

              // Option 2: Solid Color
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.format_color_fill_rounded, color: Color(0xFFF59E0B)),
                ),
                title: const Text('Custom Solid Background Color', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: const Text('Pick any solid background color with live adjustment', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFullColorPickerDialog(
                    currentColor: _customBgColor,
                    onColorSelected: (c) {
                      setState(() {
                        _customBgColor = c;
                        _bgMode = 'color';
                      });
                      _saveStylingPreferences();
                    },
                  );
                },
              ),

              // Option 3: Full Customizer Studio Modal
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.tune_rounded, color: Color(0xFF6366F1)),
                ),
                title: const Text('Full Slide & Background Studio...', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5)),
                subtitle: const Text('Curated church gradients, dimmer, blur, fonts & badges', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _openSlideCustomizerModal(isDark);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickFontColorPicker(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.format_color_text_rounded, color: Color(0xFF6366F1), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Change Projector Font Color',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick High-Contrast Screen Colors:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                const Color(0xFFFFFFFF), // Pure White
                const Color(0xFFFBBF24), // Luminous Gold
                const Color(0xFFF59E0B), // Amber Sun
                const Color(0xFFFFFBEB), // Cathedral Ivory
                const Color(0xFF38BDF8), // Celestial Cyan
                const Color(0xFF34D399), // Emerald Glow
                const Color(0xFFFDA4AF), // Rose Coral
                const Color(0xFFE2E8F0), // Platinum Light
                const Color(0xFF0F172A), // Dark Onyx
              ].map((c) {
                final isCurrent = _customTextColor.value == c.value;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _customTextColor = c;
                      _textTextureEffect = 'flat';
                    });
                    _saveStylingPreferences();
                    Navigator.pop(ctx);
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent ? const Color(0xFF6366F1) : (isDark ? Colors.white24 : Colors.black26),
                        width: isCurrent ? 3.5 : 1.5,
                      ),
                      boxShadow: [
                        if (isCurrent)
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.5),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: isCurrent
                        ? Icon(Icons.check, size: 20, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Center(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.colorize_rounded, size: 16),
                label: const Text('Custom Color Wheel...'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  side: const BorderSide(color: Color(0xFF6366F1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showFullColorPickerDialog(
                    currentColor: _customTextColor,
                    onColorSelected: (c) {
                      setState(() {
                        _customTextColor = c;
                        _textTextureEffect = 'flat';
                      });
                      _saveStylingPreferences();
                    },
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // RIGHT STAGE MONITOR CONTROLS & CANVAS
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStageHeaderControls(bool isDark) {
    return Row(
      children: [
        if (_isSidebarCollapsed) ...[
          Tooltip(
            message: 'Expand Sidebar (S)',
            child: InkWell(
              onTap: () {
                setState(() => _isSidebarCollapsed = false);
                _saveStylingPreferences();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.view_sidebar_rounded, size: 16, color: Color(0xFF818CF8)),
                    SizedBox(width: 6),
                    Text(
                      'Show Sidebar',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF818CF8)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],

        // Live Screen Beacon
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _isBlackout
                ? const Color(0xFFEF4444).withOpacity(0.2)
                : const Color(0xFF10B981).withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isBlackout ? const Color(0xFFEF4444) : const Color(0xFF10B981),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isBlackout ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                  boxShadow: [
                    BoxShadow(
                      color: (_isBlackout ? const Color(0xFFEF4444) : const Color(0xFF10B981)).withOpacity(0.6),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isBlackout
                    ? 'SCREEN BLACKED OUT'
                    : (_isFrozen ? 'OUTPUT FROZEN (BROWSING)' : 'LIVE AUDIENCE PROJECTION'),
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _isBlackout ? const Color(0xFFEF4444) : (_isFrozen ? const Color(0xFF06B6D4) : const Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Direct Custom Background Image Button
        Tooltip(
          message: 'Change Projector Background Image / Color',
          child: InkWell(
            onTap: () => _showQuickBackgroundModal(isDark),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _bgMode == 'image' && _customImagePath != null
                    ? const Color(0xFF10B981).withOpacity(0.18)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _bgMode == 'image' && _customImagePath != null
                      ? const Color(0xFF10B981)
                      : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_rounded,
                    size: 15,
                    color: _bgMode == 'image' && _customImagePath != null ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _bgMode == 'image' && _customImagePath != null ? 'Custom Image ✓' : 'Background Image',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _bgMode == 'image' && _customImagePath != null
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Direct Font Color Picker Button
        Tooltip(
          message: 'Change Projector Scripture Font Color',
          child: InkWell(
            onTap: () => _showQuickFontColorPicker(isDark),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: _customTextColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? Colors.white54 : Colors.black26),
                      boxShadow: [
                        BoxShadow(
                          color: _customTextColor.withOpacity(0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Font Color',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Full Slide Customizer Studio Button
        Tooltip(
          message: 'Full Slide Customization Studio (Fonts, Metallic Foil, Badges)',
          child: IconButton(
            icon: const Icon(Icons.tune_rounded, size: 17),
            tooltip: 'Style Studio',
            style: IconButton.styleFrom(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
            ),
            color: const Color(0xFF6366F1),
            onPressed: () => _openSlideCustomizerModal(isDark),
          ),
        ),
        const SizedBox(width: 8),

        // Lower Third Toggle (OBS / Stream overlay)
        FilterChip(
          selected: _isLowerThird,
          label: Text(
            _isLowerThird ? 'Lower-Third (OBS/Stream)' : 'Full Worship Screen',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _isLowerThird ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
            ),
          ),
          avatar: Icon(
            _isLowerThird ? Icons.horizontal_split_rounded : Icons.crop_free_rounded,
            size: 14,
            color: _isLowerThird ? Colors.white : const Color(0xFF6366F1),
          ),
          selectedColor: const Color(0xFF6366F1),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          onSelected: (val) => setState(() => _isLowerThird = val),
        ),
      ],
    );
  }

  Widget _buildFloatingChevronButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.4),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BOTTOM STAGE CONTROLS WITH SLIDE CUSTOMIZER BUTTON
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildStageBottomControls(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Theme Dropdown Quick Switcher
            Text(
              'Theme:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedThemeId,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                items: kProjectorThemes.map((t) {
                  return DropdownMenuItem(
                    value: t.id,
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: t.accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(t.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final selectedTheme = kProjectorThemes.firstWhere((t) => t.id == val);
                    setState(() {
                      _selectedThemeId = val;
                      _bgMode = 'preset';
                      _customTextColor = selectedTheme.textColor;
                      _fontFamily = selectedTheme.fontFamily;
                      _customBadgeColor = selectedTheme.referenceBadgeColor;
                      _customBadgeTextColor = selectedTheme.referenceTextColor;
                    });
                    _saveStylingPreferences();
                  }
                },
              ),
            ),

            const SizedBox(width: 14),

            // Primary Slide Customizer Button (Colors, Font & Background Image)
            ElevatedButton.icon(
              onPressed: () => _openSlideCustomizerModal(isDark),
              icon: const Icon(Icons.palette_rounded, size: 16),
              label: const Text('Slide & Background Studio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                textStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),

            const SizedBox(width: 18),

            // Font Size Slider
            Text(
              'Size:',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                if (_fontSize > 26) {
                  setState(() => _fontSize -= 4);
                  _saveStylingPreferences();
                }
              },
            ),
            SizedBox(
              width: 100,
              child: SliderTheme(
                data: SliderThemeData(
                  thumbColor: const Color(0xFF6366F1),
                  activeTrackColor: const Color(0xFF6366F1),
                  inactiveTrackColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                  trackHeight: 3,
                ),
                child: Slider(
                  value: _fontSize,
                  min: 24.0,
                  max: 68.0,
                  divisions: 11,
                  onChanged: (val) {
                    setState(() => _fontSize = val);
                    _saveStylingPreferences();
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              onPressed: () {
                if (_fontSize < 68) {
                  setState(() => _fontSize += 4);
                  _saveStylingPreferences();
                }
              },
            ),
            Text(
              '${_fontSize.round()} pt',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),

            const SizedBox(width: 24),

            // Hotkey hint pills
            Text(
              'Shortcuts: [← / →] Next/Prev  •  [S] Sidebar  •  [B] Blackout  •  [F11] Fullscreen',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SLIDE CUSTOMIZER STUDIO MODAL (Colors, Font Texture, Background Image)
  // ─────────────────────────────────────────────────────────────────────────────

  void _openSlideCustomizerModal(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF0B132B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780, maxHeight: 640),
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.palette_rounded, color: Color(0xFF6366F1), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Slide Styling & Presentation Studio',
                                  style: TextStyle(
                                    fontFamily: 'Cinzel',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  'Customize background image, colors, font family & metallic font texture',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      ),

                      // Tabs Bar
                      TabBar(
                        indicatorColor: const Color(0xFF6366F1),
                        indicatorWeight: 3,
                        labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
                        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13),
                        tabs: const [
                          Tab(icon: Icon(Icons.wallpaper_rounded, size: 16), text: 'Background Image & Color'),
                          Tab(icon: Icon(Icons.text_fields_rounded, size: 16), text: 'Font, Color & Texture'),
                          Tab(icon: Icon(Icons.badge_rounded, size: 16), text: 'Reference Badge'),
                        ],
                      ),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          children: [
                            // 1. Background Customizer
                            _buildBackgroundCustomizerTab(isDark, setDialogState),

                            // 2. Font & Typography Customizer
                            _buildTypographyCustomizerTab(isDark, setDialogState),

                            // 3. Reference Badge Customizer
                            _buildBadgeCustomizerTab(isDark, setDialogState),
                          ],
                        ),
                      ),

                      // Footer Actions: Reset / Done
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF090D16) : const Color(0xFFF8FAFC),
                          border: Border(
                            top: BorderSide(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                        ),
                        child: Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.restart_alt_rounded, size: 16),
                              label: const Text('Reset to Default Theme'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  _bgMode = 'preset';
                                  _selectedThemeId = 'midnight_gold';
                                  _customImagePath = null;
                                  _bgDimmerOpacity = 0.35;
                                  _bgBlur = 0.0;
                                  _fontFamily = 'Cinzel';
                                  _customTextColor = const Color(0xFFF8FAFC);
                                  _textTextureEffect = 'flat';
                                  _isUppercase = true;
                                  _hasTextOutline = false;
                                  _customBadgeColor = const Color(0xFFF59E0B);
                                  _customBadgeTextColor = const Color(0xFF0F172A);
                                });
                                setState(() {});
                                _saveStylingPreferences();
                              },
                            ),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Done & Apply', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 1: BACKGROUND CUSTOMIZER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBackgroundCustomizerTab(bool isDark, StateSetter setDialogState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Background Source:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),

          // Mode Segmented Selector Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChoiceChip(
                label: 'Theme Presets',
                icon: Icons.palette_outlined,
                isSelected: _bgMode == 'preset',
                onSelected: () {
                  setDialogState(() => _bgMode = 'preset');
                  setState(() => _bgMode = 'preset');
                  _saveStylingPreferences();
                },
                isDark: isDark,
              ),
              _buildChoiceChip(
                label: 'Custom Solid Color',
                icon: Icons.format_color_fill_rounded,
                isSelected: _bgMode == 'color',
                onSelected: () {
                  setDialogState(() => _bgMode = 'color');
                  setState(() => _bgMode = 'color');
                  _saveStylingPreferences();
                },
                isDark: isDark,
              ),
              _buildChoiceChip(
                label: 'Pick Image from PC',
                icon: Icons.add_photo_alternate_rounded,
                isSelected: _bgMode == 'image',
                onSelected: () {
                  setDialogState(() => _bgMode = 'image');
                  setState(() => _bgMode = 'image');
                  _saveStylingPreferences();
                },
                isDark: isDark,
              ),
              _buildChoiceChip(
                label: 'Curated Church Presets',
                icon: Icons.church_rounded,
                isSelected: _bgMode == 'curated',
                onSelected: () {
                  setDialogState(() => _bgMode = 'curated');
                  setState(() => _bgMode = 'curated');
                  _saveStylingPreferences();
                },
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Dynamic Body depending on Mode
          if (_bgMode == 'image') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _pickCustomBackgroundImage();
                          setDialogState(() {});
                        },
                        icon: const Icon(Icons.folder_open_rounded, size: 16),
                        label: const Text('Choose Image File (.jpg, .png)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_customImagePath != null)
                        TextButton.icon(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Remove Image'),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                          onPressed: () {
                            setDialogState(() {
                              _customImagePath = null;
                              _bgMode = 'preset';
                            });
                            setState(() {
                              _customImagePath = null;
                              _bgMode = 'preset';
                            });
                            _saveStylingPreferences();
                          },
                        ),
                    ],
                  ),
                  if (_customImagePath != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: File(_customImagePath!).existsSync()
                              ? Image.file(File(_customImagePath!), width: 70, height: 45, fit: BoxFit.cover)
                              : Container(width: 70, height: 45, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _customImagePath!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else if (_bgMode == 'color') ...[
            Text(
              'Select Background Color:',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                const Color(0xFF000000), // OLED Black
                const Color(0xFF0F172A), // Slate Navy
                const Color(0xFF1E1B4B), // Royal Indigo
                const Color(0xFF1E0A12), // Crimson Velvet
                const Color(0xFF041C14), // Emerald
                const Color(0xFF18181B), // Zinc Dark
                const Color(0xFFF8FAFC), // Alabaster Light
              ].map((c) {
                final isCurrent = _customBgColor.value == c.value;
                return InkWell(
                  onTap: () {
                    setDialogState(() => _customBgColor = c);
                    setState(() => _customBgColor = c);
                    _saveStylingPreferences();
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isCurrent ? const Color(0xFF6366F1) : (isDark ? Colors.white24 : Colors.black26),
                        width: isCurrent ? 3 : 1,
                      ),
                    ),
                    child: isCurrent ? Icon(Icons.check, size: 18, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              icon: const Icon(Icons.colorize_rounded, size: 16),
              label: const Text('Pick Exact Custom HEX / RGB...'),
              onPressed: () {
                _showFullColorPickerDialog(
                  currentColor: _customBgColor,
                  onColorSelected: (c) {
                    setDialogState(() => _customBgColor = c);
                    setState(() => _customBgColor = c);
                    _saveStylingPreferences();
                  },
                );
              },
            ),
          ] else if (_bgMode == 'curated') ...[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
              ),
              itemCount: kCuratedChurchPresets.length,
              itemBuilder: (context, index) {
                final preset = kCuratedChurchPresets[index];
                final isSelected = _curatedPresetId == preset.id;

                return InkWell(
                  onTap: () {
                    setDialogState(() => _curatedPresetId = preset.id);
                    setState(() => _curatedPresetId = preset.id);
                    _saveStylingPreferences();
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: preset.colors),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF59E0B) : Colors.white24,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          preset.name,
                          style: const TextStyle(fontFamily: 'Cinzel', fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          preset.subtitle,
                          style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 14),

          // Background Dimmer Slider (Ensures readability over images)
          Row(
            children: [
              Text(
                'Background Dimmer / Dark Overlay:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${(_bgDimmerOpacity * 100).round()}%',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          Slider(
            value: _bgDimmerOpacity,
            min: 0.0,
            max: 0.85,
            divisions: 17,
            activeColor: const Color(0xFF6366F1),
            onChanged: (val) {
              setDialogState(() => _bgDimmerOpacity = val);
              setState(() => _bgDimmerOpacity = val);
              _saveStylingPreferences();
            },
          ),

          // Background Blur Slider
          Row(
            children: [
              Text(
                'Background Blur Effect (Focus on text):',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${_bgBlur.round()} px',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
              ),
            ],
          ),
          Slider(
            value: _bgBlur,
            min: 0.0,
            max: 15.0,
            divisions: 15,
            activeColor: const Color(0xFF6366F1),
            onChanged: (val) {
              setDialogState(() => _bgBlur = val);
              setState(() => _bgBlur = val);
              _saveStylingPreferences();
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 2: TYPOGRAPHY, FONT COLOR & METALLIC TEXTURE CUSTOMIZER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildTypographyCustomizerTab(bool isDark, StateSetter setDialogState) {
    final List<String> availableFonts = [
      'Cinzel',
      'Poppins',
      'Merriweather',
      'Playfair Display',
      'Montserrat',
      'Roboto',
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Font Family Picker
          Text(
            'Scripture Font Family:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableFonts.map((f) {
              final isSelected = _fontFamily == f;
              return ChoiceChip(
                label: Text(f, style: TextStyle(fontFamily: f == 'Cinzel' || f == 'Poppins' ? f : null, fontWeight: FontWeight.w600)),
                selected: isSelected,
                selectedColor: const Color(0xFF6366F1),
                labelStyle: TextStyle(color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A))),
                onSelected: (_) {
                  setDialogState(() => _fontFamily = f);
                  setState(() => _fontFamily = f);
                  _saveStylingPreferences();
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Metallic Font Texture / Shader Effect (e.g. Gold Foil / Silver)
          Text(
            'Font Texture / Metallic Gradient Effect:',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTextureChip(
                label: 'Flat Color',
                effectKey: 'flat',
                gradient: null,
                setDialogState: setDialogState,
                isDark: isDark,
              ),
              _buildTextureChip(
                label: 'Radiant Gold Foil',
                effectKey: 'gold_foil',
                gradient: const [Color(0xFFFFF9C4), Color(0xFFFFD54F), Color(0xFFFFA000)],
                setDialogState: setDialogState,
                isDark: isDark,
              ),
              _buildTextureChip(
                label: 'Silver Chrome',
                effectKey: 'silver_foil',
                gradient: const [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF64748B)],
                setDialogState: setDialogState,
                isDark: isDark,
              ),
              _buildTextureChip(
                label: 'Sunset Bronze',
                effectKey: 'bronze_fire',
                gradient: const [Color(0xFFFED7AA), Color(0xFFFB923C), Color(0xFFC2410C)],
                setDialogState: setDialogState,
                isDark: isDark,
              ),
              _buildTextureChip(
                label: 'Celestial Cyan',
                effectKey: 'celestial_cyan',
                gradient: const [Color(0xFFE0F2FE), Color(0xFF38BDF8), Color(0xFF0284C7)],
                setDialogState: setDialogState,
                isDark: isDark,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Font Color Palette
          Text(
            'Font Color (When using flat color):',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Wrap(
                spacing: 10,
                children: [
                  const Color(0xFFFFFFFF), // Pure White
                  const Color(0xFFFBBF24), // Luminous Gold
                  const Color(0xFFF59E0B), // Amber Sun
                  const Color(0xFFFFFBEB), // Ivory Cream
                  const Color(0xFF38BDF8), // Celestial Cyan
                  const Color(0xFFFDA4AF), // Rose Coral
                  const Color(0xFF0F172A), // Dark Onyx
                ].map((c) {
                  final isCurrent = _customTextColor.value == c.value;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        _customTextColor = c;
                        _textTextureEffect = 'flat';
                      });
                      setState(() {
                        _customTextColor = c;
                        _textTextureEffect = 'flat';
                      });
                      _saveStylingPreferences();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? const Color(0xFF6366F1) : Colors.black26,
                          width: isCurrent ? 3 : 1,
                        ),
                      ),
                      child: isCurrent ? Icon(Icons.check, size: 16, color: c.computeLuminance() > 0.5 ? Colors.black : Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.colorize_rounded, size: 14),
                label: const Text('Custom...'),
                onPressed: () {
                  _showFullColorPickerDialog(
                    currentColor: _customTextColor,
                    onColorSelected: (c) {
                      setDialogState(() {
                        _customTextColor = c;
                        _textTextureEffect = 'flat';
                      });
                      setState(() {
                        _customTextColor = c;
                        _textTextureEffect = 'flat';
                      });
                      _saveStylingPreferences();
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 14),

          // Toggles: Uppercase & Outline
          Row(
            children: [
              Expanded(
                child: SwitchListTile(
                  title: const Text('ALL-CAPS UPPERCASE', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('Traditional bold church display style', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                  value: _isUppercase,
                  activeColor: const Color(0xFF6366F1),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => _isUppercase = val);
                    setState(() => _isUppercase = val);
                    _saveStylingPreferences();
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: SwitchListTile(
                  title: const Text('Text Outline / Stroke', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: const Text('High-contrast black outline for busy backgrounds', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
                  value: _hasTextOutline,
                  activeColor: const Color(0xFF6366F1),
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setDialogState(() => _hasTextOutline = val);
                    setState(() => _hasTextOutline = val);
                    _saveStylingPreferences();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextureChip({
    required String label,
    required String effectKey,
    required List<Color>? gradient,
    required StateSetter setDialogState,
    required bool isDark,
  }) {
    final isSelected = _textTextureEffect == effectKey;

    return InkWell(
      onTap: () {
        setDialogState(() => _textTextureEffect = effectKey);
        setState(() => _textTextureEffect = effectKey);
        _saveStylingPreferences();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient != null ? LinearGradient(colors: gradient) : null,
          color: gradient == null ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)) : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1) : Colors.transparent,
            width: isSelected ? 2.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: gradient != null ? Colors.black : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TAB 3: REFERENCE BADGE CUSTOMIZER
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBadgeCustomizerTab(bool isDark, StateSetter setDialogState) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reference Badge Color:',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Wrap(
                spacing: 10,
                children: [
                  const Color(0xFFF59E0B), // Golden
                  const Color(0xFF0284C7), // Sky Blue
                  const Color(0xFFE11D48), // Crimson
                  const Color(0xFF059669), // Emerald
                  const Color(0xFF6366F1), // Royal Indigo
                  const Color(0xFF1E293B), // Charcoal Dark
                ].map((c) {
                  final isCurrent = _customBadgeColor.value == c.value;
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        _customBadgeColor = c;
                        _customBadgeTextColor = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                      });
                      setState(() {
                        _customBadgeColor = c;
                        _customBadgeTextColor = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                      });
                      _saveStylingPreferences();
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCurrent ? Colors.white : Colors.black26,
                          width: isCurrent ? 3 : 1,
                        ),
                      ),
                      child: isCurrent ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 14),
              OutlinedButton.icon(
                icon: const Icon(Icons.colorize_rounded, size: 14),
                label: const Text('Custom...'),
                onPressed: () {
                  _showFullColorPickerDialog(
                    currentColor: _customBadgeColor,
                    onColorSelected: (c) {
                      setDialogState(() {
                        _customBadgeColor = c;
                        _customBadgeTextColor = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                      });
                      setState(() {
                        _customBadgeColor = c;
                        _customBadgeTextColor = c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
                      });
                      _saveStylingPreferences();
                    },
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 14),

          SwitchListTile(
            title: const Text('Show Translation Abbreviation in Badge', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: const Text('Displays "• KJV" or "• AMP" next to the scripture address', style: TextStyle(fontFamily: 'Poppins', fontSize: 11)),
            value: _showTranslationInBadge,
            activeColor: const Color(0xFF6366F1),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setDialogState(() => _showTranslationInBadge = val);
              setState(() => _showTranslationInBadge = val);
              _saveStylingPreferences();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onSelected,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullColorPickerDialog({
    required Color currentColor,
    required ValueChanged<Color> onColorSelected,
  }) {
    Color picked = currentColor;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick Color', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (c) => picked = c,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.7,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              onColorSelected(picked);
              Navigator.pop(ctx);
            },
            child: const Text('Select'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // THE LIVE PROJECTOR CANVAS (Renders on Stage and in Fullscreen)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildProjectorCanvas({
    required BibleVerse? verse,
    required String translation,
  }) {
    // 1. Blackout State: Complete pitch black
    if (_isBlackout) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          '• BLACKOUT ACTIVE •',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFF334155),
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      );
    }

    // 2. Clear Text State: Background active without scripture text
    if (_isCleared) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundLayer(),
          Center(
            child: Text(
              '• TEXT CLEARED •',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.3),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      );
    }

    // 3. Normal Live Scripture Presentation Slide
    final rawVerseText = verse?.text ?? 'For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.';
    final verseText = _isUppercase ? rawVerseText.toUpperCase() : rawVerseText;
    final bookName = verse?.bookName ?? _currentBook.name;
    final chapter = verse?.chapter ?? _currentChapter;
    final verseNum = verse?.verse ?? _currentVerse;

    // Adjust font size dynamically if the verse is very long to prevent overflow
    double effectiveFontSize = _fontSize;
    if (verseText.length > 250) {
      effectiveFontSize = (_fontSize * 0.78).clamp(20.0, 50.0);
    } else if (verseText.length > 150) {
      effectiveFontSize = (_fontSize * 0.88).clamp(24.0, 56.0);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background layer (Custom Image, Color, Gradient, or Theme Preset)
        _buildBackgroundLayer(),

        // Foreground scripture content
        _isLowerThird
            ? _buildLowerThirdLayout(verseText, bookName, chapter, verseNum, translation, effectiveFontSize)
            : _buildCenterLayout(verseText, bookName, chapter, verseNum, translation, effectiveFontSize),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // BACKGROUND LAYER GENERATOR
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildBackgroundLayer() {
    // 1. Custom Image picked from computer
    if (_bgMode == 'image' && _customImagePath != null && File(_customImagePath!).existsSync()) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_customImagePath!),
            fit: BoxFit.cover,
          ),
          if (_bgBlur > 0)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: _bgBlur, sigmaY: _bgBlur),
              child: Container(color: Colors.transparent),
            ),
          if (_bgDimmerOpacity > 0)
            Container(color: Colors.black.withOpacity(_bgDimmerOpacity)),
        ],
      );
    }

    // 2. Curated Church Preset
    if (_bgMode == 'curated') {
      final preset = _currentCuratedPreset;
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: preset.begin,
            end: preset.end,
            colors: preset.colors,
          ),
        ),
        child: _bgDimmerOpacity > 0
            ? Container(color: Colors.black.withOpacity(_bgDimmerOpacity))
            : null,
      );
    }

    // 3. Custom Solid Color
    if (_bgMode == 'color') {
      return Container(
        color: _customBgColor,
        child: _bgDimmerOpacity > 0
            ? Container(color: Colors.black.withOpacity(_bgDimmerOpacity))
            : null,
      );
    }

    // 4. Default Preset Theme
    final theme = _currentTheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradientColors,
        ),
      ),
      child: _bgDimmerOpacity > 0
          ? Container(color: Colors.black.withOpacity(_bgDimmerOpacity))
          : null,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // TEXT SHADER / TEXTURE ENGINE (Metallic Gold Foil / Silver / Bronze)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _applyTextTexture(Widget textChild) {
    if (_textTextureEffect == 'gold_foil') {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFFF9C4),
            Color(0xFFFFD54F),
            Color(0xFFFFB300),
            Color(0xFFFFA000),
            Color(0xFFFFF8E1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: textChild,
      );
    } else if (_textTextureEffect == 'silver_foil') {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFE2E8F0),
            Color(0xFF94A3B8),
            Color(0xFFCBD5E1),
            Color(0xFFFFFFFF),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: textChild,
      );
    } else if (_textTextureEffect == 'bronze_fire') {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFFED7AA),
            Color(0xFFFB923C),
            Color(0xFFEA580C),
            Color(0xFFC2410C),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bounds),
        child: textChild,
      );
    } else if (_textTextureEffect == 'celestial_cyan') {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => const LinearGradient(
          colors: [
            Color(0xFFE0F2FE),
            Color(0xFF38BDF8),
            Color(0xFF0284C7),
            Color(0xFFBAE6FD),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: textChild,
      );
    }
    return textChild;
  }

  TextStyle _getVerseTextStyle(double effectiveFontSize) {
    Color col = _textTextureEffect == 'flat' ? _customTextColor : Colors.white;

    // Base typography styling
    TextStyle style;
    switch (_fontFamily) {
      case 'Merriweather':
        style = GoogleFonts.merriweather(fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
      case 'Playfair Display':
        style = GoogleFonts.playfairDisplay(fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
      case 'Montserrat':
        style = GoogleFonts.montserrat(fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
      case 'Roboto':
        style = GoogleFonts.roboto(fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
      case 'Poppins':
        style = TextStyle(fontFamily: 'Poppins', fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
      case 'Cinzel':
      default:
        style = TextStyle(fontFamily: 'Cinzel', fontSize: effectiveFontSize, fontWeight: _fontWeight, color: col, height: 1.45);
        break;
    }

    return style.copyWith(
      shadows: [
        Shadow(
          color: Colors.black.withOpacity(0.85),
          blurRadius: _shadowBlur,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Full Center Worship Layout (Standard Church Projector)
  Widget _buildCenterLayout(
    String text,
    String bookName,
    int chapter,
    int verseNum,
    String translation,
    double effectiveFontSize,
  ) {
    final badgeBg = _customBadgeColor;
    final badgeText = _customBadgeTextColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Scripture Reference Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: badgeBg.withOpacity(0.92),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: badgeBg.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${bookName.toUpperCase()} $chapter:$verseNum',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    color: badgeText,
                  ),
                ),
                if (_showTranslationInBadge) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '•',
                      style: TextStyle(color: badgeText.withOpacity(0.7)),
                    ),
                  ),
                  Text(
                    translation,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: badgeText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Bold Scripture Verse Body with Metallic Shader Texture & Shadow
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _applyTextTexture(
                  Text(
                    text,
                    textAlign: _textAlign,
                    style: _getVerseTextStyle(effectiveFontSize),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Lower-Third Layout (For live streaming, OBS, and vMix camera overlays)
  Widget _buildLowerThirdLayout(
    String text,
    String bookName,
    int chapter,
    int verseNum,
    String translation,
    double effectiveFontSize,
  ) {
    return Column(
      children: [
        const Spacer(),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: _customBadgeColor, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: _customBadgeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${bookName.toUpperCase()} $chapter:$verseNum',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _customBadgeTextColor,
                      ),
                    ),
                  ),
                  if (_showTranslationInBadge) ...[
                    const SizedBox(width: 8),
                    Text(
                      translation,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _customBadgeColor,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _applyTextTexture(
                Text(
                  text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: _getVerseTextStyle((effectiveFontSize * 0.65).clamp(16.0, 32.0)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FULLSCREEN PRESENTATION STAGE (F11)
  // ─────────────────────────────────────────────────────────────────────────────

  Widget _buildFullscreenProjector() {
    return Stack(
      children: [
        // Live Screen Canvas
        Positioned.fill(
          child: _buildProjectorCanvas(
            verse: _isFrozen ? _frozenVerse : _activeVerse,
            translation: _isFrozen ? (_frozenTranslation ?? _currentTranslation) : _currentTranslation,
          ),
        ),

        // Floating Auto-Hiding Control Bar on Top Right
        Positioned(
          top: 16,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  tooltip: 'Previous Verse (Left Arrow)',
                  onPressed: _previousVerse,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  tooltip: 'Next Verse (Right Arrow / Space)',
                  onPressed: _nextVerse,
                ),
                const SizedBox(width: 6),
                Container(width: 1, height: 18, color: Colors.white24),
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    _isBlackout ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: _isBlackout ? const Color(0xFFEF4444) : Colors.white,
                    size: 20,
                  ),
                  tooltip: 'Toggle Blackout (B)',
                  onPressed: () => setState(() => _isBlackout = !_isBlackout),
                ),
                IconButton(
                  icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.white, size: 20),
                  tooltip: 'Exit Fullscreen (Esc / F11)',
                  onPressed: () => setState(() => _isFullscreenStage = false),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
