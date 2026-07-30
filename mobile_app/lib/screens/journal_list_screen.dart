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
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
      body: Stack(
        children: [
          const CosmicBackground(children: []),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAppBar(),
                Expanded(
                  child: _isLoading
                      ? Center(child: CircularProgressIndicator(color: ImagoColors.gold))
                      : _entries.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              itemCount: _entries.length,
                              itemBuilder: (ctx, i) => _buildJournalCard(_entries[i]),
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3D5AFE),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const JournalEditorScreen()),
          );
          if (result == true) {
            _loadEntries();
          }
        },
        child: Icon(Icons.edit_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: 8),
          Text(
            'Journal & Notes',
            style: TextStyle(
              fontFamily: 'Cinzel',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ImagoColors.cream,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: Colors.white.withOpacity(0.2), size: 60),
          SizedBox(height: 16),
          Text(
            'Your journal is empty',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: Colors.white.withOpacity(0.8),
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Write down your reflections, sermon notes, '
            'and spiritual journey.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(JournalEntry entry) {
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
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.title.isEmpty ? 'Untitled' : entry.title,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(entry.updatedAt),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            if (entry.tags.isNotEmpty) ...[
              SizedBox(height: 12),
              Wrap(
                spacing: 6,
                children: entry.tags.map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF5C6BC0),
                      fontSize: 10,
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
