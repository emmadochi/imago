import 'package:flutter/material.dart';
import '../models/bible_models.dart';
import '../services/bible_service.dart';
import '../services/crossref_service.dart';
import '../theme/imago_theme.dart';

class CrossrefSheet extends StatefulWidget {
  final BibleVerse sourceVerse;
  final Function(int book, int chapter, int verse)? onJumpToVerse;

  final ReaderTheme? readerTheme;

  const CrossrefSheet({
    super.key,
    required this.sourceVerse,
    this.onJumpToVerse,
    this.readerTheme,
  });

  static Future<void> show({
    required BuildContext context,
    required BibleVerse sourceVerse,
    Function(int book, int chapter, int verse)? onJumpToVerse,
    ReaderTheme? readerTheme,
  }) {
    final theme = readerTheme ?? ReaderTheme.current;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => CrossrefSheet(
        sourceVerse: sourceVerse,
        onJumpToVerse: onJumpToVerse,
        readerTheme: theme,
      ),
    );
  }

  @override
  State<CrossrefSheet> createState() => _CrossrefSheetState();
}

class _CrossrefSheetState extends State<CrossrefSheet> {
  List<String> _targetRefs = [];
  bool _loading = true;
  final Map<String, List<BibleVerse>> _previewCache = {};

  @override
  void initState() {
    super.initState();
    _loadReferences();
  }

  Future<void> _loadReferences() async {
    final refs = await CrossrefService.instance.getCrossReferences(
      widget.sourceVerse.book,
      widget.sourceVerse.chapter,
      widget.sourceVerse.verse,
    );
    if (!mounted) return;

    setState(() {
      _targetRefs = refs;
      _loading = false;
    });

    // Pre-fetch verse texts for the top 15 references
    for (final r in refs.take(15)) {
      final verses = await BibleService.instance.getVerseByReference(r);
      if (mounted) {
        setState(() {
          _previewCache[r] = verses;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme ?? ReaderTheme.current;
    final isDark = theme.isDark;
    final textPrimary = theme.primaryText;
    final textSecondary = theme.secondaryText;
    final accent = theme.accentColor;
    final cardBg = isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC);
    final borderColor = theme.borderColor;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TSK Cross References',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? ImagoColors.gold : accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.sourceVerse.reference,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Icon(Icons.close_rounded, color: textPrimary, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: accent)),
            )
          else if (_targetRefs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No cross references found for this verse.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _targetRefs.length,
                itemBuilder: (ctx, i) {
                  final ref = _targetRefs[i];
                  final verses = _previewCache[ref];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ref,
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                color: isDark ? ImagoColors.gold : accent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (verses != null && verses.isNotEmpty && widget.onJumpToVerse != null)
                              GestureDetector(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onJumpToVerse!(
                                    verses.first.book,
                                    verses.first.chapter,
                                    verses.first.verse,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Jump',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.north_east_rounded, color: Colors.white, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (verses == null)
                          FutureBuilder<List<BibleVerse>>(
                            future: BibleService.instance.getVerseByReference(ref),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return SizedBox(
                                  height: 20,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        color: accent.withOpacity(0.5),
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final list = snapshot.data!;
                              if (list.isEmpty) {
                                return Text(
                                  'Verse text unavailable',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: textSecondary.withOpacity(0.6),
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                );
                              }
                              return _buildVerseText(list, textPrimary);
                            },
                          )
                        else
                          _buildVerseText(verses, textPrimary),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerseText(List<BibleVerse> verses, Color textColor) {
    final fullText = verses.map((v) => '${v.verse}. ${v.text}').join(' ');
    return SelectableText(
      fullText,
      style: TextStyle(
        fontFamily: 'Poppins',
        color: textColor,
        fontSize: 13.5,
        height: 1.5,
      ),
    );
  }
}
