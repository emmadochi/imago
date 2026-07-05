// lib/screens/bible_screen.dart
// Full offline Bible reader for Imago — Book picker, Chapter grid, Verse reader, Search

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../theme/imago_theme.dart';

enum _BibleView { books, chapters, verses, search }

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

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

  // Translation
  late String _translation;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
    setState(() {
      _verses = verses;
      _view = _BibleView.verses;
      _loading = false;
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

  void _goBack() {
    setState(() {
      if (_view == _BibleView.verses) {
        _view = _BibleView.chapters;
      } else if (_view == _BibleView.chapters) {
        _view = _BibleView.books;
      } else if (_view == _BibleView.search) {
        _view = _BibleView.books;
        _searchController.clear();
        _searchResults = [];
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
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
                  const Expanded(child: Center(child: CircularProgressIndicator(color: ImagoColors.gold)))
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
                child: Text(
                  title,
                  style: const TextStyle(
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
                  child: Text(
                    _translation,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
        // Prev / Next chapter navigation
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
              _chapterNavBtn(
                Icons.chevron_right_rounded,
                _selectedChapter < _chapterCount
                    ? () => _selectChapter(_selectedChapter + 1)
                    : null,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: _verses.length,
            itemBuilder: (ctx, i) => _buildVerseItem(_verses[i]),
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
    return GestureDetector(
      onLongPress: () => _showVerseOptions(v),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            Container(
              width: 28,
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${v.verse}',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: ImagoColors.gold.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Verse text
            Expanded(
              child: Text(
                v.text,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontSize: 15.5,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      ),
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
              style: const TextStyle(
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
                const SizedBox(width: 12),
                _verseActionBtn(Icons.share_rounded, 'Share', () {
                  // Share can be wired to share_plus later
                  Clipboard.setData(ClipboardData(text: '${v.text} — ${v.reference} ($_translation)'));
                  Navigator.pop(ctx);
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
          const Padding(
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
                          style: const TextStyle(
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
            const Text(
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
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
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
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
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
