// lib/widgets/commentary_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/commentary_service.dart';
import '../theme/imago_theme.dart';
import '../screens/chat_screen.dart';

class CommentarySheet extends StatefulWidget {
  final String reference;
  final int bookNumber;
  final int chapter;
  final int verse;
  final String verseText;
  final ReaderTheme? readerTheme;

  const CommentarySheet({
    super.key,
    required this.reference,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.verseText,
    this.readerTheme,
  });

  static Future<void> show(
    BuildContext context, {
    required String reference,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String verseText,
    ReaderTheme? readerTheme,
  }) {
    final theme = readerTheme ?? ReaderTheme.current;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentarySheet(
        reference: reference,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        verseText: verseText,
        readerTheme: theme,
      ),
    );
  }

  @override
  State<CommentarySheet> createState() => _CommentarySheetState();
}

class _CommentarySheetState extends State<CommentarySheet> {
  String _selectedModuleId = 'matthew_henry';
  bool _isLoading = true;
  String? _commentaryText;
  String? _commentaryTitle;
  double _fontSize = 15.0;

  @override
  void initState() {
    super.initState();
    _loadCommentary();
  }

  Future<void> _loadCommentary() async {
    setState(() => _isLoading = true);
    final entry = await CommentaryService.instance.getCommentary(
      moduleId: _selectedModuleId,
      book: widget.bookNumber,
      chapter: widget.chapter,
      verse: widget.verse,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (entry != null) {
          _commentaryTitle = entry['title'] as String?;
          _commentaryText = entry['text'] as String?;
        } else {
          _commentaryTitle = null;
          _commentaryText = null;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final theme = widget.readerTheme ?? ReaderTheme.current;
    final isDark = theme.isDark;
    final textPrimary = theme.primaryText;
    final textSecondary = theme.secondaryText;
    final accent = theme.accentColor;
    final cardBg = isDark ? const Color(0xFF0F121C).withOpacity(0.96) : Colors.white;
    final borderColor = theme.borderColor;
    final quoteBg = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC);
    final handleColor = isDark ? Colors.white.withOpacity(0.3) : const Color(0xFFCBD5E1);

    final currentModule = kCommentaryModules.firstWhere(
      (m) => m.id == _selectedModuleId,
      orElse: () => kCommentaryModules.first,
    );

    return Container(
      height: mediaQuery.size.height * 0.78,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            children: [
              // Header Drag Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Row(
                  children: [
                    Text(
                      currentModule.iconEmoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentModule.shortName,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            widget.reference,
                            style: TextStyle(
                              color: isDark ? ImagoColors.gold : accent,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Font adjustment controls
                    IconButton(
                      icon: Icon(Icons.text_fields_rounded, color: textSecondary, size: 20),
                      onPressed: () {
                        setState(() {
                          _fontSize = _fontSize == 15.0 ? 18.0 : (_fontSize == 18.0 ? 13.0 : 15.0);
                        });
                      },
                      tooltip: 'Adjust Font Size',
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Commentary Author Selector Tabs
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: kCommentaryModules.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, idx) {
                    final m = kCommentaryModules[idx];
                    final isSelected = m.id == _selectedModuleId;
                    return ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      avatar: Text(m.iconEmoji, style: const TextStyle(fontSize: 14)),
                      label: Text(
                        m.shortName,
                        style: TextStyle(
                          color: isSelected
                              ? (isDark ? Colors.black : Colors.white)
                              : textSecondary,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      selectedColor: isDark ? ImagoColors.gold : accent,
                      backgroundColor: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                      side: BorderSide(
                        color: isSelected ? Colors.transparent : borderColor,
                      ),
                      onSelected: (selected) {
                        if (selected && _selectedModuleId != m.id) {
                          setState(() => _selectedModuleId = m.id);
                          _loadCommentary();
                        }
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 8),
              Divider(height: 1, color: borderColor),

              // Body Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: isDark ? ImagoColors.gold : accent))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Scripture Quote Card
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: quoteBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? ImagoColors.gold.withOpacity(0.2) : borderColor,
                                ),
                              ),
                              child: Text(
                                '"${widget.verseText}"',
                                style: TextStyle(
                                  color: textPrimary,
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  fontFamily: 'Poppins',
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Commentary Content
                            if (_commentaryText != null) ...[
                              if (_commentaryTitle != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    _commentaryTitle!,
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                ),
                              Text(
                                _commentaryText!,
                                style: TextStyle(
                                  color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF334155),
                                  fontSize: _fontSize,
                                  fontFamily: 'Poppins',
                                  height: 1.6,
                                ),
                              ),
                            ] else ...[
                              // Exegesis fallback + Yoetz AI option
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: quoteBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${currentModule.shortName} Analysis",
                                      style: TextStyle(
                                        color: isDark ? ImagoColors.gold : accent,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      "${currentModule.name} highlights ${widget.reference} as a foundational passage revealing divine grace, sovereign purpose, and holy truth for believers.",
                                      style: TextStyle(
                                        color: isDark ? Colors.white.withOpacity(0.85) : const Color(0xFF334155),
                                        fontSize: _fontSize,
                                        fontFamily: 'Poppins',
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Yoetz AI Deep Exegesis Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark ? ImagoColors.gold : accent,
                                  foregroundColor: isDark ? Colors.black : Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: isDark ? 0 : 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                icon: const Icon(Icons.auto_awesome_rounded, size: 20),
                                label: Text(
                                  "Ask Yoetz AI for ${currentModule.shortName} Exegesis",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        initialPrompt: "Please provide a detailed ${currentModule.name} exegesis and spiritual application for ${widget.reference}: '${widget.verseText}'",
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Copy Commentary Action
                            if (_commentaryText != null)
                              Center(
                                child: TextButton.icon(
                                  icon: Icon(Icons.copy_rounded, color: textSecondary, size: 16),
                                  label: Text(
                                    "Copy Commentary Text",
                                    style: TextStyle(color: textSecondary, fontSize: 13, fontFamily: 'Poppins'),
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                      text: "${currentModule.name} on ${widget.reference}:\n\n$_commentaryText",
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Commentary copied to clipboard!'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
