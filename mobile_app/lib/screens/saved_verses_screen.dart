import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_data_models.dart';
import '../models/bible_models.dart';
import '../services/user_data_service.dart';
import '../services/bible_service.dart';
import '../theme/imago_theme.dart';

class SavedVersesScreen extends StatefulWidget {
  const SavedVersesScreen({super.key});

  @override
  State<SavedVersesScreen> createState() => _SavedVersesScreenState();
}

class _SavedVersesScreenState extends State<SavedVersesScreen> {
  List<BibleBookmark> _bookmarks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final bookmarks = await UserDataService.instance.getBookmarks();
    if (mounted) {
      setState(() {
        _bookmarks = bookmarks;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBookmark(int id) async {
    await UserDataService.instance.deleteBookmark(id);
    _loadBookmarks();
  }

  Future<void> _showVerseDetails(BibleBookmark bookmark) async {
    final isDark = ImagoColors.isDark;
    // Fetch verse text
    final verses = await BibleService.instance.getVerses(bookmark.book, bookmark.chapter);
    final verse = verses.firstWhere(
      (v) => v.verse == bookmark.verse,
      orElse: () => BibleVerse(book: bookmark.book, bookName: '', chapter: bookmark.chapter, verse: bookmark.verse, text: 'Verse not found.'),
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ImagoColors.surface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      bookmark.title.isNotEmpty ? bookmark.title : 'Chapter ${bookmark.chapter}:${bookmark.verse}',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: isDark ? ImagoColors.gold : const Color(0xFFB45309),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                verse.text,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                  fontSize: 16,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteBookmark(bookmark.id!);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                  label: const Text('Remove Bookmark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
        final bg = isDark
            ? const Color(0xFF0A0E1A)
            : (isParchment ? const Color(0xFFF7F2E7) : const Color(0xFFF8FAFC));
        final cardBg = isDark
            ? const Color(0xFF131D33)
            : (isParchment ? const Color(0xFFFFFDF8) : Colors.white);
        final borderColor = isDark
            ? const Color(0xFF1E293B)
            : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));
        final textPrimary = isDark
            ? Colors.white
            : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              CosmicBackground(children: const []),
              Positioned(
                top: -40, left: -40,
                child: CosmicOrb(size: 260, color: ImagoColors.violet, opacity: isDark ? 0.08 : 0.04),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(isDark, cardBg, borderColor, textPrimary),
                    Expanded(child: _buildBody(isDark, cardBg, borderColor, textPrimary, textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, Color cardBg, Color borderColor, Color textPrimary) {
    final canPop = Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? ImagoColors.cardBackground : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 16),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Text(
            'Saved Verses',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5)),
      );
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border_rounded, size: 64, color: textSecondary.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'No saved verses yet.',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookmarks.length,
      itemBuilder: (ctx, i) {
        final bookmark = _bookmarks[i];
        final date = DateTime.fromMillisecondsSinceEpoch(bookmark.createdAt);
        final dateString = "${date.month}/${date.day}/${date.year}";

        return GestureDetector(
          onTap: () => _showVerseDetails(bookmark),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF64748B).withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? ImagoColors.gold.withOpacity(0.15) : const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.bookmark_rounded, color: isDark ? ImagoColors.gold : const Color(0xFFB45309), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bookmark.title.isNotEmpty ? bookmark.title : 'Chapter ${bookmark.chapter}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Saved on $dateString',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: textSecondary.withOpacity(0.5)),
              ],
            ),
          ),
        );
      },
    );
  }
}
