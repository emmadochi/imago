// lib/widgets/desktop_study_inspector.dart
// Creative Desktop Scripture Study Station: Dockable right-hand inspector
// with Parallel Translation, Matthew Henry Commentary, Cross-References, and Study Notes.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/bible_service.dart';
import '../services/commentary_service.dart';
import '../services/crossref_service.dart';
import '../services/user_data_service.dart';
import '../theme/imago_theme.dart';

enum DesktopInspectorTab {
  parallel,
  commentary,
  crossref,
  notes,
}

class DesktopStudyInspector extends StatefulWidget {
  final BibleBook book;
  final int chapter;
  final BibleVerse? selectedVerse;
  final ReaderTheme readerTheme;
  final DesktopInspectorTab initialTab;
  final VoidCallback onClose;
  final Function(int book, int chapter, int verse) onNavigateVerse;

  const DesktopStudyInspector({
    super.key,
    required this.book,
    required this.chapter,
    required this.selectedVerse,
    required this.readerTheme,
    this.initialTab = DesktopInspectorTab.parallel,
    required this.onClose,
    required this.onNavigateVerse,
  });

  @override
  State<DesktopStudyInspector> createState() => _DesktopStudyInspectorState();
}

class _DesktopStudyInspectorState extends State<DesktopStudyInspector> {
  late DesktopInspectorTab _currentTab;

  // Parallel Translation State
  String _parallelTranslation = 'NIV';
  List<BibleVerse> _parallelVerses = [];
  bool _loadingParallel = false;

  // Commentary State
  String _selectedCommentaryModule = 'matthew_henry';
  bool _loadingCommentary = false;
  String? _commentaryTitle;
  String? _commentaryText;

  // Cross-Reference State
  bool _loadingCrossref = false;
  List<String> _crossReferences = [];

  // Study Note State
  final _noteController = TextEditingController();
  bool _savingNote = false;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
    _initTabContent();
  }

  @override
  void didUpdateWidget(covariant DesktopStudyInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.book != widget.book ||
        oldWidget.chapter != widget.chapter ||
        oldWidget.selectedVerse != widget.selectedVerse) {
      _initTabContent();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _initTabContent() {
    switch (_currentTab) {
      case DesktopInspectorTab.parallel:
        _loadParallelTranslation();
        break;
      case DesktopInspectorTab.commentary:
        _loadCommentary();
        break;
      case DesktopInspectorTab.crossref:
        _loadCrossReferences();
        break;
      case DesktopInspectorTab.notes:
        _loadStudyNote();
        break;
    }
  }

  // ── Parallel Translation ──────────────────────────────────────────────
  Future<void> _loadParallelTranslation() async {
    setState(() => _loadingParallel = true);
    try {
      final verses = await BibleService.instance.getVerses(
        widget.book.number,
        widget.chapter,
        translationAbbreviation: _parallelTranslation,
      );
      if (mounted) {
        setState(() {
          _parallelVerses = verses;
          _loadingParallel = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingParallel = false);
    }
  }

  // ── Commentary ────────────────────────────────────────────────────────
  Future<void> _loadCommentary() async {
    final v = widget.selectedVerse;
    if (v == null) {
      setState(() {
        _commentaryTitle = null;
        _commentaryText = 'Select or right-click any verse to view its commentary.';
        _loadingCommentary = false;
      });
      return;
    }

    setState(() => _loadingCommentary = true);
    try {
      final entry = await CommentaryService.instance.getCommentary(
        moduleId: _selectedCommentaryModule,
        book: v.book,
        chapter: v.chapter,
        verse: v.verse,
      );
      if (mounted) {
        setState(() {
          _commentaryTitle = entry?['title'] as String?;
          _commentaryText = entry?['text'] as String? ?? 'No commentary entry found for ${v.reference}.';
          _loadingCommentary = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _commentaryText = 'Unable to load commentary.';
          _loadingCommentary = false;
        });
      }
    }
  }

  // ── Cross-References ──────────────────────────────────────────────────
  Future<void> _loadCrossReferences() async {
    final v = widget.selectedVerse;
    if (v == null) {
      setState(() {
        _crossReferences = [];
        _loadingCrossref = false;
      });
      return;
    }

    setState(() => _loadingCrossref = true);
    try {
      final refs = await CrossrefService.instance.getCrossReferences(
        v.book,
        v.chapter,
        v.verse,
      );
      if (mounted) {
        setState(() {
          _crossReferences = refs;
          _loadingCrossref = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCrossref = false);
    }
  }

  // ── Study Notes ───────────────────────────────────────────────────────
  Future<void> _loadStudyNote() async {
    final v = widget.selectedVerse;
    if (v == null) return;
    try {
      final notes = await UserDataService.instance.getNotesForChapter(v.book, v.chapter);
      final activeNote = notes.where((n) => n.verse == v.verse).firstOrNull;
      if (mounted) {
        _noteController.text = activeNote?.content ?? '';
      }
    } catch (_) {}
  }

  Future<void> _saveStudyNote() async {
    final v = widget.selectedVerse;
    if (v == null) return;
    setState(() => _savingNote = true);
    try {
      final cleanText = _noteController.text.trim();
      if (cleanText.isEmpty) {
        await UserDataService.instance.deleteNote(v.book, v.chapter, v.verse);
      } else {
        final now = DateTime.now().millisecondsSinceEpoch;
        await UserDataService.instance.saveNote(BibleNote(
          id: 0,
          book: v.book,
          chapter: v.chapter,
          verse: v.verse,
          content: cleanText,
          createdAt: now,
          updatedAt: now,
        ));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved study note for ${v.reference}!'),
            backgroundColor: widget.readerTheme.accentColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  void _insertVerseQuote() {
    final v = widget.selectedVerse;
    if (v == null) return;
    final quote = '\n\n"${v.text}" — ${v.reference}\n\n';
    final current = _noteController.text;
    _noteController.text = current + quote;
    _noteController.selection = TextSelection.fromPosition(
      TextPosition(offset: _noteController.text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme;
    final isDark = theme.isDark;

    return Container(
      width: 390,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.06),
            blurRadius: 16,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header Bar ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: theme.accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Study Station',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryText,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        widget.selectedVerse != null
                            ? widget.selectedVerse!.reference
                            : '${widget.book.name} ${widget.chapter}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: theme.accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: theme.secondaryText,
                  tooltip: 'Close Study Station (Ctrl+P)',
                  onPressed: widget.onClose,
                ),
              ],
            ),
          ),

          // ── Tab Bar Navigation ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B132B) : const Color(0xFFF1F5F9),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                ),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton(
                  tab: DesktopInspectorTab.parallel,
                  icon: Icons.splitscreen_rounded,
                  label: 'Parallel',
                ),
                _buildTabButton(
                  tab: DesktopInspectorTab.commentary,
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Commentary',
                ),
                _buildTabButton(
                  tab: DesktopInspectorTab.crossref,
                  icon: Icons.alt_route_rounded,
                  label: 'Cross-Refs',
                ),
                _buildTabButton(
                  tab: DesktopInspectorTab.notes,
                  icon: Icons.edit_note_rounded,
                  label: 'Notes',
                ),
              ],
            ),
          ),

          // ── Active Tab View ──────────────────────────────────────────
          Expanded(
            child: _buildTabBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required DesktopInspectorTab tab,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentTab == tab;
    final isDark = widget.readerTheme.isDark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _currentTab = tab);
          _initTabContent();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF4F46E5) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF4F46E5))
                    : widget.readerTheme.secondaryText,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : widget.readerTheme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(ReaderTheme theme) {
    switch (_currentTab) {
      case DesktopInspectorTab.parallel:
        return _buildParallelView(theme);
      case DesktopInspectorTab.commentary:
        return _buildCommentaryView(theme);
      case DesktopInspectorTab.crossref:
        return _buildCrossrefView(theme);
      case DesktopInspectorTab.notes:
        return _buildNotesView(theme);
    }
  }

  // ── Parallel Translation Body ─────────────────────────────────────────
  Widget _buildParallelView(ReaderTheme theme) {
    final isDark = theme.isDark;
    final translations = ['NIV', 'KJV', 'ASV', 'MSG', 'AMP', 'EasyEnglish'];

    return Column(
      children: [
        // Translation Switcher Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B).withOpacity(0.3) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Compare with:',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  color: theme.secondaryText,
                ),
              ),
              const Spacer(),
              DropdownButton<String>(
                value: _parallelTranslation,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryText,
                ),
                underline: const SizedBox(),
                isDense: true,
                items: translations
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) {
                  if (val != null && val != _parallelTranslation) {
                    setState(() => _parallelTranslation = val);
                    _loadParallelTranslation();
                  }
                },
              ),
            ],
          ),
        ),

        // Verses List
        Expanded(
          child: _loadingParallel
              ? Center(child: CircularProgressIndicator(color: theme.accentColor))
              : _parallelVerses.isEmpty
                  ? Center(
                      child: Text(
                        'No parallel verses available.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: theme.secondaryText,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      itemCount: _parallelVerses.length,
                      itemBuilder: (context, index) {
                        final v = _parallelVerses[index];
                        final isFocused = widget.selectedVerse?.verse == v.verse;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isFocused
                                ? theme.accentColor.withOpacity(isDark ? 0.2 : 0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isFocused
                                ? Border.all(color: theme.accentColor.withOpacity(0.4))
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${v.verse}',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.verseNumberColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  v.text,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    height: 1.55,
                                    color: theme.primaryText,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 14),
                                color: theme.secondaryText.withOpacity(0.6),
                                tooltip: 'Copy verse (${_parallelTranslation})',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(
                                    text: '${v.text} — ${v.reference} ($_parallelTranslation)',
                                  ));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('${v.reference} ($_parallelTranslation) copied!'),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── Commentary View Body ─────────────────────────────────────────────
  Widget _buildCommentaryView(ReaderTheme theme) {
    final v = widget.selectedVerse;

    return Column(
      children: [
        // Module Picker & Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF1E293B).withOpacity(0.3) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  v != null ? 'Exposition: ${v.reference}' : 'Commentary',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryText,
                  ),
                ),
              ),
              if (_commentaryText != null && _commentaryText!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  color: theme.secondaryText,
                  tooltip: 'Copy Commentary Note',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(
                      text: 'Commentary on ${v?.reference ?? ""}:\n$_commentaryText',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Commentary copied to clipboard!')),
                    );
                  },
                ),
            ],
          ),
        ),

        // Commentary Content
        Expanded(
          child: _loadingCommentary
              ? Center(child: CircularProgressIndicator(color: theme.accentColor))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_commentaryTitle != null && _commentaryTitle!.isNotEmpty) ...[
                        Text(
                          _commentaryTitle!,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        _commentaryText ?? 'Select a verse on the left to read its commentary.',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          height: 1.65,
                          color: theme.primaryText,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // ── Cross-References View Body ────────────────────────────────────────
  Widget _buildCrossrefView(ReaderTheme theme) {
    final v = widget.selectedVerse;

    if (v == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Click or right-click any verse to view Treasury of Scripture Knowledge cross-references.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              color: theme.secondaryText,
            ),
          ),
        ),
      );
    }

    if (_loadingCrossref) {
      return Center(child: CircularProgressIndicator(color: theme.accentColor));
    }

    if (_crossReferences.isEmpty) {
      return Center(
        child: Text(
          'No cross-references cataloged for ${v.reference}.',
          style: TextStyle(fontFamily: 'Poppins', color: theme.secondaryText),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.isDark ? const Color(0xFF1E293B).withOpacity(0.3) : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: theme.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${_crossReferences.length} Connected Scriptures',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: _crossReferences.length,
            itemBuilder: (context, index) {
              final ref = _crossReferences[index];

              return Card(
                color: theme.cardBackground,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: theme.borderColor.withOpacity(0.5)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.alt_route_rounded,
                    color: theme.accentColor,
                    size: 16,
                  ),
                  title: Text(
                    ref,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                  onTap: () async {
                    final parsed = _parseReference(ref);
                    if (parsed != null) {
                      widget.onNavigateVerse(parsed['book']!, parsed['chapter']!, parsed['verse']!);
                    }
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Map<String, int>? _parseReference(String ref) {
    try {
      final parts = ref.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) return null;
      final bookPart = parts.sublist(0, parts.length - 1).join(' ').toLowerCase();
      final numParts = parts.last.split(':');
      final chapter = int.tryParse(numParts.first);
      final verse = numParts.length > 1 ? int.tryParse(numParts[1]) : 1;

      final matchBook = kBibleBooks.firstWhere(
        (b) => b.name.toLowerCase() == bookPart || b.name.toLowerCase().startsWith(bookPart),
        orElse: () => kBibleBooks.first,
      );

      if (chapter != null) {
        return {'book': matchBook.number, 'chapter': chapter, 'verse': verse ?? 1};
      }
    } catch (_) {}
    return null;
  }

  // ── Study Notes View Body ─────────────────────────────────────────────
  Widget _buildNotesView(ReaderTheme theme) {
    final v = widget.selectedVerse;
    final isDark = theme.isDark;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Personal Reflection',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryText,
                ),
              ),
              const Spacer(),
              if (v != null)
                TextButton.icon(
                  onPressed: _insertVerseQuote,
                  icon: const Icon(Icons.format_quote_rounded, size: 14),
                  label: const Text('Insert Scripture', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.accentColor,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.borderColor),
              ),
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _noteController,
                maxLines: null,
                expands: true,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  height: 1.6,
                  color: theme.primaryText,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: v != null
                      ? 'Write your study notes and sermon insights on ${v.reference}...'
                      : 'Select a verse to record your personal reflections...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: theme.secondaryText.withOpacity(0.6),
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: v != null && !_savingNote ? _saveStudyNote : null,
              icon: _savingNote
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(
                _savingNote ? 'Saving...' : 'Save Note for ${v?.reference ?? "Verse"}',
                style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
