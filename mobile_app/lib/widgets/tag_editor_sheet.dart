// lib/widgets/tag_editor_sheet.dart

import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../theme/imago_theme.dart';

class TagEditorSheet extends StatefulWidget {
  final BibleVerse verse;
  final VoidCallback onTagsUpdated;

  final ReaderTheme? readerTheme;

  const TagEditorSheet({
    super.key,
    required this.verse,
    required this.onTagsUpdated,
    this.readerTheme,
  });

  static void show(
    BuildContext context, {
    required BibleVerse verse,
    required VoidCallback onTagsUpdated,
    ReaderTheme? readerTheme,
  }) {
    final theme = readerTheme ?? ReaderTheme.current;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TagEditorSheet(
        verse: verse,
        onTagsUpdated: onTagsUpdated,
        readerTheme: theme,
      ),
    );
  }

  @override
  State<TagEditorSheet> createState() => _TagEditorSheetState();
}

class _TagEditorSheetState extends State<TagEditorSheet> {
  final TextEditingController _controller = TextEditingController();
  List<BibleTag> _currentTags = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  Future<void> _loadTags() async {
    final tags = await UserDataService.instance.getTagsForVerse(
      widget.verse.book,
      widget.verse.chapter,
      widget.verse.verse,
    );
    if (mounted) {
      setState(() {
        _currentTags = tags;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTag() async {
    final tagText = _controller.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (tagText.isEmpty) return;

    _controller.clear();
    setState(() => _isLoading = true);

    final tag = BibleTag(
      id: 0,
      book: widget.verse.book,
      chapter: widget.verse.chapter,
      verse: widget.verse.verse,
      tag: tagText,
    );

    await UserDataService.instance.addTag(tag);
    widget.onTagsUpdated();
    await _loadTags();
  }

  Future<void> _removeTag(String tagText) async {
    setState(() => _isLoading = true);
    await UserDataService.instance.removeTag(
      widget.verse.book,
      widget.verse.chapter,
      widget.verse.verse,
      tagText,
    );
    widget.onTagsUpdated();
    await _loadTags();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme ?? ReaderTheme.current;
    final isDark = theme.isDark;
    final textPrimary = theme.primaryText;
    final textSecondary = theme.secondaryText;
    final accent = theme.accentColor;
    final containerBg = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC);
    final borderColor = theme.borderColor;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verse Tags',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.verse.reference,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Current tags wrap
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: accent))
          else if (_currentTags.isEmpty)
            Text(
              'No tags yet. Add one below (e.g. faith, marriage).',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: textSecondary.withOpacity(0.6),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentTags.map((tagObj) {
                return Chip(
                  label: Text(
                    '#${tagObj.tag}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? Colors.white : const Color(0xFF312E81),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor: isDark ? ImagoColors.gold.withOpacity(0.2) : const Color(0xFFEEF2FF),
                  side: BorderSide(color: isDark ? ImagoColors.gold.withOpacity(0.5) : const Color(0xFFC7D2FE)),
                  deleteIcon: Icon(Icons.close_rounded, size: 16, color: isDark ? Colors.white70 : const Color(0xFF4F46E5)),
                  onDeleted: () => _removeTag(tagObj.tag),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                );
              }).toList(),
            ),
            
          const SizedBox(height: 24),
          
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: containerBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a tag...',
                      hintStyle: TextStyle(
                        color: textSecondary.withOpacity(0.6),
                        fontFamily: 'Poppins',
                      ),
                      border: InputBorder.none,
                      prefixText: '#',
                      prefixStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: isDark ? (accent == ImagoColors.gold ? Colors.black87 : Colors.white) : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
