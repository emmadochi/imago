import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/imago_theme.dart';
import '../models/user_data_models.dart';
import '../services/user_data_service.dart';
import 'journal_editor_screen.dart';

class JournalListScreen extends StatefulWidget {
  const JournalListScreen({super.key});

  @override
  State<JournalListScreen> createState() => _JournalListScreenState();
}

class _JournalListScreenState extends State<JournalListScreen> {
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final entries = await UserDataService.instance.getJournalEntries();
    setState(() {
      _entries = entries;
      _isLoading = false;
    });
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
        final accent = isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5);

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              if (isDark) const CosmicBackground(children: []),
              SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAppBar(isDark, cardBg, border, textPrimary),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator(color: accent))
                          : _entries.isEmpty
                              ? _buildEmptyState(textPrimary, textSecondary)
                              : Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 860),
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                                      itemCount: _entries.length,
                                      itemBuilder: (ctx, i) => _buildJournalCard(
                                        _entries[i],
                                        isDark,
                                        cardBg,
                                        border,
                                        textPrimary,
                                        textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: const Color(0xFF4F46E5),
            elevation: 4,
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const JournalEditorScreen()),
              );
              if (result == true) {
                _loadEntries();
              }
            },
            icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
            label: const Text(
              'New Entry',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(bool isDark, Color cardBg, Color border, Color textPrimary) {
    final canPop = Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.arrow_back_ios_rounded, color: textPrimary, size: 16),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF4F46E5).withOpacity(0.2) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.edit_note_rounded,
              color: isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Journal & Reflections',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: textSecondary.withOpacity(0.35), size: 64),
          const SizedBox(height: 16),
          Text(
            'Your journal is empty',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Write down your reflections, sermon notes, \nand spiritual journey.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(
    JournalEntry entry,
    bool isDark,
    Color cardBg,
    Color border,
    Color textPrimary,
    Color textSecondary,
  ) {
    // Attempt to extract plain text from Quill JSON for preview
    String previewText = 'No content';
    try {
      final List<dynamic> ops = jsonDecode(entry.content);
      previewText = ops.map((op) => op['insert']?.toString() ?? '').join('').trim();
      if (previewText.isEmpty) previewText = 'Empty note';
    } catch (_) {}

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => JournalEditorScreen(entry: entry)),
        );
        if (result == true) {
          _loadEntries();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.title.isEmpty ? 'Untitled Reflection' : entry.title,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(entry.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: entry.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF4F46E5).withOpacity(0.18)
                        : const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF4F46E5).withOpacity(0.4)
                          : const Color(0xFFC7D2FE),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
