import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../theme/imago_theme.dart';

class NoteEditorSheet extends StatefulWidget {
  final BibleVerse verse;
  final BibleNote? initialNote;
  final VoidCallback onSaved;

  final ReaderTheme? readerTheme;

  const NoteEditorSheet({
    super.key,
    required this.verse,
    this.initialNote,
    required this.onSaved,
    this.readerTheme,
  });

  static void show(
    BuildContext context, {
    required BibleVerse verse,
    BibleNote? initialNote,
    required VoidCallback onSaved,
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
      builder: (ctx) => NoteEditorSheet(
        verse: verse,
        initialNote: initialNote,
        onSaved: onSaved,
        readerTheme: theme,
      ),
    );
  }

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _controller;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    String initialText = '';
    if (widget.initialNote != null && widget.initialNote!.content.isNotEmpty) {
      initialText = _extractText(widget.initialNote!.content);
    }
    _controller = TextEditingController(text: initialText);
  }

  String _extractText(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is List) {
        String text = '';
        for (var op in decoded) {
          if (op is Map && op.containsKey('insert')) {
            final insert = op['insert'];
            if (insert is String) text += insert;
          }
        }
        return text;
      }
    } catch (_) {}
    return content;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveNote() async {
    final text = _controller.text.trim();
    
    setState(() => _isSaving = true);
    
    if (text.isEmpty) {
      if (widget.initialNote != null) {
        await UserDataService.instance.deleteNote(
          widget.verse.book,
          widget.verse.chapter,
          widget.verse.verse,
        );
      }
    } else {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final note = BibleNote(
        id: widget.initialNote?.id ?? 0,
        book: widget.verse.book,
        chapter: widget.verse.chapter,
        verse: widget.verse.verse,
        content: text,
        createdAt: widget.initialNote?.createdAt ?? now,
        updatedAt: now,
      );
      
      if (widget.initialNote == null) {
        await UserDataService.instance.saveNote(note);
      } else {
        await UserDataService.instance.saveNote(note);
      }
    }
    
    setState(() => _isSaving = false);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final theme = widget.readerTheme ?? ReaderTheme.current;
    final isDark = theme.isDark;
    final textPrimary = theme.primaryText;
    final textSecondary = theme.secondaryText;
    final accent = theme.accentColor;
    final containerBg = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC);
    final borderColor = theme.borderColor;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + keyboardHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.verse.bookName} ${widget.verse.chapter}:${widget.verse.verse}',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Study Notes',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (_isSaving)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 2,
                  ),
                )
              else
                GestureDetector(
                  onTap: _saveNote,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? (accent == ImagoColors.gold ? Colors.black87 : Colors.white) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: containerBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                autofocus: true,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write your notes here...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
