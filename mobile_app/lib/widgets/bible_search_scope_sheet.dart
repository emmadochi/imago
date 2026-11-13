// lib/widgets/bible_search_scope_sheet.dart
// Modal sheet for selecting MySword Bible groups or highlighting custom Bible books for search

import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../theme/imago_theme.dart';

class BibleSearchScopeResult {
  final String label;
  final List<int>? bookNumbers; // null or empty means Entire Bible (all 66 books)
  final String? groupName;

  const BibleSearchScopeResult({
    required this.label,
    this.bookNumbers,
    this.groupName,
  });

  bool get isEntireBible => bookNumbers == null || bookNumbers!.isEmpty || bookNumbers!.length == 66;
}

class BibleSearchScopeSheet extends StatefulWidget {
  final List<int>? initialSelectedBooks;
  final String? initialGroupName;
  final ReaderTheme readerTheme;
  final void Function(BibleSearchScopeResult result) onApply;

  const BibleSearchScopeSheet({
    super.key,
    this.initialSelectedBooks,
    this.initialGroupName,
    required this.readerTheme,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    List<int>? initialSelectedBooks,
    String? initialGroupName,
    required ReaderTheme readerTheme,
    required void Function(BibleSearchScopeResult result) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BibleSearchScopeSheet(
        initialSelectedBooks: initialSelectedBooks,
        initialGroupName: initialGroupName,
        readerTheme: readerTheme,
        onApply: onApply,
      ),
    );
  }

  @override
  State<BibleSearchScopeSheet> createState() => _BibleSearchScopeSheetState();
}

class _BibleSearchScopeSheetState extends State<BibleSearchScopeSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Set<int> _highlightedBooks;
  String? _selectedGroupId;
  String _bookFilter = '';

  @override
  void initState() {
    super.initState();
    _highlightedBooks = widget.initialSelectedBooks != null
        ? widget.initialSelectedBooks!.toSet()
        : <int>{};

    // Match group if present
    if (widget.initialGroupName != null) {
      final matched = kBibleSearchGroups.firstWhere(
        (g) => g.name == widget.initialGroupName,
        orElse: () => kBibleSearchGroups.first,
      );
      _selectedGroupId = matched.id;
    } else if (_highlightedBooks.isEmpty || _highlightedBooks.length == 66) {
      _selectedGroupId = 'all';
    }

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedGroupId != null ? 0 : 1,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _applyGroup(BibleSearchGroup group) {
    Navigator.pop(context);
    if (group.id == 'all') {
      widget.onApply(const BibleSearchScopeResult(
        label: 'Entire Bible',
        bookNumbers: null,
        groupName: 'Entire Bible',
      ));
    } else {
      widget.onApply(BibleSearchScopeResult(
        label: group.name,
        bookNumbers: group.bookNumbers,
        groupName: group.name,
      ));
    }
  }

  void _applyHighlightedBooks() {
    Navigator.pop(context);
    if (_highlightedBooks.isEmpty || _highlightedBooks.length == 66) {
      widget.onApply(const BibleSearchScopeResult(
        label: 'Entire Bible',
        bookNumbers: null,
        groupName: 'Entire Bible',
      ));
    } else if (_highlightedBooks.length == 1) {
      final bookNum = _highlightedBooks.first;
      final bookName = kBibleBooks.firstWhere((b) => b.number == bookNum).name;
      widget.onApply(BibleSearchScopeResult(
        label: bookName,
        bookNumbers: _highlightedBooks.toList()..sort(),
        groupName: null,
      ));
    } else {
      widget.onApply(BibleSearchScopeResult(
        label: '${_highlightedBooks.length} Books',
        bookNumbers: _highlightedBooks.toList()..sort(),
        groupName: null,
      ));
    }
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
            color: Colors.black.withOpacity(0.35),
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
                        'SEARCH SCOPE',
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
                        'Choose Where to Search',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: theme.secondaryText),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Tabs
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
              tabs: const [
                Tab(text: 'MySword Groups'),
                Tab(text: 'Highlight Books'),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGroupsTab(theme),
                _buildHighlightBooksTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: MySword Biblical Groups ---
  Widget _buildGroupsTab(ReaderTheme theme) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: kBibleSearchGroups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final group = kBibleSearchGroups[i];
        final isSelected = _selectedGroupId == group.id;

        return GestureDetector(
          onTap: () => _applyGroup(group),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? (theme.isDark ? ImagoColors.violetGradient : null)
                  : null,
              color: isSelected
                  ? (theme.isDark ? null : theme.accentColor)
                  : theme.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Colors.transparent : theme.borderColor,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : (theme.isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      group.id == 'all'
                          ? Icons.auto_stories_rounded
                          : (group.id == 'ot' || group.id == 'law'
                              ? Icons.history_edu_rounded
                              : Icons.menu_book_rounded),
                      size: 18,
                      color: isSelected ? Colors.white : theme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : theme.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        group.description,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: isSelected ? Colors.white70 : theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- TAB 2: Custom Multi-Book Selection (Highlight Books) ---
  Widget _buildHighlightBooksTab(ReaderTheme theme) {
    final query = _bookFilter.trim().toLowerCase();
    final filteredBooks = kBibleBooks.where((b) {
      if (query.isNotEmpty && !b.name.toLowerCase().contains(query)) return false;
      return true;
    }).toList();

    return Column(
      children: [
        // Action buttons row (Select All, OT, NT, Clear)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _quickActionButton('Select All', () {
                  setState(() => _highlightedBooks = List.generate(66, (i) => i + 1).toSet());
                }, theme),
                const SizedBox(width: 6),
                _quickActionButton('Old Testament', () {
                  setState(() => _highlightedBooks = List.generate(39, (i) => i + 1).toSet());
                }, theme),
                const SizedBox(width: 6),
                _quickActionButton('New Testament', () {
                  setState(() => _highlightedBooks = List.generate(27, (i) => i + 40).toSet());
                }, theme),
                const SizedBox(width: 6),
                _quickActionButton('Gospels', () {
                  setState(() => _highlightedBooks = {40, 41, 42, 43});
                }, theme),
                const SizedBox(width: 6),
                _quickActionButton('Clear', () {
                  setState(() => _highlightedBooks.clear());
                }, theme, isDestructive: true),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Search filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.borderColor),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _bookFilter = val),
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: theme.primaryText),
              decoration: InputDecoration(
                hintText: 'Search books to highlight...',
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

        const SizedBox(height: 10),

        // Grid of checkable book chips
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: filteredBooks.length,
            itemBuilder: (ctx, i) {
              final book = filteredBooks[i];
              final isHighlighted = _highlightedBooks.contains(book.number);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isHighlighted) {
                      _highlightedBooks.remove(book.number);
                    } else {
                      _highlightedBooks.add(book.number);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isHighlighted
                        ? (theme.isDark ? ImagoColors.violetGradient : null)
                        : null,
                    color: isHighlighted
                        ? (theme.isDark ? null : theme.accentColor)
                        : theme.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isHighlighted ? Colors.transparent : theme.borderColor,
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isHighlighted) ...[
                          const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            book.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                              color: isHighlighted ? Colors.white : theme.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom apply button
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          decoration: BoxDecoration(
            color: theme.surface,
            border: Border(top: BorderSide(color: theme.borderColor)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _applyHighlightedBooks,
              child: Text(
                _highlightedBooks.isEmpty
                    ? 'Search Entire Bible (All Books)'
                    : 'Apply ${_highlightedBooks.length} Highlighted Book${_highlightedBooks.length > 1 ? "s" : ""}',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton(String label, VoidCallback onTap, ReaderTheme theme, {bool isDestructive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.12)
              : theme.accentColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDestructive
                ? Colors.redAccent.withOpacity(0.3)
                : theme.accentColor.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDestructive ? Colors.redAccent : theme.accentColor,
          ),
        ),
      ),
    );
  }
}
