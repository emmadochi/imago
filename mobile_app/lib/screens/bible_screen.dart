// lib/screens/bible_screen.dart
// Full offline Bible reader for Imago — Book picker, Chapter grid, Verse reader, Search

import 'dart:ui';
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
import '../widgets/typography_sheet.dart';
import '../widgets/formatted_definition_text.dart';
import '../data/topical_index.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

enum _BibleView { books, chapters, verses, search }

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  static final ValueNotifier<bool> distractionFreeNotifier = ValueNotifier(false);

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen>
    with SingleTickerProviderStateMixin {
  _BibleView _view = _BibleView.books;
  BibleBook? _selectedBook;
  int _selectedChapter = 1;
  List<BibleVerse> _verses = [];
  int _chapterCount = 0;
  bool _loading = false;
  bool _initialized = false;

  // Search
  final _searchController = TextEditingController();
  List<BibleVerse> _searchResults = [];
  bool _searching = false;

  // Translation & Parallel
  late String _translation;
  String? _parallelTranslation;
  bool _showParallel = false;

  // Dictionary & Layout

  // Audio Player
  bool _isPlayingAudio = false;
  int? _playingVerseNum;
  final ScrollController _scrollController = ScrollController();
  bool _isDistractionFree = false;
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
    setState(() {
      _fontFamily = prefs.getString('typography_font') ?? 'Poppins';
      _fontSize = prefs.getDouble('typography_size') ?? 15.5;
      _lineHeight = prefs.getDouble('typography_line_height') ?? 1.7;
    });
  }

  Future<void> _saveTypographySettings() async {
    final prefs = await SharedPreferences.getInstance();
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
  }

  Future<void> _selectBook(BibleBook book) async {
    setState(() {
      _selectedBook = book;
      _loading = true;
    });
    final count = await BibleService.instance.getChapterCount(book.number);
    setState(() {
      _chapterCount = count;
      _view = _BibleView.chapters;
      _loading = false;
    });
  }

  Future<void> _selectChapter(int chapter) async {
    setState(() {
      _selectedChapter = chapter;
      _loading = true;
    });
    final verses = await BibleService.instance.getVerses(_selectedBook!.number, chapter);
    await _loadChapterUserData(_selectedBook!.number, chapter);
    setState(() {
      _verses = verses;
      _view = _BibleView.verses;
      _loading = false;
    });
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

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await BibleService.instance.search(query);
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  Future<void> _switchTranslation(String abbr) async {
    await BibleService.instance.setTranslation(abbr);
    setState(() => _translation = abbr);
    // Reload current view with new translation
    if (_view == _BibleView.verses && _selectedBook != null) {
      await _selectChapter(_selectedChapter);
    }
  }


  Future<void> _playChapterAudio() async {
    setState(() => _isPlayingAudio = true);
    
    for (int i = 0; i < _verses.length; i++) {
      if (!mounted || !_isPlayingAudio) break;
      
      final verse = _verses[i];
      setState(() => _playingVerseNum = verse.verse);
      
      // Attempt to scroll to the verse
      if (_scrollController.hasClients) {
        // Very basic estimation of scroll position (assuming ~100px per verse on average)
        // A robust solution uses Scrollable.ensureVisible with GlobalKeys, but this works well enough for TTS sync
        final offset = (i * 120.0).clamp(0.0, _scrollController.position.maxScrollExtent);
        _scrollController.animateTo(offset, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
      
      await TtsService.instance.speak(verse.text);
    }
    
    _stopAudio();
  }
  
  void _stopAudio() {
    TtsService.instance.stop();
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
        _playingVerseNum = null;
      });
    }
  }

  void _goBack() {
    setState(() {
      if (_view == _BibleView.verses) {
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
    _searchController.dispose();
    _scrollController.dispose();
    _stopAudio();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
      floatingActionButton: _view == _BibleView.verses
          ? FloatingActionButton(
              backgroundColor: _isPlayingAudio ? Colors.redAccent : const Color(0xFF3D5AFE),
              onPressed: _isPlayingAudio ? _stopAudio : _playChapterAudio,
              child: Icon(_isPlayingAudio ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white),
            )
          : null,
      body: Stack(
        children: [
          const CosmicBackground(children: []),
          // Ambient orb
          Positioned(
            top: -40, left: -40,
            child: CosmicOrb(size: 260, color: const Color(0xFF3D5AFE), opacity: 0.07),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (!_initialized || _loading)
                  Expanded(child: Center(child: CircularProgressIndicator(color: ImagoColors.gold)))
                else
                  Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
      case _BibleView.search:
        title = 'Search';
        showBack = true;
    }

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              if (showBack)
                GestureDetector(
                  onTap: _goBack,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
                  ),
                )
              else
                const SizedBox(width: 36),
              const SizedBox(width: 10),
              Expanded(
                child: _view == _BibleView.verses || _view == _BibleView.chapters
                    ? Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _view = _BibleView.books;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              color: Colors.transparent, // expand hit area
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _selectedBook?.name ?? '',
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      color: ImagoColors.cream,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: ImagoColors.cream.withOpacity(0.7), size: 18),
                                ],
                              ),
                            ),
                          ),
                          if (_view == _BibleView.verses) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _view = _BibleView.chapters;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                color: Colors.transparent,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$_selectedChapter',
                                      style: TextStyle(
                                        fontFamily: 'Cinzel',
                                        color: ImagoColors.cream,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(Icons.keyboard_arrow_down_rounded,
                                        color: ImagoColors.cream.withOpacity(0.7), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      )
                    : Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: ImagoColors.cream,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              // Translation selector
              GestureDetector(
                onTap: _showTranslationPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: ImagoColors.violetGradient,
                    borderRadius: BorderRadius.circular(10),
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
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case _BibleView.books:
        return _buildBookList();
      case _BibleView.chapters:
        return _buildChapterGrid();
      case _BibleView.verses:
        return _buildVerseReader();
      case _BibleView.search:
        return _buildSearchView();
    }
  }

  // ─── Book List ────────────────────────────────────────────
  Widget _buildBookList() {
    final ot = kBibleBooks.where((b) => b.isOldTestament).toList();
    final nt = kBibleBooks.where((b) => !b.isOldTestament).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _sectionLabel('OLD TESTAMENT'),
        const SizedBox(height: 10),
        _buildBookGrid(ot),
        const SizedBox(height: 24),
        _sectionLabel('NEW TESTAMENT'),
        const SizedBox(height: 10),
        _buildBookGrid(nt),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: ImagoColors.gold.withOpacity(0.7),
        fontSize: 11,
        letterSpacing: 2.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBookGrid(List<BibleBook> books) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: books.length,
      itemBuilder: (ctx, i) {
        final book = books[i];
        return GestureDetector(
          onTap: () => _selectBook(book),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Center(
              child: Text(
                book.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Chapter Grid ─────────────────────────────────────────
  Widget _buildChapterGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _chapterCount,
      itemBuilder: (ctx, i) {
        final chap = i + 1;
        return GestureDetector(
          onTap: () => _selectChapter(chap),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              gradient: chap == _selectedChapter ? ImagoColors.violetGradient : null,
              color: chap == _selectedChapter ? null : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: chap == _selectedChapter
                    ? Colors.transparent
                    : Colors.white.withOpacity(0.08),
              ),
              boxShadow: chap == _selectedChapter
                  ? [BoxShadow(color: ImagoColors.violet.withOpacity(0.4), blurRadius: 8)]
                  : null,
            ),
            child: Center(
              child: Text(
                '$chap',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: chap == _selectedChapter ? Colors.white : Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: chap == _selectedChapter ? FontWeight.bold : FontWeight.w400,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── Verse Reader ─────────────────────────────────────────
  Widget _buildVerseReader() {
    return Column(
      children: [
        if (!_isDistractionFree) ...[
          // Top navigation bar for chapter selection
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.02),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _chapterNavBtn(
                  Icons.chevron_left_rounded,
                  _selectedChapter > 1
                      ? () => _selectChapter(_selectedChapter - 1)
                      : null,
                ),
                Text(
                  'Chapter $_selectedChapter',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _chapterNavBtn(
                      Icons.text_fields_rounded,
                      () {
                        TypographySettingsSheet.show(
                          context,
                          currentFontFamily: _fontFamily,
                          currentFontSize: _fontSize,
                          currentLineHeight: _lineHeight,
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
                    ),
                    const SizedBox(width: 8),
                    _chapterNavBtn(
                      Icons.chevron_right_rounded,
                      _selectedChapter < _chapterCount
                          ? () => _selectChapter(_selectedChapter + 1)
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isDistractionFree = !_isDistractionFree;
                BibleScreen.distractionFreeNotifier.value = _isDistractionFree;
                if (_isDistractionFree) {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                } else {
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
                }
              });
            },
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _verses.length,
              itemBuilder: (ctx, i) => _buildVerseItem(_verses[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chapterNavBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: onTap != null ? Colors.white.withOpacity(0.06) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: onTap != null ? Colors.white : Colors.white.withOpacity(0.2),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildVerseItem(BibleVerse v) {
    // If it's a concordance translation with Strong's tags like KJV+
    final text = v.text;
    final isConcordance = text.contains('[G') || text.contains('[H');
    
    // Check if this verse is highlighted
    final highlight = _chapterHighlights.where((h) => h.verse == v.verse).firstOrNull;
final bgColor = _playingVerseNum == v.verse
        ? ImagoColors.gold.withOpacity(0.15)
        : highlight != null 
            ? Color(int.parse(highlight.colorHex.replaceFirst('#', ''), radix: 16)).withOpacity(1.0) 
            : Colors.transparent;

    return GestureDetector(
      onLongPress: () => _showVerseOptions(v),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: highlight != null ? const EdgeInsets.all(8) : EdgeInsets.zero,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${v.verse}',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: highlight != null ? Colors.black87 : ImagoColors.gold.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: isConcordance
                  ? _buildConcordanceText(text, highlight != null)
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
                                      ? TextStyle(fontFamily: _fontFamily, color: highlight != null ? Colors.black : Colors.white, fontSize: _fontSize, height: _lineHeight)
                                      : GoogleFonts.getFont(_fontFamily, color: highlight != null ? Colors.black : Colors.white, fontSize: _fontSize, height: _lineHeight),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  parallelVerse.text,
                                  style: _fontFamily == 'Poppins'
                                      ? TextStyle(fontFamily: _fontFamily, color: highlight != null ? Colors.black87 : Colors.white70, fontSize: _fontSize - 1, height: _lineHeight - 0.1, fontStyle: FontStyle.italic)
                                      : GoogleFonts.getFont(_fontFamily, color: highlight != null ? Colors.black87 : Colors.white70, fontSize: _fontSize - 1, height: _lineHeight - 0.1, fontStyle: FontStyle.italic),
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
                                  color: highlight != null ? Colors.black : Colors.white,
                                  fontSize: _fontSize,
                                  height: _lineHeight,
                                )
                              : GoogleFonts.getFont(
                                  _fontFamily,
                                  color: highlight != null ? Colors.black : Colors.white,
                                  fontSize: _fontSize,
                                  height: _lineHeight,
                                ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConcordanceText(String text, bool isHighlighted) {
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
                  color: isHighlighted ? Colors.black12 : ImagoColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isHighlighted ? Colors.black26 : ImagoColors.gold.withOpacity(0.3)),
                ),
                child: Text(
                  strongs,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isHighlighted ? Colors.black87 : ImagoColors.gold,
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
              color: isHighlighted ? Colors.black : Colors.white,
              fontSize: _fontSize,
              height: _lineHeight,
            )
          : GoogleFonts.getFont(
              _fontFamily,
              color: isHighlighted ? Colors.black : Colors.white,
              fontSize: _fontSize,
              height: _lineHeight,
            ),
    );
  }

  void _showDictionaryDefinition(String term) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
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
                              color: ImagoColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        Center(child: CircularProgressIndicator(color: ImagoColors.gold))
                      else if (definition != null)
                        FormattedDefinitionText(text: definition, onVerseTap: (v) {})
                      else
                        Text(
                          "No definition found.",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.5),
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
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, color: ImagoColors.gold, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Find all occurrences',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white,
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

  void _showVerseOptions(BibleVerse v) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
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
                color: ImagoColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              v.text,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _verseActionBtn(Icons.copy_rounded, 'Copy', () {
                  Clipboard.setData(ClipboardData(text: '${v.text} — ${v.reference} ($_translation)'));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${v.reference} copied!'),
                      backgroundColor: ImagoColors.nebula,
                    ),
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.link_rounded, 'Cross-Refs', () {
                  Navigator.pop(ctx);
                  CrossrefSheet.show(
                    context: context,
                    sourceVerse: v,
                    onJumpToVerse: (b, c, ver) {
                      _selectBook(kBibleBooks.firstWhere((book) => book.number == b));
                      _selectChapter(c);
                    },
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
                    onSaved: () => _loadChapterUserData(v.book, v.chapter),
                  );
                }),
                const SizedBox(width: 8),
                _verseActionBtn(Icons.local_offer_rounded, 'Tag', () {
                  Navigator.pop(ctx);
                  TagEditorSheet.show(
                    context, verse: v,
                    onTagsUpdated: () => _loadChapterUserData(v.book, v.chapter),
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
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: ImagoColors.gold, size: 20),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Search ───────────────────────────────────────────────
  Widget _buildSearchView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontFamily: 'Poppins'),
              decoration: InputDecoration(
                hintText: 'Search the Word...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontFamily: 'Poppins'),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _stopAudio();
        _searchController.clear();
                          setState(() => _searchResults = []);
                        },
                        child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
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
        if (_searching)
          Padding(
            padding: EdgeInsets.only(top: 20),
            child: CircularProgressIndicator(color: ImagoColors.gold),
          )
        else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Text(
              'No verses found for\n"${_searchController.text}"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontFamily: 'Poppins'),
            ),
          )
        else if (_searchResults.isEmpty && _searchController.text.isEmpty)
          Expanded(child: _buildSuggestedTopics())
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: _searchResults.length,
              itemBuilder: (ctx, i) {
                final v = _searchResults[i];
                return GestureDetector(
                  onTap: () async {
                    final book = kBibleBooks.firstWhere((b) => b.number == v.book);
                    await _selectBook(book);
                    await _selectChapter(v.chapter);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.reference,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: ImagoColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          v.text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.8),
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
    );
  }

  Widget _buildSuggestedTopics() {
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
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.tag_rounded, color: ImagoColors.gold, size: 14),
                const SizedBox(width: 6),
                Text(
                  topic,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
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
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Translation',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: ImagoColors.cream,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...kBibleTranslations.map((t) {
              final isSelected = t.abbreviation == _translation;
              final isParallel = t.abbreviation == _parallelTranslation;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  if (_translation == t.abbreviation) return; // Do nothing
                  _switchTranslation(t.abbreviation);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected ? ImagoColors.violetGradient : null,
                    color: isSelected ? null : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        t.abbreviation,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: isSelected ? Colors.white : ImagoColors.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t.description,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.75),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18)
                      else if (!isSelected)
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
                              color: isParallel && _showParallel ? ImagoColors.gold.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (isParallel && _showParallel) ? 'Remove' : '+ Compare',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: (isParallel && _showParallel) ? ImagoColors.gold : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
