import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../theme/imago_theme.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import '../services/bible_service.dart';

class JournalEditorScreen extends StatefulWidget {
  final JournalEntry? entry;
  final String? initialTitle;
  final String? initialVerseQuote;

  const JournalEditorScreen({
    super.key,
    this.entry,
    this.initialTitle,
    this.initialVerseQuote,
  });

  /// Formats a list of [BibleVerse] objects cleanly for journal quotation,
  /// stripping raw MyBible HTML/Strong's tags while preserving verse numbers for ranges.
  static String formatVersesForJournal(List<BibleVerse> verses) {
    if (verses.isEmpty) return '';
    final first = verses.first;
    final last = verses.last;
    final ref = verses.length == 1
        ? first.reference
        : '${first.bookName} ${first.chapter}:${first.verse}-${last.verse}';

    final cleanCombined = verses.map((v) {
      final cleaned = BibleVerse.cleanText(v.text)
          .replaceAll(RegExp(r'\[[GH]\d+\]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return verses.length > 1 ? '[${v.verse}] $cleaned' : cleaned;
    }).join(' ');

    return '"$cleanCombined" — $ref';
  }

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
    
    _titleController.text = widget.entry?.title ?? widget.initialTitle ?? '';
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
    } else if (widget.initialVerseQuote != null && widget.initialVerseQuote!.trim().isNotEmpty) {
      final quote = '${widget.initialVerseQuote!.trim()}\n';
      final doc = quill.Document()..insert(0, '$quote\n');
      _controller = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _controller.formatText(0, quote.length - 1, quill.Attribute.blockQuote);
      _controller.updateSelection(
        TextSelection.collapsed(offset: doc.length - 1),
        quill.ChangeSource.local,
      );
      _hasChanges = true;
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
    final selectedQuote = await showDialog<String>(
      context: context,
      builder: (ctx) => const _InsertVersePickerDialog(),
    );

    if (selectedQuote != null && selectedQuote.trim().isNotEmpty && mounted) {
      final docLength = _controller.document.length;
      final rawBase = _controller.selection.baseOffset;
      final rawExtent = _controller.selection.extentOffset;
      final start = (rawBase < 0 ? docLength - 1 : rawBase).clamp(0, docLength - 1);
      final end = (rawExtent < 0 ? start : rawExtent).clamp(start, docLength - 1);
      final replaceLen = end - start;

      final needsLeadingNewline = start > 0 && _controller.document.toPlainText()[start - 1] != '\n';
      final prefix = needsLeadingNewline ? '\n' : '';
      final insertedBlock = '$prefix${selectedQuote.trim()}\n\n';

      _controller.replaceText(
        start,
        replaceLen,
        insertedBlock,
        TextSelection.collapsed(offset: start + insertedBlock.length),
      );

      final quoteStart = start + prefix.length;
      _controller.formatText(quoteStart, selectedQuote.trim().length, quill.Attribute.blockQuote);
      setState(() => _hasChanges = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final bg = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF131D33) : Colors.white;
        final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              if (isDark) const CosmicBackground(children: []),
              SafeArea(
                child: Column(
                  children: [
                    _buildAppBar(isDark, cardBg, border, textPrimary, textSecondary),
                    _buildTitleField(textPrimary, textSecondary),
                    if (_tags.isNotEmpty) _buildTagsList(isDark),
                    Container(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      child: quill.QuillSimpleToolbar(
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
                    ),
                    Divider(height: 1, color: border),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
      },
    );
  }

  Widget _buildAppBar(bool isDark, Color cardBg, Color border, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: textPrimary),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton.icon(
            onPressed: _hasChanges ? _saveEntry : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _hasChanges ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              foregroundColor: _hasChanges ? Colors.white : textSecondary.withOpacity(0.6),
              elevation: _hasChanges ? 2 : 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            icon: Icon(
              Icons.check_rounded,
              color: _hasChanges ? Colors.white : textSecondary.withOpacity(0.6),
              size: 18,
            ),
            label: Text(
              'Save',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _hasChanges ? Colors.white : textSecondary.withOpacity(0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _titleController,
        style: TextStyle(
          fontFamily: 'Cinzel',
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: 'Journal Title...',
          hintStyle: TextStyle(
            fontFamily: 'Cinzel',
            color: textSecondary.withOpacity(0.5),
            fontSize: 24,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildTagsList(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          children: _tags.map((tag) => Chip(
            label: Text(
              tag,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: isDark ? const Color(0xFF4F46E5).withOpacity(0.18) : const Color(0xFFEEF2FF),
            side: BorderSide(color: isDark ? const Color(0xFF4F46E5).withOpacity(0.4) : const Color(0xFFC7D2FE)),
            onDeleted: () => _removeTag(tag),
            deleteIconColor: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
          )).toList(),
        ),
      ),
    );
  }
}

class _InsertVersePickerDialog extends StatefulWidget {
  const _InsertVersePickerDialog();

  @override
  State<_InsertVersePickerDialog> createState() => _InsertVersePickerDialogState();
}

class _InsertVersePickerDialogState extends State<_InsertVersePickerDialog> {
  final TextEditingController _refController = TextEditingController();
  Timer? _debounce;
  bool _browseMode = false; // false = Type Reference, true = Browse Book/Chapter/Verse

  // Search Reference state
  List<BibleVerse> _fetchedVerses = [];
  bool _isSearching = false;
  String? _statusMessage;

  // Browse Picker state
  BibleBook _selectedBook = kBibleBooks.firstWhere((b) => b.name == 'Psalms', orElse: () => kBibleBooks.first);
  int _selectedChapter = 23;
  int _chapterCount = 150;
  List<BibleVerse> _chapterVerses = [];
  int _startVerse = 1;
  int _endVerse = 1;
  bool _loadingBrowse = false;

  @override
  void initState() {
    super.initState();
    _loadBrowseChapter();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _lookupReference(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _fetchedVerses = [];
        _isSearching = false;
        _statusMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _statusMessage = null;
    });

    try {
      final results = await BibleService.instance.getVerseByReference(trimmed);
      if (!mounted) return;
      setState(() {
        _fetchedVerses = results;
        _isSearching = false;
        if (results.isEmpty) {
          _statusMessage = 'No scripture matched "$trimmed". Try format like "Psalm 23:1" or "Romans 8:28-30".';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchedVerses = [];
        _isSearching = false;
        _statusMessage = 'Could not look up "$trimmed".';
      });
    }
  }

  Future<void> _loadBrowseChapter() async {
    setState(() => _loadingBrowse = true);
    try {
      final count = await BibleService.instance.getChapterCount(_selectedBook.number);
      final safeChapter = _selectedChapter.clamp(1, count > 0 ? count : 1);
      final verses = await BibleService.instance.getVerses(_selectedBook.number, safeChapter);
      if (!mounted) return;
      setState(() {
        _chapterCount = count > 0 ? count : 1;
        _selectedChapter = safeChapter;
        _chapterVerses = verses;
        final maxV = verses.isNotEmpty ? verses.last.verse : 1;
        _startVerse = _startVerse.clamp(1, maxV);
        _endVerse = _endVerse.clamp(_startVerse, maxV);
        _loadingBrowse = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _chapterVerses = [];
        _loadingBrowse = false;
      });
    }
  }

  List<BibleVerse> get _activeSelectedVerses {
    if (!_browseMode) return _fetchedVerses;
    return _chapterVerses.where((v) => v.verse >= _startVerse && v.verse <= _endVerse).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ImagoColors.isDark;
    final bg = isDark ? const Color(0xFF131D33) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
    final activeVerses = _activeSelectedVerses;

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        'Insert Bible Verse',
        style: TextStyle(fontFamily: 'Cinzel', color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mode selector: Type Reference vs Browse Bible
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _browseMode = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: !_browseMode ? const Color(0xFF4F46E5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Type Reference',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: !_browseMode ? Colors.white : textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _browseMode = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: _browseMode ? const Color(0xFF4F46E5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Browse Bible',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _browseMode ? Colors.white : textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (!_browseMode) ...[
                TextField(
                  controller: _refController,
                  autofocus: true,
                  style: TextStyle(color: textPrimary, fontFamily: 'Poppins', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Psalm 23:1 or Romans 8:28',
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.6), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF4F46E5)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onChanged: (val) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      _lookupReference(val);
                    });
                  },
                  onSubmitted: _lookupReference,
                ),
              ] else ...[
                // Book dropdown
                DropdownButtonFormField<BibleBook>(
                  value: _selectedBook,
                  isExpanded: true,
                  dropdownColor: bg,
                  style: TextStyle(fontFamily: 'Poppins', color: textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Book',
                    labelStyle: TextStyle(fontFamily: 'Poppins', color: textSecondary, fontSize: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: kBibleBooks.map((b) => DropdownMenuItem(value: b, child: Text(b.name))).toList(),
                  onChanged: (book) {
                    if (book != null) {
                      setState(() {
                        _selectedBook = book;
                        _selectedChapter = 1;
                        _startVerse = 1;
                        _endVerse = 1;
                      });
                      _loadBrowseChapter();
                    }
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Chapter dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedChapter.clamp(1, _chapterCount),
                        dropdownColor: bg,
                        style: TextStyle(fontFamily: 'Poppins', color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Chapter',
                          labelStyle: TextStyle(fontFamily: 'Poppins', color: textSecondary, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: List.generate(_chapterCount, (i) => i + 1)
                            .map((c) => DropdownMenuItem(value: c, child: Text('$c')))
                            .toList(),
                        onChanged: (ch) {
                          if (ch != null) {
                            setState(() {
                              _selectedChapter = ch;
                              _startVerse = 1;
                              _endVerse = 1;
                            });
                            _loadBrowseChapter();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // From Verse dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _chapterVerses.isEmpty
                            ? 1
                            : _startVerse.clamp(1, _chapterVerses.last.verse),
                        dropdownColor: bg,
                        style: TextStyle(fontFamily: 'Poppins', color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'From Verse',
                          labelStyle: TextStyle(fontFamily: 'Poppins', color: textSecondary, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: (_chapterVerses.isEmpty ? [1] : _chapterVerses.map((v) => v.verse).toList())
                            .map((vNum) => DropdownMenuItem(value: vNum, child: Text('$vNum')))
                            .toList(),
                        onChanged: (vNum) {
                          if (vNum != null) {
                            setState(() {
                              _startVerse = vNum;
                              if (_endVerse < vNum) _endVerse = vNum;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // To Verse dropdown
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _chapterVerses.isEmpty
                            ? 1
                            : _endVerse.clamp(_startVerse, _chapterVerses.last.verse),
                        dropdownColor: bg,
                        style: TextStyle(fontFamily: 'Poppins', color: textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'To Verse',
                          labelStyle: TextStyle(fontFamily: 'Poppins', color: textSecondary, fontSize: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: (_chapterVerses.isEmpty
                                ? [1]
                                : _chapterVerses.where((v) => v.verse >= _startVerse).map((v) => v.verse).toList())
                            .map((vNum) => DropdownMenuItem(value: vNum, child: Text('$vNum')))
                            .toList(),
                        onChanged: (vNum) {
                          if (vNum != null) {
                            setState(() => _endVerse = vNum);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              // Live Scripture Preview
              if (_isSearching || _loadingBrowse)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4F46E5)),
                    ),
                  ),
                )
              else if (activeVerses.isNotEmpty)
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 160),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(isDark ? 0.14 : 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      JournalEditorScreen.formatVersesForJournal(activeVerses),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: textPrimary,
                      ),
                    ),
                  ),
                )
              else if (!_browseMode && _statusMessage != null)
                Text(
                  _statusMessage!,
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: textSecondary),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: textSecondary, fontFamily: 'Poppins')),
        ),
        ElevatedButton.icon(
          onPressed: activeVerses.isEmpty
              ? null
              : () => Navigator.pop(context, JournalEditorScreen.formatVersesForJournal(activeVerses)),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Insert', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }
}
