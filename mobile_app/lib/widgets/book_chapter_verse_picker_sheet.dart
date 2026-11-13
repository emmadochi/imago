// lib/widgets/book_chapter_verse_picker_sheet.dart
// Unified Book, Chapter, and Verse quick selector for yo-ETS Bible

import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../theme/imago_theme.dart';

class BookChapterVersePickerSheet extends StatefulWidget {
  final BibleBook initialBook;
  final int initialChapter;
  final int? initialVerse;
  final ReaderTheme readerTheme;
  final void Function(BibleBook book, int chapter, int verse) onSelected;

  const BookChapterVersePickerSheet({
    super.key,
    required this.initialBook,
    required this.initialChapter,
    this.initialVerse,
    required this.readerTheme,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required BibleBook initialBook,
    required int initialChapter,
    int? initialVerse,
    required ReaderTheme readerTheme,
    required void Function(BibleBook book, int chapter, int verse) onSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookChapterVersePickerSheet(
        initialBook: initialBook,
        initialChapter: initialChapter,
        initialVerse: initialVerse,
        readerTheme: readerTheme,
        onSelected: onSelected,
      ),
    );
  }

  @override
  State<BookChapterVersePickerSheet> createState() =>
      _BookChapterVersePickerSheetState();
}

class _BookChapterVersePickerSheetState
    extends State<BookChapterVersePickerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late BibleBook _selectedBook;
  late int _selectedChapter;
  int? _selectedVerse;

  // Filter state for books tab
  String _bookSearchQuery = '';
  int _testamentFilter = 0; // 0: All, 1: OT, 2: NT

  int _chapterCount = 1;
  int _verseCount = 30;
  bool _loadingCounts = false;

  @override
  void initState() {
    super.initState();
    _selectedBook = widget.initialBook;
    _selectedChapter = widget.initialChapter;
    _selectedVerse = widget.initialVerse ?? 1;

    _tabController = TabController(length: 3, vsync: this);
    _loadCounts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    setState(() => _loadingCounts = true);
    final chCount = await BibleService.instance.getChapterCount(_selectedBook.number);
    final vCount = await BibleService.instance.getVerseCount(_selectedBook.number, _selectedChapter);
    if (!mounted) return;
    setState(() {
      _chapterCount = chCount;
      _verseCount = vCount > 0 ? vCount : 30;
      _loadingCounts = false;
    });
  }

  Future<void> _onBookPicked(BibleBook book) async {
    setState(() {
      _selectedBook = book;
      _selectedChapter = 1;
      _selectedVerse = 1;
    });
    await _loadCounts();
    _tabController.animateTo(1);
  }

  Future<void> _onChapterPicked(int chapter) async {
    setState(() {
      _selectedChapter = chapter;
      _selectedVerse = 1;
    });
    final vCount = await BibleService.instance.getVerseCount(_selectedBook.number, chapter);
    if (mounted) {
      setState(() {
        _verseCount = vCount > 0 ? vCount : 30;
      });
      _tabController.animateTo(2);
    }
  }

  void _onVersePicked(int verse) {
    setState(() => _selectedVerse = verse);
    Navigator.pop(context);
    widget.onSelected(_selectedBook, _selectedChapter, verse);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme;
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: theme.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: theme.borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SELECT PASSAGE',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: theme.isDark ? ImagoColors.gold : theme.accentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedBook.name} $_selectedChapter${_selectedVerse != null ? ":$_selectedVerse" : ""}',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Read from chapter 1 button
                TextButton.icon(
                  onPressed: () => _onVersePicked(1),
                  icon: Icon(Icons.arrow_forward_rounded, size: 16, color: theme.accentColor),
                  label: Text(
                    'Read Chapter',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.accentColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Step Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.borderColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                gradient: theme.isDark ? ImagoColors.violetGradient : null,
                color: theme.isDark ? null : theme.accentColor,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: theme.secondaryText,
              labelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabs: [
                Tab(text: _selectedBook.name.length > 10 ? '${_selectedBook.name.substring(0, 8)}..' : _selectedBook.name),
                Tab(text: 'Chapter $_selectedChapter'),
                Tab(text: 'Verse ${_selectedVerse ?? 1}'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBooksTab(theme),
                _buildChaptersTab(theme),
                _buildVersesTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: Books ---
  Widget _buildBooksTab(ReaderTheme theme) {
    final query = _bookSearchQuery.trim().toLowerCase();
    final books = kBibleBooks.where((b) {
      if (_testamentFilter == 1 && !b.isOldTestament) return false;
      if (_testamentFilter == 2 && b.isOldTestament) return false;
      if (query.isNotEmpty && !b.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        // Filter row + Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.borderColor),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _bookSearchQuery = val),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: theme.primaryText),
                    decoration: InputDecoration(
                      hintText: 'Filter book...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: theme.secondaryText.withOpacity(0.6),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: theme.secondaryText),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _filterSegment(0, 'All', theme),
              const SizedBox(width: 4),
              _filterSegment(1, 'OT', theme),
              const SizedBox(width: 4),
              _filterSegment(2, 'NT', theme),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Grid of books
        Expanded(
          child: books.isEmpty
              ? Center(
                  child: Text(
                    'No books found',
                    style: TextStyle(fontFamily: 'Poppins', color: theme.secondaryText),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: books.length,
                  itemBuilder: (ctx, i) {
                    final book = books[i];
                    final isSelected = book.number == _selectedBook.number;
                    return GestureDetector(
                      onTap: () => _onBookPicked(book),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? (theme.isDark ? ImagoColors.violetGradient : null)
                              : null,
                          color: isSelected
                              ? (theme.isDark ? null : theme.accentColor)
                              : theme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? Colors.transparent : theme.borderColor,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            book.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? Colors.white : theme.primaryText,
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

  Widget _filterSegment(int index, String label, ReaderTheme theme) {
    final isSelected = _testamentFilter == index;
    return GestureDetector(
      onTap: () => setState(() => _testamentFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (theme.isDark ? theme.accentColor : theme.accentColor.withOpacity(0.15))
              : theme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? (theme.isDark ? Colors.white : theme.accentColor)
                : theme.secondaryText,
          ),
        ),
      ),
    );
  }

  // --- TAB 2: Chapters ---
  Widget _buildChaptersTab(ReaderTheme theme) {
    if (_loadingCounts) {
      return Center(child: CircularProgressIndicator(color: theme.accentColor));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _chapterCount,
      itemBuilder: (ctx, i) {
        final chapter = i + 1;
        final isSelected = chapter == _selectedChapter;

        return GestureDetector(
          onTap: () => _onChapterPicked(chapter),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected
                  ? (theme.isDark ? ImagoColors.violetGradient : null)
                  : null,
              color: isSelected
                  ? (theme.isDark ? null : theme.accentColor)
                  : theme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : theme.borderColor,
              ),
            ),
            child: Center(
              child: Text(
                '$chapter',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : theme.primaryText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: Verses ---
  Widget _buildVersesTab(ReaderTheme theme) {
    if (_loadingCounts) {
      return Center(child: CircularProgressIndicator(color: theme.accentColor));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        childAspectRatio: 1.1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: _verseCount,
      itemBuilder: (ctx, i) {
        final verse = i + 1;
        final isSelected = verse == _selectedVerse;

        return GestureDetector(
          onTap: () => _onVersePicked(verse),
          child: Container(
            decoration: BoxDecoration(
              gradient: isSelected
                  ? (theme.isDark ? ImagoColors.violetGradient : null)
                  : null,
              color: isSelected
                  ? (theme.isDark ? null : theme.accentColor)
                  : theme.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : theme.borderColor,
              ),
            ),
            child: Center(
              child: Text(
                '$verse',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? Colors.white : theme.primaryText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
