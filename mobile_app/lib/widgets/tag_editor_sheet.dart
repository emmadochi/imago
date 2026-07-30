// lib/widgets/tag_editor_sheet.dart

import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../theme/imago_theme.dart';

class TagEditorSheet extends StatefulWidget {
  final BibleVerse verse;
  final VoidCallback onTagsUpdated;

  const TagEditorSheet({
    super.key,
    required this.verse,
    required this.onTagsUpdated,
  });

  static void show(
    BuildContext context, {
    required BibleVerse verse,
    required VoidCallback onTagsUpdated,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => TagEditorSheet(
        verse: verse,
        onTagsUpdated: onTagsUpdated,
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
                      color: ImagoColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    widget.verse.reference,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          // Current tags wrap
          if (_isLoading)
            Center(child: CircularProgressIndicator(color: ImagoColors.gold))
          else if (_currentTags.isEmpty)
            Text(
              'No tags yet. Add one below (e.g. faith, marriage).',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.4),
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
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: ImagoColors.gold.withOpacity(0.2),
                  side: BorderSide(color: ImagoColors.gold.withOpacity(0.5)),
                  deleteIcon: Icon(Icons.close_rounded, size: 16, color: Colors.white70),
                  onDeleted: () => _removeTag(tagObj.tag),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                );
              }).toList(),
            ),
            
          SizedBox(height: 24),
          
          // Input row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Add a tag...',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontFamily: 'Poppins',
                      ),
                      border: InputBorder.none,
                      prefixText: '#',
                      prefixStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
              ),
              SizedBox(width: 12),
              GestureDetector(
                onTap: _addTag,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: ImagoColors.goldGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.add_rounded, color: Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
