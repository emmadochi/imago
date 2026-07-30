import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../theme/imago_theme.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../services/bible_service.dart';

class JournalEditorScreen extends StatefulWidget {
  final JournalEntry? entry;

  const JournalEditorScreen({super.key, this.entry});

  @override
  State<JournalEditorScreen> createState() => _JournalEditorScreenState();
}

class _JournalEditorScreenState extends State<JournalEditorScreen> {
  late quill.QuillController _controller;
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _tags = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    
    _titleController.text = widget.entry?.title ?? '';
    _tags = List.from(widget.entry?.tags ?? []);

    if (widget.entry != null && widget.entry!.content.isNotEmpty) {
      try {
        final doc = quill.Document.fromJson(jsonDecode(widget.entry!.content));
        _controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = quill.QuillController.basic();
      }
    } else {
      _controller = quill.QuillController.basic();
    }

    _controller.addListener(_onContentChanged);
    _titleController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _saveEntry() async {
    if (_titleController.text.isEmpty && _controller.document.isEmpty()) {
      Navigator.pop(context, false);
      return;
    }

    final content = jsonEncode(_controller.document.toDelta().toJson());
    
    final newEntry = JournalEntry(
      id: widget.entry?.id,
      title: _titleController.text.trim(),
      content: content,
      tags: _tags,
      createdAt: widget.entry?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await UserDataService.instance.saveJournalEntry(newEntry);
    if (mounted) Navigator.pop(context, true);
  }

  void _addTag(String tag) {
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _hasChanges = true;
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasChanges = true;
    });
  }

  Future<void> _insertVerse() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        final ctrl = TextEditingController();
        return AlertDialog(
          backgroundColor: const Color(0xFF1B1147),
          title: const Text('Insert Verse', style: TextStyle(fontFamily: 'Cinzel', color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'e.g. John 3:16',
              hintStyle: TextStyle(color: Colors.white38),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: Text('Insert', style: TextStyle(color: ImagoColors.gold)),
            ),
          ],
        );
      }
    );

    if (result != null && result.isNotEmpty) {
      final index = _controller.selection.baseOffset;
      final length = _controller.selection.extentOffset - index;
      
      _controller.replaceText(index, length, '\\n"For God so loved the world..." - $result\\n', 
        TextSelection.collapsed(offset: index + result.length + 38));
        
      _controller.formatSelection(quill.Attribute.blockQuote);
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
      body: Stack(
        children: [
          const CosmicBackground(children: []),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildTitleField(),
                if (_tags.isNotEmpty) _buildTagsList(),
                quill.QuillSimpleToolbar(
                  controller: _controller,
                  config: quill.QuillSimpleToolbarConfig(
                    customButtons: [
                      quill.QuillToolbarCustomButtonOptions(
                        icon: const Icon(Icons.auto_stories_rounded),
                        tooltip: 'Insert Bible Verse',
                        onPressed: _insertVerse,
                      ),
                    ],
                    showFontFamily: false,
                    showFontSize: false,
                    showSmallButton: false,
                    showInlineCode: false,
                    showColorButton: false,
                    showBackgroundColorButton: false,
                    showClearFormat: false,
                    showAlignmentButtons: false,
                    showLeftAlignment: false,
                    showCenterAlignment: false,
                    showRightAlignment: false,
                    showJustifyAlignment: false,
                    showHeaderStyle: true,
                    showListNumbers: true,
                    showListBullets: true,
                    showListCheck: true,
                    showCodeBlock: false,
                    showQuote: true,
                    showIndent: false,
                    showLink: true,
                    showUndo: true,
                    showRedo: true,
                    showDirection: false,
                    showSearchButton: false,
                    showSubscript: false,
                    showSuperscript: false,
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: quill.QuillEditor.basic(
                      controller: _controller,
                      focusNode: _focusNode,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context, false),
          ),
          TextButton.icon(
            onPressed: _hasChanges ? _saveEntry : null,
            icon: Icon(Icons.check_rounded, 
              color: _hasChanges ? ImagoColors.gold : Colors.white24, 
              size: 20
            ),
            label: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _hasChanges ? ImagoColors.gold : Colors.white24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _titleController,
        style: const TextStyle(
          fontFamily: 'Cinzel',
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: 'Journal Title...',
          hintStyle: TextStyle(
            fontFamily: 'Cinzel',
            color: Colors.white.withOpacity(0.3),
            fontSize: 24,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTagsList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: _tags.map((tag) => Chip(
            label: Text(
              tag,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFF5C6BC0),
                fontSize: 12,
              ),
            ),
            backgroundColor: const Color(0xFF5C6BC0).withOpacity(0.15),
            side: BorderSide(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
            onDeleted: () => _removeTag(tag),
            deleteIconColor: const Color(0xFF5C6BC0),
          )).toList(),
        ),
      ),
    );
  }
}
