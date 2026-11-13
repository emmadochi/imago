// lib/screens/bible_screen.dart
// Full offline Bible reader for Imago — Book picker, Chapter grid, Verse reader, Search

import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../services/tts_service.dart';
import '../theme/imago_theme.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../services/dictionary_service.dart';
import '../services/crossref_service.dart';
import '../widgets/color_picker_sheet.dart';
import '../widgets/note_editor_sheet.dart';
import '../widgets/tag_editor_sheet.dart';
import '../widgets/crossref_sheet.dart';
import '../widgets/commentary_sheet.dart';
import '../widgets/typography_sheet.dart';
import '../models/feedback_model.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/formatted_definition_text.dart';
import '../widgets/book_chapter_verse_picker_sheet.dart';
import '../widgets/bible_search_scope_sheet.dart';
import '../widgets/desktop_study_inspector.dart';
import '../widgets/bible_audio_settings_sheet.dart';
import '../data/topical_index.dart';
import 'bible_lists_screen.dart';
import 'saved_verses_screen.dart';
import 'reading_plans_screen.dart';
import 'scripture_projector_screen.dart';
import 'journal_editor_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _BibleView { books, chapters, verses, reader, search }

class BibleScreen extends StatefulWidget {
  final int? initialBook;
  final int? initialChapter;

  const BibleScreen({super.key, this.initialBook, this.initialChapter});

  static final ValueNotifier<bool> distractionFreeNotifier = ValueNotifier(false);

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _PassageHistoryItem {
  final BibleBook book;
  final int chapter;
  final int verse;
  final String label;

  const _PassageHistoryItem({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.label,
  });
}

class _BibleScreenState extends State<BibleScreen>
    with SingleTickerProviderStateMixin {
  _BibleView _view = _BibleView.books;
  BibleBook? _selectedBook;
  int _selectedChapter = 1;
  int _selectedVerse = 1;
  List<BibleVerse> _verses = [];
  int _chapterCount = 0;
  int _verseCount = 30;
  bool _loading = false;
  bool _initialized = false;
  final List<_PassageHistoryItem> _navigationHistory = [];

  // Search
  final _searchController = TextEditingController();
  List<BibleVerse> _searchResults = [];
  bool _searching = false;
  BibleSearchMatchType _searchMatchType = BibleSearchMatchType.exactPhrase;
  List<int>? _searchBookFilter;
  String _searchScopeLabel = 'Entire Bible';
  String? _searchGroupName;
  int? _highlightedTargetVerse;

  // Desktop Study Station & Multi-Verse Copy / Highlight
  bool _showDesktopInspector = false;
  DesktopInspectorTab _desktopInspectorTab = DesktopInspectorTab.parallel;
  BibleVerse? _focusedVerse;
  final Set<int> _selectedVerseNumbers = {};
  int? _hoveredVerseNum;

  // Translation & Parallel
  late String _translation;
  String? _parallelTranslation;
  bool _showParallel = false;

  // Dictionary & Layout

  // Audio Player & Sacred Sound
  bool _isPlayingAudio = false;
  bool _isAudioPaused = false;
  int _currentAudioVerseIndex = 0;
  int _playbackSessionId = 0;
  int? _playingVerseNum;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _verseKeys = {};

  GlobalKey _getVerseKey(int verseNum) {
    return _verseKeys.putIfAbsent(verseNum, () => GlobalKey());
  }
  bool _isDistractionFree = false;
  ReaderThemeMode _readerThemeMode = ReaderThemeMode.night;
  String _fontFamily = 'Poppins';
  double _fontSize = 15.5;
  double _lineHeight = 1.7;

  // User Data
  Set<int> _bookmarkedVerses = {};
  List<BibleHighlight> _chapterHighlights = [];
  Map<int, BibleNote> _chapterNotes = {};
  Map<int, List<BibleTag>> _chapterTags = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadTypographySettings();
  }

  Future<void> _loadTypographySettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeInt = prefs.getInt('readerTheme');
    final savedThemeStr = prefs.getString('reader_theme_mode');
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    final ReaderThemeMode resolvedMode;
    if (savedThemeInt != null && savedThemeInt >= 0 && savedThemeInt < ReaderThemeMode.values.length) {
      resolvedMode = ReaderThemeMode.values[savedThemeInt];
    } else if (savedThemeStr != null) {
      resolvedMode = ReaderTheme.fromString(savedThemeStr).mode;
    } else {
      resolvedMode = isDesktop ? ReaderThemeMode.day : readerThemeNotifier.value;
    }

    if (readerThemeNotifier.value != resolvedMode) {
      readerThemeNotifier.value = resolvedMode;
    }

    setState(() {
      _readerThemeMode = resolvedMode;
      _fontFamily = prefs.getString('typography_font') ?? 'Poppins';
      _fontSize = prefs.getDouble('typography_size') ?? 15.5;
      _lineHeight = prefs.getDouble('typography_line_height') ?? 1.7;
    });
  }

  Future<void> _saveTypographySettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readerTheme', _readerThemeMode.index);
    await prefs.setString('reader_theme_mode', _readerThemeMode.name);
    await prefs.setString('typography_font', _fontFamily);
    await prefs.setDouble('typography_size', _fontSize);
    await prefs.setDouble('typography_line_height', _lineHeight);
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    await BibleService.instance.init();
    _translation = BibleService.instance.currentTranslation;
    setState(() {
      _loading = false;
      _initialized = true;
    });

    if (widget.initialBook != null && mounted) {
      final b = kBibleBooks.firstWhere((book) => book.number == widget.initialBook, orElse: () => kBibleBooks.first);
      await _selectBook(b, navigateToChapters: false);
      _selectedChapter = widget.initialChapter ?? 1;
      await _openReader(targetVerse: 1);
    }
  }

  Future<void> _selectBook(BibleBook book, {bool navigateToChapters = true}) async {
    _resetDistractionFree();
    setState(() {
      _selectedBook = book;
      _loading = true;
    });
    final count = await BibleService.instance.getChapterCount(book.number);
    setState(() {
      _chapterCount = count;
      if (navigateToChapters) {
        _view = _BibleView.chapters;
      }
      _loading = false;
    });
  }

  Future<void> _selectChapter(int chapter, {int? targetVerse}) async {
    setState(() {
      _selectedChapter = chapter;
      _loading = true;
    });
    final count = await BibleService.instance.getVerseCount(_selectedBook!.number, chapter);
    setState(() {
      _verseCount = count > 0 ? count : 30;
    });

    if (targetVerse != null) {
      await _openReader(targetVerse: targetVerse);
    } else {
      _resetDistractionFree();
      setState(() {
        _view = _BibleView.verses;
        _loading = false;
      });
    }
  }

  Future<void> _openReader({int targetVerse = 1}) async {
    setState(() => _loading = true);
    final verses = await BibleService.instance.getVerses(_selectedBook!.number, _selectedChapter);
    await _loadChapterUserData(_selectedBook!.number, _selectedChapter);
    _verseKeys.clear();
    setState(() {
      _verses = verses;
      _selectedVerse = targetVerse;
      _view = _BibleView.reader;
      _loading = false;
    });

    if (targetVerse > 1) {
      _scrollToVerse(targetVerse);
    } else if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _changeReaderChapter(int newChapter) async {
    setState(() {
      _selectedChapter = newChapter;
      _loading = true;
    });
    final count = await BibleService.instance.getVerseCount(_selectedBook!.number, newChapter);
    final verses = await BibleService.instance.getVerses(_selectedBook!.number, newChapter);
    await _loadChapterUserData(_selectedBook!.number, newChapter);
    _verseKeys.clear();
    setState(() {
      _verseCount = count > 0 ? count : 30;
      _verses = verses;
      _selectedVerse = 1;
      _loading = false;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _scrollToVerse(int targetVerse, {bool animate = true, bool highlight = true}) {
    if (highlight) {
      setState(() => _highlightedTargetVerse = targetVerse);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final targetKey = _verseKeys[targetVerse];
      final currentCtx = targetKey?.currentContext;

      if (currentCtx != null) {
        Scrollable.ensureVisible(
          currentCtx,
          alignment: 0.10,
          duration: animate ? const Duration(milliseconds: 400) : Duration.zero,
          curve: Curves.easeOutCubic,
        );
      } else {
        // Two-phase scroll: Verse not yet rendered by ListView.builder cache
        final targetIndex = _verses.indexWhere((v) => v.verse == targetVerse);
        if (targetIndex >= 0 && _verses.isNotEmpty) {
          int charsBefore = 0;
          int totalChars = 0;
          for (int i = 0; i < _verses.length; i++) {
            final len = _verses[i].text.length + 35;
            if (i < targetIndex) charsBefore += len;
            totalChars += len;
          }
          final progress = totalChars > 0 ? (charsBefore / totalChars) : (targetIndex / _verses.length);

          final approxVerseHeight = (_fontSize * _lineHeight * 3.0) + 28.0;
          final fallbackOffset = targetIndex * approxVerseHeight;
          final maxExtent = _scrollController.position.hasContentDimensions
              ? _scrollController.position.maxScrollExtent
              : fallbackOffset;
          final jumpOffset = (progress * maxExtent).clamp(0.0, maxExtent);

          _scrollController.jumpTo(jumpOffset > 0 ? jumpOffset : fallbackOffset);

          // Once the target vicinity is mounted, lock exactly onto the target verse
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final updatedCtx = _verseKeys[targetVerse]?.currentContext;
            if (updatedCtx != null) {
              Scrollable.ensureVisible(
                updatedCtx,
                alignment: 0.10,
                duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }

      if (highlight) {
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _highlightedTargetVerse == targetVerse) {
            setState(() => _highlightedTargetVerse = null);
          }
        });
      }
    });
  }

  void _openPassagePicker(ReaderTheme readerTheme) {
    BookChapterVersePickerSheet.show(
      context: context,
      initialBook: _selectedBook ?? kBibleBooks.first,
      initialChapter: _selectedChapter,
      initialVerse: _selectedVerse,
      readerTheme: readerTheme,
      onSelected: (book, chapter, verse) async {
        setState(() => _navigationHistory.clear());
        await _selectBook(book, navigateToChapters: false);
        _selectedChapter = chapter;
        await _openReader(targetVerse: verse);
      },
    );
  }
  
  Future<void> _loadChapterUserData(int bookId, int chapterId) async {
    final bookmarks = await UserDataService.instance.getBookmarks();
    final highlights = await UserDataService.instance.getHighlightsForChapter(bookId, chapterId);
    final notes = await UserDataService.instance.getNotesForChapter(bookId, chapterId);
    final tags = await UserDataService.instance.getTagsForChapter(bookId, chapterId);

    if (!mounted) return;
    setState(() {
      _bookmarkedVerses = bookmarks.where((b) => b.book == bookId && b.chapter == chapterId).map((b) => b.verse).toSet();
      _chapterHighlights = highlights;
      _chapterNotes = {for (var n in notes) n.verse: n};
      
      _chapterTags.clear();
      for (var t in tags) {
        _chapterTags.putIfAbsent(t.verse, () => []).add(t);
      }
    });
  }

  Future<void> _runSearch([String? queryOverride]) async {
    final query = queryOverride ?? _searchController.text;
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await BibleService.instance.search(
      query,
      matchType: _searchMatchType,
      bookFilter: _searchBookFilter,
    );
    if (!mounted) return;
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _switchTranslation(String abbr) async {
    await BibleService.instance.setTranslation(abbr);
    setState(() => _translation = abbr);
    // Reload current view with new translation
    if (_selectedBook != null) {
      final count = await BibleService.instance.getChapterCount(_selectedBook!.number);
      final vCount = await BibleService.instance.getVerseCount(_selectedBook!.number, _selectedChapter);
      setState(() {
        _chapterCount = count;
        _verseCount = vCount > 0 ? vCount : 30;
      });
      if (_view == _BibleView.reader) {
        await _openReader(targetVerse: _selectedVerse);
      }
    }
  }

  Future<void> _playChapterAudio({int startIndex = 0}) async {
    await _stopAudio();
    final sessionId = ++_playbackSessionId;
    setState(() {
      _isPlayingAudio = true;
      _isAudioPaused = false;
      _currentAudioVerseIndex = startIndex.clamp(0, _verses.isEmpty ? 0 : _verses.length - 1);
    });

    // Start background ambient music once per audio session; plays continuously across verses
    if (!TtsService.instance.isAmbientPlaying) {
      await TtsService.instance.startAmbient();
    }

    while (mounted && _isPlayingAudio && sessionId == _playbackSessionId) {
      while (_currentAudioVerseIndex < _verses.length) {
        if (!mounted || !_isPlayingAudio || sessionId != _playbackSessionId) break;

        // Handle pause state
        while (_isAudioPaused) {
          if (!mounted || !_isPlayingAudio || sessionId != _playbackSessionId) break;
          await Future.delayed(const Duration(milliseconds: 150));
        }
        if (!mounted || !_isPlayingAudio || sessionId != _playbackSessionId) break;

        final verse = _verses[_currentAudioVerseIndex];
        setState(() => _playingVerseNum = verse.verse);

        // Scroll to current reading verse smoothly with exact verse alignment
        _scrollToVerse(verse.verse, animate: true, highlight: false);

        await TtsService.instance.speakAndWait(verse.text, withAmbient: false);

        if (!mounted || !_isPlayingAudio || sessionId != _playbackSessionId) break;
        if (!_isAudioPaused) {
          _currentAudioVerseIndex++;
          // Inter-verse breathing delay: give hardware audio buffers time to clear
          // and create natural, reverent scripture cadence without skipping verses
          await Future.delayed(const Duration(milliseconds: 280));
        }
      }

      if (!mounted || !_isPlayingAudio || sessionId != _playbackSessionId || _isAudioPaused) break;

      // Chapter finished! Automatically transition to the next chapter until stopped
      bool chapterAdvanced = false;
      if (_selectedChapter < _chapterCount) {
        // Next chapter within current book
        final nextChapter = _selectedChapter + 1;
        await _changeReaderChapter(nextChapter);
        if (mounted && sessionId == _playbackSessionId) {
          setState(() {
            _currentAudioVerseIndex = 0;
            _playingVerseNum = null;
          });
          chapterAdvanced = true;
        }
      } else if (_selectedBook != null && kBibleBooks.isNotEmpty) {
        // End of current book reached — advance to the next book chapter 1 if available
        final currentIdx = kBibleBooks.indexWhere((b) => b.number == _selectedBook!.number);
        if (currentIdx >= 0 && currentIdx < kBibleBooks.length - 1) {
          final nextBook = kBibleBooks[currentIdx + 1];
          await _selectBook(nextBook, navigateToChapters: false);
          await _changeReaderChapter(1);
          if (mounted && sessionId == _playbackSessionId) {
            setState(() {
              _currentAudioVerseIndex = 0;
              _playingVerseNum = null;
            });
            chapterAdvanced = true;
          }
        }
      }

      if (!chapterAdvanced) {
        // End of the Bible or could not advance
        break;
      }

      // Natural reverent breathing delay between chapters (800ms)
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (sessionId == _playbackSessionId && mounted && _isPlayingAudio && !_isAudioPaused) {
      await _stopAudio();
    }
  }

  Future<void> _pauseAudio() async {
    setState(() => _isAudioPaused = true);
    await TtsService.instance.pause();
    await TtsService.instance.pauseAmbient();
  }

  void _resumeAudio() {
    setState(() => _isAudioPaused = false);
    TtsService.instance.resumeAmbient();
  }

  void _togglePauseAudio() {
    if (_isAudioPaused) {
      _resumeAudio();
    } else {
      _pauseAudio();
    }
  }

  Future<void> _skipNextVerse() async {
    if (_currentAudioVerseIndex < _verses.length - 1) {
      await _playChapterAudio(startIndex: _currentAudioVerseIndex + 1);
    } else if (_selectedChapter < _chapterCount) {
      // Skip seamlessly into next chapter's first verse
      await _changeReaderChapter(_selectedChapter + 1);
      await _playChapterAudio(startIndex: 0);
    } else if (_selectedBook != null && kBibleBooks.isNotEmpty) {
      final currentIdx = kBibleBooks.indexWhere((b) => b.number == _selectedBook!.number);
      if (currentIdx >= 0 && currentIdx < kBibleBooks.length - 1) {
        final nextBook = kBibleBooks[currentIdx + 1];
        await _selectBook(nextBook, navigateToChapters: false);
        await _changeReaderChapter(1);
        await _playChapterAudio(startIndex: 0);
      }
    }
  }

  Future<void> _skipPreviousVerse() async {
    if (_currentAudioVerseIndex > 0) {
      await _playChapterAudio(startIndex: _currentAudioVerseIndex - 1);
    } else if (_selectedChapter > 1) {
      // Skip back into previous chapter's last verse
      final prevChapter = _selectedChapter - 1;
      await _changeReaderChapter(prevChapter);
      await _playChapterAudio(startIndex: _verses.isNotEmpty ? _verses.length - 1 : 0);
    } else if (_selectedBook != null && kBibleBooks.isNotEmpty) {
      final currentIdx = kBibleBooks.indexWhere((b) => b.number == _selectedBook!.number);
      if (currentIdx > 0) {
        final prevBook = kBibleBooks[currentIdx - 1];
        await _selectBook(prevBook, navigateToChapters: false);
        await _changeReaderChapter(_chapterCount);
        await _playChapterAudio(startIndex: _verses.isNotEmpty ? _verses.length - 1 : 0);
      }
    }
  }

  Future<void> _stopAudio() async {
    _playbackSessionId++;
    await TtsService.instance.stop(stopAmbientSound: true);
    await TtsService.instance.stopAmbient();
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
        _isAudioPaused = false;
        _playingVerseNum = null;
      });
    }
  }

  void _toggleDistractionFree() {
    if (_view != _BibleView.reader) return;
    setState(() {
      _isDistractionFree = !_isDistractionFree;
      BibleScreen.distractionFreeNotifier.value = _isDistractionFree;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (_isDistractionFree) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      }
    });
  }

  void _resetDistractionFree() {
    if (_isDistractionFree) {
      _isDistractionFree = false;
      BibleScreen.distractionFreeNotifier.value = false;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  Future<void> _jumpToPassage({
    required int bookNumber,
    required int chapter,
    required int verse,
    bool recordHistory = true,
  }) async {
    if (recordHistory && _selectedBook != null) {
      final currentV = _focusedVerse?.verse ?? (_selectedVerse > 0 ? _selectedVerse : 1);
      final historyItem = _PassageHistoryItem(
        book: _selectedBook!,
        chapter: _selectedChapter,
        verse: currentV,
        label: '${_selectedBook!.name} $_selectedChapter:$currentV',
      );
      if (_navigationHistory.isEmpty || _navigationHistory.last.label != historyItem.label) {
        _navigationHistory.add(historyItem);
      }
    }
    final book = kBibleBooks.firstWhere((bk) => bk.number == bookNumber, orElse: () => kBibleBooks.first);
    await _selectBook(book, navigateToChapters: false);
    await _selectChapter(chapter, targetVerse: verse);
    if (mounted) setState(() {});
  }

  Future<void> _popNavigationHistory() async {
    if (_navigationHistory.isNotEmpty) {
      final prev = _navigationHistory.removeLast();
      await _selectBook(prev.book, navigateToChapters: false);
      await _selectChapter(prev.chapter, targetVerse: prev.verse);
      if (mounted) setState(() {});
    }
  }

  Widget _buildFloatingHistoryPill(ReaderTheme readerTheme) {
    if (_navigationHistory.isEmpty) return const SizedBox.shrink();
    final target = _navigationHistory.last;

    return Positioned(
      top: 14,
      left: 0,
      right: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          elevation: 6,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
            decoration: BoxDecoration(
              color: readerTheme.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: readerTheme.accentColor.withOpacity(0.55),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(readerTheme.isDark ? 0.35 : 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.undo_rounded, size: 16, color: readerTheme.accentColor),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _popNavigationHistory,
                  child: Text(
                    'Return to ${target.label}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: readerTheme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _navigationHistory.clear()),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: readerTheme.borderColor.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 14, color: readerTheme.secondaryText),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBack() {
    if (_isDistractionFree) {
      _toggleDistractionFree();
      return;
    }
    if (_view == _BibleView.reader && _navigationHistory.isNotEmpty) {
      _popNavigationHistory();
      return;
    }
    setState(() {
      _navigationHistory.clear();
      if (_view == _BibleView.reader) {
        _view = _BibleView.verses;
        _stopAudio();
      } else if (_view == _BibleView.verses) {
        _view = _BibleView.chapters;
      } else if (_view == _BibleView.chapters) {
        _view = _BibleView.books;
      } else if (_view == _BibleView.search) {
        _view = _BibleView.books;
        _stopAudio();
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  @override
  void dispose() {
    if (_isDistractionFree) {
      BibleScreen.distractionFreeNotifier.value = false;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    _searchController.dispose();
    _scrollController.dispose();
    _verseKeys.clear();
    _stopAudio();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ReaderThemeMode>(
      valueListenable: readerThemeNotifier,
      builder: (context, globalThemeMode, _) {
        final readerTheme = ReaderTheme.of(globalThemeMode);

        return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, control: true): () {
          if (_selectedVerseNumbers.isNotEmpty) {
            _copySelectedVerses();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          setState(() {
            _showDesktopInspector = !_showDesktopInspector;
            if (_showDesktopInspector && _focusedVerse == null && _verses.isNotEmpty) {
              _focusedVerse = _verses.first;
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          setState(() => _view = _BibleView.search);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_selectedVerseNumbers.isNotEmpty) {
            setState(() => _selectedVerseNumbers.clear());
          } else if (_isDistractionFree) {
            _toggleDistractionFree();
          } else if (_showDesktopInspector) {
            setState(() => _showDesktopInspector = false);
          }
        },
        const SingleActivator(LogicalKeyboardKey.f11): () {
          _toggleDistractionFree();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: readerTheme.isDark ? const Color(0xFF040510) : readerTheme.background,
      floatingActionButton: _view == _BibleView.reader
          ? Container(
              margin: EdgeInsets.only(
                bottom: _isDistractionFree ? 20 : 80,
                right: 8,
              ),
              child: _isPlayingAudio
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: readerTheme.isDark
                            ? const Color(0xFF101328).withOpacity(0.95)
                            : readerTheme.surface.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: readerTheme.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(readerTheme.isDark ? 0.45 : 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Previous verse
                          GestureDetector(
                            onTap: _skipPreviousVerse,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.skip_previous_rounded, size: 20, color: readerTheme.primaryText),
                            ),
                          ),
                          // Play / Pause
                          GestureDetector(
                            onTap: _togglePauseAudio,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: readerTheme.accentColor,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isAudioPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Next verse
                          GestureDetector(
                            onTap: _skipNextVerse,
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.skip_next_rounded, size: 20, color: readerTheme.primaryText),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Verse pill
                          if (_playingVerseNum != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: readerTheme.accentColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'v.$_playingVerseNum',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: readerTheme.accentColor,
                                ),
                              ),
                            ),
                          const SizedBox(width: 4),
                          // Audio Settings (Speed, Tone, Ambient)
                          GestureDetector(
                            onTap: () => BibleAudioSettingsSheet.show(context, readerTheme: readerTheme),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.tune_rounded, size: 19, color: readerTheme.accentColor),
                            ),
                          ),
                          // Stop
                          GestureDetector(
                            onTap: _stopAudio,
                            child: const Padding(
                              padding: EdgeInsets.all(6),
                              child: Icon(Icons.close_rounded, size: 19, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Tooltip(
                      message: 'Play Chapter Audio (Long-press for Audio Studio)',
                      child: GestureDetector(
                        onLongPress: () => BibleAudioSettingsSheet.show(context, readerTheme: readerTheme),
                        onTap: _playChapterAudio,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: readerTheme.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: readerTheme.accentColor.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
            )
          : null,
      body: Stack(
        children: [
          if (readerTheme.isDark) ...[
            const CosmicBackground(children: []),
            // Ambient orb
            Positioned(
              top: -40, left: -40,
              child: CosmicOrb(size: 260, color: const Color(0xFF3D5AFE), opacity: 0.07),
            ),
          ] else
            Container(color: readerTheme.background),
          SafeArea(
            top: !_isDistractionFree,
            bottom: !_isDistractionFree,
            child: Column(
              children: [
                if (!_isDistractionFree) _buildHeader(readerTheme),
                if (!_initialized || _loading)
                  Expanded(child: Center(child: CircularProgressIndicator(color: readerTheme.verseNumberColor)))
                else
                  Expanded(child: _buildBody(readerTheme)),
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
  }

  Widget _buildHeader(ReaderTheme readerTheme) {
    String title;
    bool showBack = false;

    switch (_view) {
      case _BibleView.books:
        title = 'The Bible';
      case _BibleView.chapters:
        title = _selectedBook?.name ?? 'Chapters';
        showBack = true;
      case _BibleView.verses:
        title = '${_selectedBook?.name} $_selectedChapter';
        showBack = true;
      case _BibleView.reader:
        title = '${_selectedBook?.name} $_selectedChapter';
        showBack = true;
      case _BibleView.search:
        title = 'Search';
        showBack = true;
    }

    final isSmallScreen = MediaQuery.of(context).size.width < 700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: readerTheme.surface,
        border: Border(bottom: BorderSide(color: readerTheme.borderColor)),
        boxShadow: readerTheme.isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          if (showBack) ...[
            GestureDetector(
              onTap: _goBack,
              child: Tooltip(
                message: _view == _BibleView.reader && _navigationHistory.isNotEmpty
                    ? 'Return to ${_navigationHistory.last.label}'
                    : 'Back',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _view == _BibleView.reader && _navigationHistory.isNotEmpty
                        ? readerTheme.accentColor.withOpacity(0.15)
                        : readerTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _view == _BibleView.reader && _navigationHistory.isNotEmpty
                          ? readerTheme.accentColor.withOpacity(0.6)
                          : readerTheme.borderColor.withOpacity(0.5),
                    ),
                  ),
                  child: Icon(
                    _view == _BibleView.reader && _navigationHistory.isNotEmpty
                        ? Icons.undo_rounded
                        : Icons.arrow_back_rounded,
                    color: _view == _BibleView.reader && _navigationHistory.isNotEmpty
                        ? readerTheme.accentColor
                        : readerTheme.primaryText,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: _view == _BibleView.reader || _view == _BibleView.verses || _view == _BibleView.chapters
                  ? GestureDetector(
                      onTap: () => _openPassagePicker(readerTheme),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: readerTheme.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: readerTheme.borderColor.withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                _view == _BibleView.reader
                                    ? '${_selectedBook?.name ?? ""} $_selectedChapter${_selectedVerse > 1 ? ":$_selectedVerse" : ""}'
                                    : _view == _BibleView.verses
                                        ? '${_selectedBook?.name ?? ""} $_selectedChapter'
                                        : (_selectedBook?.name ?? ''),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: readerTheme.primaryText,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: readerTheme.accentColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    )
                  : Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: readerTheme.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Translation selector
          GestureDetector(
            onTap: _showTranslationPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                gradient: readerTheme.isDark ? ImagoColors.violetGradient : null,
                color: readerTheme.isDark ? null : readerTheme.accentColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: readerTheme.accentColor.withOpacity(0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _translation,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_showParallel && _parallelTranslation != null) ...[
                    const SizedBox(width: 6),
                    Container(width: 1, height: 12, color: Colors.white30),
                    const SizedBox(width: 6),
                    Text(
                      _parallelTranslation!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Search button
          GestureDetector(
            onTap: () => setState(() => _view = _BibleView.search),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: readerTheme.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: readerTheme.borderColor.withOpacity(0.5)),
              ),
              child: Icon(Icons.search_rounded, color: readerTheme.primaryText, size: 18),
            ),
          ),
          // Projector & Desktop inspector only on large screens
          if (_view == _BibleView.reader && !isSmallScreen) ...[
            const SizedBox(width: 8),
            Tooltip(
              message: 'Project Scripture (Worship / Screen Display)',
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScriptureProjectorScreen(
                        initialBook: _selectedBook,
                        initialChapter: _selectedChapter,
                        initialVerse: _selectedVerseNumbers.isNotEmpty
                            ? _selectedVerseNumbers.first
                            : _selectedVerse,
                        initialTranslation: _translation,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6366F1)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.present_to_all_rounded, color: Color(0xFF6366F1), size: 16),
                      SizedBox(width: 5),
                      Text(
                        'Project',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Study Station (Ctrl+P)',
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showDesktopInspector = !_showDesktopInspector;
                    if (_showDesktopInspector && _focusedVerse == null && _verses.isNotEmpty) {
                      _focusedVerse = _verses.first;
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _showDesktopInspector
                        ? readerTheme.accentColor.withOpacity(0.2)
                        : readerTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _showDesktopInspector
                          ? readerTheme.accentColor
                          : readerTheme.borderColor.withOpacity(0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: _showDesktopInspector
                        ? readerTheme.accentColor
                        : readerTheme.primaryText,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ReaderTheme readerTheme) {
    switch (_view) {
      case _BibleView.books:
        return _buildBookList(readerTheme);
      case _BibleView.chapters:
        return _buildChapterGrid(readerTheme);
      case _BibleView.verses:
        return _buildVerseGrid(readerTheme);
      case _BibleView.reader:
        return _buildVerseReader(readerTheme);
      case _BibleView.search:
        return _buildSearchView(readerTheme);
    }
  }

  // ─── Book List ────────────────────────────────────────────
  Widget _buildBookList(ReaderTheme readerTheme) {
    final ot = kBibleBooks.where((b) => b.isOldTestament).toList();
    final nt = kBibleBooks.where((b) => !b.isOldTestament).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _buildQuickActionsHeader(readerTheme),
        const SizedBox(height: 20),
        _sectionLabel('OLD TESTAMENT', readerTheme),
        const SizedBox(height: 10),
        _buildBookGrid(ot, readerTheme),
        const SizedBox(height: 24),
        _sectionLabel('NEW TESTAMENT', readerTheme),
        const SizedBox(height: 10),
        _buildBookGrid(nt, readerTheme),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildQuickActionsHeader(ReaderTheme readerTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('STUDY & PLAYLISTS', readerTheme),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickActionCard(
                icon: Icons.queue_music_rounded,
                title: 'Bible Lists',
                subtitle: 'Audio Lineups',
                color: const Color(0xFF6366F1),
                readerTheme: readerTheme,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const BibleListsScreen()));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.bookmark_rounded,
                title: 'Bookmarks',
                subtitle: 'Saved Verses',
                color: const Color(0xFFF59E0B),
                readerTheme: readerTheme,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SavedVersesScreen()));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionCard(
                icon: Icons.auto_stories_rounded,
                title: 'Plans',
                subtitle: 'Daily Reading',
                color: const Color(0xFF10B981),
                readerTheme: readerTheme,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ReadingPlansScreen()));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ReaderTheme readerTheme,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: readerTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: readerTheme.borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(readerTheme.isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(readerTheme.isDark ? 0.2 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: readerTheme.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: readerTheme.secondaryText,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, ReaderTheme readerTheme) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: readerTheme.isDark ? ImagoColors.gold.withOpacity(0.8) : readerTheme.accentColor,
        fontSize: 11.5,
        letterSpacing: 2.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildBookGrid(List<BibleBook> books, ReaderTheme readerTheme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: books.length,
      itemBuilder: (ctx, i) {
        final book = books[i];
        return GestureDetector(
          onTap: () => _selectBook(book),
          child: Container(
            decoration: BoxDecoration(
              color: readerTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: readerTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Text(
                book.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: readerTheme.primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Chapter Grid ─────────────────────────────────────────
  Widget _buildChapterGrid(ReaderTheme readerTheme) {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _chapterCount,
      itemBuilder: (ctx, i) {
        final chap = i + 1;
        final isSelected = chap == _selectedChapter;
        return GestureDetector(
          onTap: () => _selectChapter(chap),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? (readerTheme.isDark ? ImagoColors.violetGradient : null)
                  : null,
              color: isSelected
                  ? (readerTheme.isDark ? null : readerTheme.accentColor)
                  : readerTheme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : readerTheme.borderColor,
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: readerTheme.accentColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                  : [BoxShadow(color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03), blurRadius: 4, offset: const Offset(0, 1))],
            ),
            child: Center(
              child: Text(
                '$chap',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isSelected ? Colors.white : readerTheme.primaryText,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Verse Grid (Step 3: Book -> Chapter -> Verses) ───────────────
  Widget _buildVerseGrid(ReaderTheme readerTheme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SELECT VERSE',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: readerTheme.isDark ? ImagoColors.gold.withOpacity(0.85) : readerTheme.accentColor,
                  fontSize: 11.5,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GestureDetector(
                onTap: () => _openReader(targetVerse: 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: readerTheme.accentColor.withOpacity(readerTheme.isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: readerTheme.accentColor.withOpacity(0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded, color: readerTheme.accentColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Read Chapter',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: readerTheme.accentColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _verseCount,
            itemBuilder: (ctx, i) {
              final v = i + 1;
              final isSelected = v == _selectedVerse;
              return GestureDetector(
                onTap: () => _openReader(targetVerse: v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? (readerTheme.isDark ? ImagoColors.violetGradient : null)
                        : null,
                    color: isSelected
                        ? (readerTheme.isDark ? null : readerTheme.accentColor)
                        : readerTheme.cardBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : readerTheme.borderColor,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: readerTheme.accentColor.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))]
                        : [BoxShadow(color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  child: Center(
                    child: Text(
                      '$v',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isSelected ? Colors.white : readerTheme.primaryText,
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
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

  // ─── Verse Reader (Step 4: Reader) ────────────────────────
  Widget _buildVerseReader(ReaderTheme readerTheme) {
    return Column(
      children: [
        if (!_isDistractionFree) ...[
          // Top navigation bar for chapter selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: readerTheme.surface.withOpacity(0.6),
              border: Border(
                bottom: BorderSide(color: readerTheme.borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Chapter stepper: [<] Chapter N [>]
                Container(
                  decoration: BoxDecoration(
                    color: readerTheme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: readerTheme.borderColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _chapterNavBtn(
                        Icons.chevron_left_rounded,
                        _selectedChapter > 1
                            ? () => _changeReaderChapter(_selectedChapter - 1)
                            : null,
                        readerTheme,
                        tooltip: 'Previous Chapter',
                        inGroup: true,
                      ),
                      GestureDetector(
                        onTap: () => _openPassagePicker(readerTheme),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Chapter $_selectedChapter',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: readerTheme.primaryText,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: readerTheme.accentColor),
                            ],
                          ),
                        ),
                      ),
                      _chapterNavBtn(
                        Icons.chevron_right_rounded,
                        _selectedChapter < _chapterCount
                            ? () => _changeReaderChapter(_selectedChapter + 1)
                            : null,
                        readerTheme,
                        tooltip: 'Next Chapter',
                        inGroup: true,
                      ),
                    ],
                  ),
                ),
                // Reader quick tools
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chapterNavBtn(
                      _isPlayingAudio ? Icons.stop_rounded : Icons.volume_up_rounded,
                      _isPlayingAudio ? _stopAudio : _playChapterAudio,
                      readerTheme,
                      tooltip: _isPlayingAudio ? 'Stop Audio' : 'Play Chapter Audio',
                    ),
                    const SizedBox(width: 6),
                    _chapterNavBtn(
                      Icons.tune_rounded,
                      () => BibleAudioSettingsSheet.show(context, readerTheme: readerTheme),
                      readerTheme,
                      tooltip: 'Audio Studio & Sacred Atmosphere',
                    ),
                    const SizedBox(width: 6),
                    _chapterNavBtn(
                      _isDistractionFree ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                      _toggleDistractionFree,
                      readerTheme,
                      tooltip: _isDistractionFree ? 'Exit Full Screen' : 'Full Screen Focus',
                    ),
                    const SizedBox(width: 6),
                    _chapterNavBtn(
                      Icons.text_fields_rounded,
                      () {
                        TypographySettingsSheet.show(
                          context,
                          currentReaderTheme: _readerThemeMode,
                          currentFontFamily: _fontFamily,
                          currentFontSize: _fontSize,
                          currentLineHeight: _lineHeight,
                          onReaderThemeChanged: (val) {
                            readerThemeNotifier.value = val;
                            setState(() => _readerThemeMode = val);
                            _saveTypographySettings();
                          },
                          onFontFamilyChanged: (val) {
                            setState(() => _fontFamily = val);
                            _saveTypographySettings();
                          },
                          onFontSizeChanged: (val) {
                            setState(() => _fontSize = val);
                            _saveTypographySettings();
                          },
                          onLineHeightChanged: (val) {
                            setState(() => _lineHeight = val);
                            _saveTypographySettings();
                          },
                        );
                      },
                      readerTheme,
                      tooltip: 'Typography & Theme',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    SelectionArea(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (_selectedVerseNumbers.isNotEmpty) {
                            setState(() => _selectedVerseNumbers.clear());
                          } else {
                            _toggleDistractionFree();
                          }
                        },
                        child: ListView.builder(
                          controller: _scrollController,
                          cacheExtent: 3500,
                          padding: EdgeInsets.fromLTRB(16, 12, 16, _isDistractionFree ? 32 : 120),
                          itemCount: _verses.length,
                          itemBuilder: (ctx, i) => _buildVerseItem(_verses[i], readerTheme),
                        ),
                      ),
                    ),
                    if (_selectedVerseNumbers.isNotEmpty)
                      _buildMultiVerseActionBar(readerTheme),
                    if (_navigationHistory.isNotEmpty)
                      _buildFloatingHistoryPill(readerTheme),
                  ],
                ),
              ),
              if (_showDesktopInspector && _selectedBook != null)
                DesktopStudyInspector(
                  book: _selectedBook!,
                  chapter: _selectedChapter,
                  selectedVerse: _focusedVerse ?? (_verses.isNotEmpty ? _verses.first : null),
                  readerTheme: readerTheme,
                  initialTab: _desktopInspectorTab,
                  onClose: () => setState(() => _showDesktopInspector = false),
                  onNavigateVerse: (b, c, ver) async {
                    await _jumpToPassage(bookNumber: b, chapter: c, verse: ver);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chapterNavBtn(IconData icon, VoidCallback? onTap, ReaderTheme readerTheme, {String? tooltip, bool inGroup = false}) {
    final btn = GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: inGroup ? Colors.transparent : (onTap != null ? readerTheme.cardBackground : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: inGroup ? null : Border.all(color: onTap != null ? readerTheme.borderColor.withOpacity(0.5) : Colors.transparent),
        ),
        child: Icon(
          icon,
          color: onTap != null ? readerTheme.primaryText : readerTheme.secondaryText.withOpacity(0.3),
          size: 19,
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  Widget _buildVerseItem(BibleVerse v, ReaderTheme readerTheme) {
    // If it's a concordance translation with Strong's tags like KJV+
    final text = v.text;
    final isConcordance = text.contains('[G') || text.contains('[H');
    
    // Check if this verse is highlighted or targeted
    final highlight = _chapterHighlights.where((h) => h.verse == v.verse).firstOrNull;
    final isPlaying = _playingVerseNum == v.verse;
    final isTarget = _highlightedTargetVerse == v.verse;
    final isSelected = _selectedVerseNumbers.contains(v.verse);
    final isHovered = _hoveredVerseNum == v.verse;

    final baseBgColor = isPlaying
        ? readerTheme.accentColor.withOpacity(0.18)
        : isTarget
            ? (readerTheme.isDark ? ImagoColors.gold.withOpacity(0.25) : readerTheme.accentColor.withOpacity(0.22))
            : isSelected
                ? readerTheme.accentColor.withOpacity(readerTheme.isDark ? 0.25 : 0.15)
                : highlight != null
                    ? Color(int.parse(highlight.colorHex.replaceFirst('#', ''), radix: 16))
                        .withOpacity(readerTheme.isDark ? 0.35 : 0.28)
                    : (isHovered && !readerTheme.isDark)
                        ? const Color(0xFFF1F5F9)
                        : (isHovered && readerTheme.isDark)
                            ? Colors.white.withOpacity(0.04)
                            : Colors.transparent;

    return MouseRegion(
      key: _getVerseKey(v.verse),
      onEnter: (_) => setState(() => _hoveredVerseNum = v.verse),
      onExit: (_) => setState(() {
        if (_hoveredVerseNum == v.verse) _hoveredVerseNum = null;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedVerseNumbers.isNotEmpty) {
            setState(() {
              if (_selectedVerseNumbers.contains(v.verse)) {
                _selectedVerseNumbers.remove(v.verse);
              } else {
                _selectedVerseNumbers.add(v.verse);
              }
            });
          } else {
            _toggleDistractionFree();
          }
        },
        onLongPress: () => _showVerseOptions(v),
        onSecondaryTapUp: (details) => _showDesktopContextMenu(context, details, v, readerTheme),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(bottom: 12),
          padding: highlight != null || isSelected || isTarget
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: baseBgColor,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: readerTheme.accentColor, width: 1.2)
                : isTarget
                    ? Border.all(
                        color: readerTheme.isDark ? ImagoColors.gold : readerTheme.accentColor,
                        width: 1.5,
                      )
                    : isHovered
                        ? Border.all(color: readerTheme.borderColor.withOpacity(0.4))
                        : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Verse number or Multi-Select checkmark
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_selectedVerseNumbers.contains(v.verse)) {
                      _selectedVerseNumbers.remove(v.verse);
                    } else {
                      _selectedVerseNumbers.add(v.verse);
                    }
                  });
                },
                child: Container(
                  width: 30,
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      if (isSelected)
                        Icon(Icons.check_circle_rounded, size: 14, color: readerTheme.accentColor)
                      else
                        Text(
                          '${v.verse}',
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: highlight != null
                                ? (readerTheme.isDark ? Colors.white : Colors.black87)
                                : readerTheme.verseNumberColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
              child: isConcordance
                  ? _buildConcordanceText(text, highlight != null, readerTheme)
                  : (_showParallel && _parallelTranslation != null)
                      ? FutureBuilder<List<BibleVerse>>(
                          future: BibleService.instance.getVerses(v.book, v.chapter, translationAbbreviation: _parallelTranslation!),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) return const SizedBox();
                            final parallelVerse = snapshot.data!.firstWhere((pv) => pv.verse == v.verse, orElse: () => v);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  text,
                                  style: _fontFamily == 'Poppins' 
                                      ? TextStyle(
                                          fontFamily: _fontFamily,
                                          color: highlight != null
                                              ? (readerTheme.isDark ? Colors.white : Colors.black)
                                              : readerTheme.primaryText,
                                          fontSize: _fontSize,
                                          height: _lineHeight,
                                        )
                                      : GoogleFonts.getFont(
                                          _fontFamily,
                                          color: highlight != null
                                              ? (readerTheme.isDark ? Colors.white : Colors.black)
                                              : readerTheme.primaryText,
                                          fontSize: _fontSize,
                                          height: _lineHeight,
                                        ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  parallelVerse.text,
                                  style: _fontFamily == 'Poppins'
                                      ? TextStyle(
                                          fontFamily: _fontFamily,
                                          color: highlight != null
                                              ? (readerTheme.isDark ? Colors.white70 : Colors.black87)
                                              : readerTheme.secondaryText,
                                          fontSize: _fontSize - 1,
                                          height: _lineHeight - 0.1,
                                          fontStyle: FontStyle.italic,
                                        )
                                      : GoogleFonts.getFont(
                                          _fontFamily,
                                          color: highlight != null
                                              ? (readerTheme.isDark ? Colors.white70 : Colors.black87)
                                              : readerTheme.secondaryText,
                                          fontSize: _fontSize - 1,
                                          height: _lineHeight - 0.1,
                                          fontStyle: FontStyle.italic,
                                        ),
                                ),
                              ],
                            );
                          },
                        )
                      : Text(
                          text,
                          style: _fontFamily == 'Poppins'
                              ? TextStyle(
                                  fontFamily: _fontFamily,
                                  color: highlight != null
                                      ? (readerTheme.isDark ? Colors.white : Colors.black)
                                      : readerTheme.primaryText,
                                  fontSize: _fontSize,
                                  height: _lineHeight,
                                )
                              : GoogleFonts.getFont(
                                  _fontFamily,
                                  color: highlight != null
                                      ? (readerTheme.isDark ? Colors.white : Colors.black)
                                      : readerTheme.primaryText,
                                  fontSize: _fontSize,
                                  height: _lineHeight,
                                ),
                        ),
            ),
            // Desktop Hover Micro-Toolbar
            if (isHovered)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: 'Copy Verse (${v.reference})',
                      child: InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(
                            text: '${v.text} — ${v.reference} ($_translation)',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${v.reference} copied!'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.copy_rounded, size: 14, color: readerTheme.accentColor),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Quick Highlight',
                      child: InkWell(
                        onTap: () async {
                          if (highlight != null) {
                            await UserDataService.instance.deleteHighlight(v.book, v.chapter, v.verse);
                          } else {
                            await UserDataService.instance.saveHighlight(BibleHighlight(
                              id: 0,
                              book: v.book,
                              chapter: v.chapter,
                              verse: v.verse,
                              colorHex: '#F59E0B',
                            ));
                          }
                          _loadChapterUserData(v.book, v.chapter);
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.format_paint_rounded,
                            size: 14,
                            color: highlight != null ? const Color(0xFFF59E0B) : readerTheme.secondaryText,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Study Station (Commentary & Parallel)',
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _focusedVerse = v;
                            _showDesktopInspector = true;
                          });
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.auto_awesome_rounded, size: 14, color: readerTheme.accentColor),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Listen',
                      child: InkWell(
                        onTap: () => TtsService.instance.speak(v.text),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.volume_up_rounded, size: 14, color: readerTheme.secondaryText),
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
  );
}

  Widget _buildConcordanceText(String text, bool isHighlighted, ReaderTheme readerTheme) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'(.*?)(?:\[([GH]\d+)\]|$)');
    final matches = regex.allMatches(text);

    for (final m in matches) {
      if (m.group(1) != null && m.group(1)!.isNotEmpty) {
        spans.add(TextSpan(text: m.group(1)));
      }
      if (m.group(2) != null) {
        final strongs = m.group(2)!;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _showDictionaryDefinition(strongs),
              child: Container(
                margin: const EdgeInsets.only(left: 2, right: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? (readerTheme.isDark ? Colors.black26 : Colors.black12)
                      : readerTheme.accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isHighlighted
                        ? (readerTheme.isDark ? Colors.black38 : Colors.black26)
                        : readerTheme.accentColor.withOpacity(0.35),
                  ),
                ),
                child: Text(
                  strongs,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isHighlighted
                        ? (readerTheme.isDark ? Colors.white : Colors.black87)
                        : readerTheme.accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      style: _fontFamily == 'Poppins'
          ? TextStyle(
              fontFamily: _fontFamily,
              color: isHighlighted
                  ? (readerTheme.isDark ? Colors.white : Colors.black)
                  : readerTheme.primaryText,
              fontSize: _fontSize,
              height: _lineHeight,
            )
          : GoogleFonts.getFont(
              _fontFamily,
              color: isHighlighted
                  ? (readerTheme.isDark ? Colors.white : Colors.black)
                  : readerTheme.primaryText,
              fontSize: _fontSize,
              height: _lineHeight,
            ),
    );
  }

  void _showDictionaryDefinition(String term) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: ImagoColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<Map<String, dynamic>?>(
          future: DictionaryService.instance.lookupWord(term),
          builder: (context, snapshot) {
            final definition = snapshot.data?['definition'] as String?;
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            term.trim(),
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: ImagoColors.secondaryText),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Center(child: CircularProgressIndicator(color: ImagoColors.accent))
                      else if (definition != null)
                        FormattedDefinitionText(text: definition, onVerseTap: (v) {})
                      else
                        Text(
                          "No definition found.",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: ImagoColors.secondaryText,
                            fontSize: 15,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (RegExp(r'^[GH]\d+$', caseSensitive: false).hasMatch(term))
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _view = _BibleView.search;
                              _searchController.text = term;
                            });
                            _runSearch(term);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: ImagoColors.cardBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: ImagoColors.borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, color: ImagoColors.accent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Find all occurrences',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: ImagoColors.primaryText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
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

  // ── Desktop Right-Click & Multi-Verse Operations ─────────────────────

  void _showDesktopContextMenu(
    BuildContext context,
    TapUpDetails details,
    BibleVerse v,
    ReaderTheme readerTheme,
  ) {
    setState(() => _focusedVerse = v);
    final isDark = readerTheme.isDark;
    final highlight = _chapterHighlights.where((h) => h.verse == v.verse).firstOrNull;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        details.globalPosition.dx + 1,
        details.globalPosition.dy + 1,
      ),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      items: [
        PopupMenuItem<String>(
          value: 'copy_citation',
          child: Row(
            children: [
              Icon(Icons.copy_rounded, size: 16, color: readerTheme.accentColor),
              const SizedBox(width: 10),
              Text(
                'Copy ${v.reference}',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_plain',
          child: Row(
            children: [
              Icon(Icons.text_fields_rounded, size: 16, color: readerTheme.secondaryText),
              const SizedBox(width: 10),
              Text(
                'Copy Text Only',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'copy_markdown',
          child: Row(
            children: [
              Icon(Icons.format_quote_rounded, size: 16, color: readerTheme.secondaryText),
              const SizedBox(width: 10),
              Text(
                'Copy as Markdown Quote',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'select_multiple',
          child: Row(
            children: [
              Icon(
                _selectedVerseNumbers.contains(v.verse)
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 16,
                color: readerTheme.accentColor,
              ),
              const SizedBox(width: 10),
              Text(
                _selectedVerseNumbers.contains(v.verse) ? 'Deselect Verse' : 'Select for Multi-Copy',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'highlight_gold',
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('Highlight Gold', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'highlight_emerald',
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('Highlight Emerald', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'highlight_sky',
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFF0EA5E9), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('Highlight Sky', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'highlight_rose',
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFF43F5E), shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Text('Highlight Rose', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        if (highlight != null)
          PopupMenuItem<String>(
            value: 'remove_highlight',
            child: const Row(
              children: [
                Icon(Icons.format_color_reset_rounded, size: 16, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text('Remove Highlight', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFFEF4444))),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'open_commentary',
          child: Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, size: 16, color: readerTheme.accentColor),
              const SizedBox(width: 10),
              Text('Open Commentary in Study Station', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'open_crossref',
          child: Row(
            children: [
              Icon(Icons.alt_route_rounded, size: 16, color: readerTheme.accentColor),
              const SizedBox(width: 10),
              Text('View Cross-References', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'open_notes',
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 16, color: readerTheme.accentColor),
              const SizedBox(width: 10),
              Text('Personal Study Note', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'listen_audio',
          child: Row(
            children: [
              Icon(Icons.volume_up_rounded, size: 16, color: readerTheme.accentColor),
              const SizedBox(width: 10),
              Text('Listen to Verse', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: readerTheme.primaryText)),
            ],
          ),
        ),
      ],
    ).then((val) async {
      if (val == null) return;
      if (val == 'copy_citation') {
        Clipboard.setData(ClipboardData(text: '${v.text} — ${v.reference} ($_translation)'));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${v.reference} copied!')));
      } else if (val == 'copy_plain') {
        Clipboard.setData(ClipboardData(text: v.text));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verse text copied!')));
      } else if (val == 'copy_markdown') {
        Clipboard.setData(ClipboardData(text: '> ${v.text}\n> — **${v.reference} ($_translation)**'));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Markdown quote copied!')));
      } else if (val == 'select_multiple') {
        setState(() {
          if (_selectedVerseNumbers.contains(v.verse)) {
            _selectedVerseNumbers.remove(v.verse);
          } else {
            _selectedVerseNumbers.add(v.verse);
          }
        });
      } else if (val.startsWith('highlight_')) {
        final colors = {
          'highlight_gold': '#F59E0B',
          'highlight_emerald': '#10B981',
          'highlight_sky': '#0EA5E9',
          'highlight_rose': '#F43F5E',
        };
        final hex = colors[val];
        if (hex != null) {
          await UserDataService.instance.saveHighlight(BibleHighlight(
            id: highlight?.id ?? 0,
            book: v.book,
            chapter: v.chapter,
            verse: v.verse,
            colorHex: hex,
          ));
          _loadChapterUserData(v.book, v.chapter);
        }
      } else if (val == 'remove_highlight') {
        await UserDataService.instance.deleteHighlight(v.book, v.chapter, v.verse);
        _loadChapterUserData(v.book, v.chapter);
      } else if (val == 'open_commentary') {
        setState(() {
          _focusedVerse = v;
          _desktopInspectorTab = DesktopInspectorTab.commentary;
          _showDesktopInspector = true;
        });
      } else if (val == 'open_crossref') {
        setState(() {
          _focusedVerse = v;
          _desktopInspectorTab = DesktopInspectorTab.crossref;
          _showDesktopInspector = true;
        });
      } else if (val == 'open_notes') {
        setState(() {
          _focusedVerse = v;
          _desktopInspectorTab = DesktopInspectorTab.notes;
          _showDesktopInspector = true;
        });
      } else if (val == 'listen_audio') {
        TtsService.instance.speak(v.text);
      }
    });
  }

  Widget _buildMultiVerseActionBar(ReaderTheme readerTheme) {
    final sortedNums = _selectedVerseNumbers.toList()..sort();
    final firstNum = sortedNums.first;
    final lastNum = sortedNums.last;
    final rangeLabel = sortedNums.length == 1
        ? '${_selectedBook?.name} $_selectedChapter:$firstNum'
        : (firstNum == lastNum
            ? '${_selectedBook?.name} $_selectedChapter:$firstNum'
            : '${_selectedBook?.name} $_selectedChapter:$firstNum–$lastNum');

    return Positioned(
      bottom: 24,
      left: 20,
      right: 20,
      child: Center(
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          color: readerTheme.isDark ? const Color(0xFF1E293B) : Colors.white,
          shadowColor: Colors.black45,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: readerTheme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: readerTheme.accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_selectedVerseNumbers.length} Selected ($rangeLabel)',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: readerTheme.accentColor,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _copySelectedVerses(format: 'citation'),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Citation', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copySelectedVerses(format: 'plain'),
                  icon: const Icon(Icons.text_fields_rounded, size: 14),
                  label: const Text('Text Only', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: readerTheme.primaryText,
                    side: BorderSide(color: readerTheme.borderColor),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    final selected = _verses.where((v) => _selectedVerseNumbers.contains(v.verse)).toList()
                      ..sort((a, b) => a.verse.compareTo(b.verse));
                    if (selected.isEmpty) return;
                    final quote = JournalEditorScreen.formatVersesForJournal(selected);
                    setState(() => _selectedVerseNumbers.clear());
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JournalEditorScreen(
                          initialTitle: 'Reflection on $rangeLabel',
                          initialVerseQuote: quote,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_rounded, size: 14),
                  label: const Text('Journal', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4F46E5),
                    side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.45)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _colorDot('#F59E0B', 'Gold'),
                    const SizedBox(width: 4),
                    _colorDot('#10B981', 'Emerald'),
                    const SizedBox(width: 4),
                    _colorDot('#0EA5E9', 'Sky'),
                    const SizedBox(width: 4),
                    _colorDot('#F43F5E', 'Rose'),
                    const SizedBox(width: 4),
                    _colorDot('#8B5CF6', 'Violet'),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.format_color_reset_rounded, size: 18),
                      tooltip: 'Clear Highlight',
                      color: readerTheme.secondaryText,
                      onPressed: () => _highlightSelectedVerses(null),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Clear selection (Esc)',
                  color: readerTheme.secondaryText,
                  onPressed: () => setState(() => _selectedVerseNumbers.clear()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _colorDot(String hex, String tooltip) {
    final color = Color(int.parse(hex.replaceFirst('#', ''), radix: 16));
    return Tooltip(
      message: 'Highlight $tooltip',
      child: InkWell(
        onTap: () => _highlightSelectedVerses(hex),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _highlightSelectedVerses(String? hex) async {
    if (_selectedBook == null) return;
    for (final vNum in _selectedVerseNumbers) {
      if (hex != null) {
        await UserDataService.instance.saveHighlight(BibleHighlight(
          id: 0,
          book: _selectedBook!.number,
          chapter: _selectedChapter,
          verse: vNum,
          colorHex: hex,
        ));
      } else {
        await UserDataService.instance.deleteHighlight(
          _selectedBook!.number,
          _selectedChapter,
          vNum,
        );
      }
    }
    await _loadChapterUserData(_selectedBook!.number, _selectedChapter);
    setState(() => _selectedVerseNumbers.clear());
  }

  void _copySelectedVerses({String format = 'citation'}) {
    if (_verses.isEmpty || _selectedVerseNumbers.isEmpty) return;
    final sortedNums = _selectedVerseNumbers.toList()..sort();
    final selectedVersesList = _verses.where((v) => sortedNums.contains(v.verse)).toList();
    if (selectedVersesList.isEmpty) return;

    final first = sortedNums.first;
    final last = sortedNums.last;
    final ref = first == last
        ? '${_selectedBook?.name} $_selectedChapter:$first'
        : '${_selectedBook?.name} $_selectedChapter:$first–$last';

    String textToCopy = '';
    if (format == 'plain') {
      textToCopy = selectedVersesList.map((v) => v.text).join(' ');
    } else if (format == 'markdown') {
      final combined = selectedVersesList.map((v) => '[${v.verse}] ${v.text}').join('\n> ');
      textToCopy = '> $combined\n> — **$ref ($_translation)**';
    } else {
      final combined = selectedVersesList.map((v) => '${v.verse}. ${v.text}').join('\n');
      textToCopy = '$combined\n— $ref ($_translation)';
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$ref copied to clipboard!'),
        backgroundColor: const Color(0xFF4F46E5),
        duration: const Duration(seconds: 2),
      ),
    );
    setState(() => _selectedVerseNumbers.clear());
  }

  void _showVerseOptions(BibleVerse v) {
    final readerTheme = ReaderTheme.of(readerThemeNotifier.value);
    showModalBottomSheet(
      context: context,
      backgroundColor: readerTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              v.reference,
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: readerTheme.primaryText,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              v.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: readerTheme.secondaryText,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _verseActionBtn(Icons.volume_up_rounded, 'Listen', () {
                  Navigator.pop(ctx);
                  TtsService.instance.speak(v.text);
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.copy_rounded, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: '${v.text} — ${v.reference} ($_translation)'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${v.reference} copied!'),
                      backgroundColor: readerTheme.accentColor,
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.link_rounded, 'Cross-Refs', () {
                  Navigator.pop(ctx);
                  CrossrefSheet.show(
                    context: context,
                    sourceVerse: v,
                    readerTheme: readerTheme,
                    onJumpToVerse: (b, c, ver) {
                      _jumpToPassage(bookNumber: b, chapter: c, verse: ver);
                    },
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.lightbulb_outline_rounded, 'Commentary', () {
                  Navigator.pop(ctx);
                  CommentarySheet.show(
                    context,
                    reference: v.reference,
                    bookNumber: v.book,
                    chapter: v.chapter,
                    verse: v.verse,
                    verseText: v.text,
                    readerTheme: readerTheme,
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _verseActionBtn(Icons.format_paint_rounded, 'Highlight', () {
                  Navigator.pop(ctx);
                  final highlight = _chapterHighlights.where((h) => h.verse == v.verse).firstOrNull;
                  ColorPickerSheet.show(
                    context,
                    initialColor: highlight?.colorHex,
                    readerTheme: readerTheme,
                    onColorSelected: (hex) async {
                      await UserDataService.instance.saveHighlight(BibleHighlight(
                        id: highlight?.id ?? 0,
                        book: v.book,
                        chapter: v.chapter,
                        verse: v.verse,
                        colorHex: hex,
                      ));
                      _loadChapterUserData(v.book, v.chapter);
                    },
                    onRemoveHighlight: () async {
                      await UserDataService.instance.deleteHighlight(v.book, v.chapter, v.verse);
                      _loadChapterUserData(v.book, v.chapter);
                    },
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(
                  _bookmarkedVerses.contains(v.verse) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  'Bookmark',
                  () async {
                    Navigator.pop(ctx);
                    final bookmarks = await UserDataService.instance.getBookmarks();
                    final existing = bookmarks.where((b) => b.book == v.book && b.chapter == v.chapter && b.verse == v.verse).firstOrNull;
                    if (existing != null) {
                      await UserDataService.instance.deleteBookmark(existing.id);
                    } else {
                      await UserDataService.instance.saveBookmark(BibleBookmark(
                        id: 0, book: v.book, chapter: v.chapter, verse: v.verse, title: v.reference, createdAt: DateTime.now().millisecondsSinceEpoch,
                      ));
                    }
                    _loadChapterUserData(v.book, v.chapter);
                  }
                ),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.edit_note_rounded, 'Note', () async {
                  Navigator.pop(ctx);
                  final note = await UserDataService.instance.getNoteForVerse(v.book, v.chapter, v.verse);
                  if (!mounted) return;
                  NoteEditorSheet.show(
                    context, verse: v, initialNote: note,
                    readerTheme: readerTheme,
                    onSaved: () => _loadChapterUserData(v.book, v.chapter),
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.local_offer_rounded, 'Tag', () {
                  Navigator.pop(ctx);
                  TagEditorSheet.show(
                    context, verse: v,
                    readerTheme: readerTheme,
                    onTagsUpdated: () => _loadChapterUserData(v.book, v.chapter),
                  );
                }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _verseActionBtn(Icons.menu_book_rounded, 'Add to Journal', () {
                  Navigator.pop(ctx);
                  final quote = JournalEditorScreen.formatVersesForJournal([v]);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => JournalEditorScreen(
                        initialTitle: 'Reflection on ${v.reference}',
                        initialVerseQuote: quote,
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.rate_review_outlined, 'Report Issue / Feedback', () {
                  Navigator.pop(ctx);
                  FeedbackDialog.show(
                    context,
                    screenContext: 'bible_verse_reader',
                    initialCategory: FeedbackCategory.scripture,
                    metadata: {
                      'verse_reference': v.reference,
                      'translation': _translation,
                      'verse_text': v.text,
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _verseActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: ImagoColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ImagoColors.borderColor),
          ),
          child: Column(
            children: [
              Icon(icon, color: ImagoColors.accent, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: ImagoColors.primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search ───────────────────────────────────────────────
  Widget _buildSearchView(ReaderTheme readerTheme) {
    final hasScopeFilter = _searchBookFilter != null && _searchBookFilter!.isNotEmpty && _searchBookFilter!.length < 66;

    return Column(
      children: [
        // Search Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Container(
            decoration: BoxDecoration(
              color: readerTheme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: readerTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: readerTheme.primaryText, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'Search the Word...',
                hintStyle: TextStyle(color: readerTheme.secondaryText.withOpacity(0.6), fontFamily: 'Poppins'),
                prefixIcon: Icon(Icons.search_rounded, color: readerTheme.secondaryText),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _stopAudio();
                          _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                        child: Icon(Icons.close_rounded, color: readerTheme.secondaryText),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onChanged: (q) {
                setState(() {}); // rebuild for suffix icon
                _runSearch(q);
              },
            ),
          ),
        ),

        // Search Controls: Match Type & Scope Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            children: [
              // Match Type Chips (Exact Phrase, All Words, Any Word)
              Row(
                children: [
                  for (final type in BibleSearchMatchType.values)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _searchMatchType = type);
                          if (_searchController.text.trim().isNotEmpty) {
                            _runSearch();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: EdgeInsets.only(right: type != BibleSearchMatchType.values.last ? 6 : 0),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            gradient: _searchMatchType == type
                                ? (readerTheme.isDark ? ImagoColors.violetGradient : null)
                                : null,
                            color: _searchMatchType == type
                                ? (readerTheme.isDark ? null : readerTheme.accentColor)
                                : readerTheme.cardBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _searchMatchType == type ? Colors.transparent : readerTheme.borderColor,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              type.label,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: _searchMatchType == type ? FontWeight.bold : FontWeight.w500,
                                color: _searchMatchType == type ? Colors.white : readerTheme.secondaryText,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Scope Selector Pill & Reset
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        BibleSearchScopeSheet.show(
                          context: context,
                          initialSelectedBooks: _searchBookFilter,
                          initialGroupName: _searchGroupName,
                          readerTheme: readerTheme,
                          onApply: (result) {
                            setState(() {
                              _searchBookFilter = result.bookNumbers;
                              _searchScopeLabel = result.label;
                              _searchGroupName = result.groupName;
                            });
                            if (_searchController.text.trim().isNotEmpty) {
                              _runSearch();
                            }
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: hasScopeFilter
                              ? (readerTheme.isDark
                                  ? readerTheme.accentColor.withOpacity(0.2)
                                  : readerTheme.accentColor.withOpacity(0.12))
                              : readerTheme.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasScopeFilter ? readerTheme.accentColor : readerTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.travel_explore_rounded,
                              size: 16,
                              color: hasScopeFilter ? readerTheme.accentColor : readerTheme.secondaryText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Scope: $_searchScopeLabel',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: hasScopeFilter ? FontWeight.bold : FontWeight.w500,
                                  color: hasScopeFilter ? readerTheme.primaryText : readerTheme.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: readerTheme.secondaryText),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasScopeFilter) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchBookFilter = null;
                          _searchScopeLabel = 'Entire Bible';
                          _searchGroupName = 'Entire Bible';
                        });
                        if (_searchController.text.trim().isNotEmpty) {
                          _runSearch();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: readerTheme.cardBackground,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: readerTheme.borderColor),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 14, color: readerTheme.secondaryText),
                            const SizedBox(width: 4),
                            Text(
                              'All Books',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                color: readerTheme.secondaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 4),

        if (_searching)
          Padding(
            padding: const EdgeInsets.only(top: 24),
            child: CircularProgressIndicator(color: readerTheme.accentColor),
          )
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              'No verses found for\n"${_searchController.text}" in $_searchScopeLabel\n(${_searchMatchType.label})',
              textAlign: TextAlign.center,
              style: TextStyle(color: readerTheme.secondaryText, fontFamily: 'Poppins', fontSize: 14),
            ),
          )
        else if (_searchResults.isEmpty && _searchController.text.isEmpty)
          Expanded(child: _buildSuggestedTopics(readerTheme))
        else
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Results Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        '${_searchResults.length} verses found',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: readerTheme.secondaryText,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: readerTheme.accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _searchScopeLabel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: readerTheme.accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Results list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _searchResults.length,
                    itemBuilder: (ctx, i) {
                      final v = _searchResults[i];
                      return GestureDetector(
                        onTap: () async {
                          final book = kBibleBooks.firstWhere((b) => b.number == v.book);
                          await _selectBook(book, navigateToChapters: false);
                          await _selectChapter(v.chapter, targetVerse: v.verse);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: readerTheme.cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: readerTheme.borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    v.reference,
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      color: readerTheme.accentColor,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(Icons.chevron_right_rounded, size: 16, color: readerTheme.secondaryText),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                v.text,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: readerTheme.primaryText,
                                  fontSize: 13.5,
                                  height: 1.55,
                                ),
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
      ],
    );
  }

  Widget _buildSuggestedTopics(ReaderTheme readerTheme) {
    final topics = kTopicalIndex.keys.toList();
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.8,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: topics.length,
      itemBuilder: (ctx, i) {
        final topic = topics[i];
        return GestureDetector(
          onTap: () {
            _searchController.text = topic;
            _runSearch(topic);
          },
          child: Container(
            decoration: BoxDecoration(
              color: readerTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: readerTheme.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(readerTheme.isDark ? 0.2 : 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tag_rounded, color: readerTheme.accentColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  topic,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: readerTheme.primaryText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Translation Picker ────────────────────────────────────
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

          return Container(
            constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.82),
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
                      'Choose Bible Translation',
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
                    hintText: 'Search language or translation (e.g. French, Pidgin, Igbo, KJV)...',
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
                      _buildLanguageChip('All', 'All Languages', selectedLanguageFilter, (f) {
                        setPickerState(() => selectedLanguageFilter = f);
                      }),
                      const SizedBox(width: 8),
                      _buildLanguageChip('English', '🇬🇧 English', selectedLanguageFilter, (f) {
                        setPickerState(() => selectedLanguageFilter = f);
                      }),
                      const SizedBox(width: 8),
                      _buildLanguageChip('Nigerian', '🇳🇬 Nigerian', selectedLanguageFilter, (f) {
                        setPickerState(() => selectedLanguageFilter = f);
                      }),
                      const SizedBox(width: 8),
                      _buildLanguageChip('International', '🌍 International', selectedLanguageFilter, (f) {
                        setPickerState(() => selectedLanguageFilter = f);
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Translation List Grouped by Language
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
                                final isSelected = t.abbreviation == _translation;
                                final isParallel = t.abbreviation == _parallelTranslation;
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
                                        if (_translation == t.abbreviation) return;
                                        _switchTranslation(t.abbreviation);
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
                                                        content: Text('${t.description} downloaded for 100% offline use!'),
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
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (!t.isBundled)
                                                    GestureDetector(
                                                      onTap: () async {
                                                        await BibleService.instance.deleteDownloadedTranslation(t.abbreviation);
                                                        setPickerState(() {});
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(
                                                            content: Text('${t.description} deleted from local storage.'),
                                                            backgroundColor: const Color(0xFF0E0B24),
                                                          ),
                                                        );
                                                      },
                                                      child: Padding(
                                                        padding: const EdgeInsets.only(right: 8),
                                                        child: Icon(
                                                          Icons.delete_outline_rounded,
                                                          color: Colors.white.withOpacity(0.4),
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  GestureDetector(
                                                    onTap: () {
                                                      Navigator.pop(ctx);
                                                      setState(() {
                                                        if (isParallel && _showParallel) {
                                                          _showParallel = false;
                                                          _parallelTranslation = null;
                                                        } else {
                                                          _showParallel = true;
                                                          _parallelTranslation = t.abbreviation;
                                                        }
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: isParallel && _showParallel
                                                            ? ImagoColors.gold.withOpacity(0.2)
                                                            : Colors.white.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(
                                                          color: isParallel && _showParallel
                                                              ? ImagoColors.gold
                                                              : Colors.white.withOpacity(0.12),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        (isParallel && _showParallel) ? 'Remove' : '+ Compare',
                                                        style: TextStyle(
                                                          fontFamily: 'Poppins',
                                                          color: (isParallel && _showParallel)
                                                              ? ImagoColors.gold
                                                              : Colors.white70,
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
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
          );
        },
      ),
    );
  }

  Widget _buildLanguageChip(String value, String label, String currentSelected, ValueChanged<String> onSelect) {
    final isSelected = currentSelected == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? ImagoColors.gold : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? ImagoColors.gold : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isSelected ? Colors.black : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
