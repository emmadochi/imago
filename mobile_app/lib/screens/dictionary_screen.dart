import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/dictionary_service.dart';
import '../services/bible_service.dart';
import '../widgets/formatted_definition_text.dart';
import '../widgets/audio_speaker_button.dart';
import '../theme/imago_theme.dart';

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _words = [];
  bool _loading = false;
  bool _initialized = false;
  String _selectedType = 'easton'; // 'easton', 'greek', 'hebrew'

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _loading = true);
    await DictionaryService.instance.init();
    await _loadCategory(_selectedType);
    setState(() {
      _initialized = true;
    });
  }

  Future<void> _loadCategory(String type) async {
    setState(() {
      _selectedType = type;
      _loading = true;
    });
    final words = await DictionaryService.instance.getWords(type: type);
    setState(() {
      _words = words;
      _loading = false;
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _loading = true);
    final results = await DictionaryService.instance.searchWords(query, type: _selectedType);
    setState(() {
      _words = results;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              Positioned(
                top: -40, left: -40,
                child: CosmicOrb(size: 260, color: ImagoColors.violet, opacity: isDark ? 0.07 : 0.03),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _buildHeader(isDark, cardBg, border, textPrimary),
                    _buildTabSelector(isDark, cardBg, border, textSecondary),
                    _buildSearchBar(isDark, cardBg, border, textPrimary, textSecondary),
                    if (!_initialized || _loading)
                      Expanded(child: Center(child: CircularProgressIndicator(color: accent)))
                    else
                      Expanded(child: _buildWordList(isDark, cardBg, border, textPrimary, textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, Color cardBg, Color border, Color textPrimary) {
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
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          if (canPop) ...[
            GestureDetector(
              onTap: () => Navigator.pop(context),
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
              Icons.auto_stories_rounded,
              color: isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Holy Lexicon & Dictionary',
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector(bool isDark, Color cardBg, Color border, Color textSecondary) {
    final tabs = [
      {'id': 'easton', 'label': 'Theological'},
      {'id': 'greek', 'label': 'Greek NT'},
      {'id': 'hebrew', 'label': 'Hebrew OT'},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131D33) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Row(
          children: tabs.map((tab) {
            final isSelected = _selectedType == tab['id'];
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_selectedType != tab['id']) {
                    _searchController.clear();
                    _loadCategory(tab['id']!);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? const Color(0xFF4F46E5) : const Color(0xFF4F46E5))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF4F46E5).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    tab['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isSelected ? Colors.white : textSecondary,
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, Color cardBg, Color border, Color textPrimary, Color textSecondary) {
    String hintText = 'Search terms...';
    if (_selectedType == 'greek') hintText = 'Search Greek, G26, or transliteration...';
    if (_selectedType == 'hebrew') hintText = 'Search Hebrew, H2617, or transliteration...';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textPrimary, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: textSecondary.withOpacity(0.7), fontFamily: 'Poppins', fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _runSearch('');
                    },
                    child: Icon(Icons.close_rounded, color: textSecondary),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onChanged: (q) {
            _runSearch(q);
          },
        ),
      ),
    );
  }

  Widget _buildWordList(bool isDark, Color cardBg, Color border, Color textPrimary, Color textSecondary) {
    if (_words.isEmpty) {
      return Center(
        child: Text(
          'No entries found.',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: textSecondary,
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _words.length,
      itemBuilder: (ctx, i) {
        final item = _words[i];
        final term = item['term'] as String;
        final strongs = item['strongs'] as String?;
        final translit = item['translit'] as String?;
        final pron = item['pron'] as String?;
        
        return GestureDetector(
          onTap: () => _showDefinitionModal(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
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
                if (strongs != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFFFC857).withOpacity(0.15)
                          : const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFFFC857).withOpacity(0.3)
                            : const Color(0xFFC7D2FE),
                      ),
                    ),
                    child: Text(
                      strongs,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        term,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (translit != null || pron != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          [if (translit != null) translit, if (pron != null) '($pron)'].join(' '),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: textSecondary,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AudioSpeakerButton(
                  term: term,
                  translit: translit,
                  pron: pron,
                  type: item['type'] as String? ?? _selectedType,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textSecondary.withOpacity(0.6), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDefinitionModal(Map<String, dynamic> item) async {
    if (!mounted) return;

    final isDark = ImagoColors.isDark;
    final modalBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accentGold = isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706);

    final term = item['term'] as String;
    final strongs = item['strongs'] as String?;
    final translit = item['translit'] as String?;
    final pron = item['pron'] as String?;
    final definition = item['definition'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        bool isSimplifying = false;
        String? simplifiedText;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (strongs != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFFFC857).withOpacity(0.2)
                                  : const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFFFC857).withOpacity(0.4)
                                    : const Color(0xFFC7D2FE),
                              ),
                            ),
                            child: Text(
                              strongs,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            term.trim(),
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        AudioSpeakerButton(
                          term: term,
                          translit: translit,
                          pron: pron,
                          type: item['type'] as String? ?? _selectedType,
                          size: 20,
                        ),
                      ],
                    ),
                    if (translit != null || pron != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Transliteration: ${translit ?? ''} ${pron != null ? '($pron)' : ''}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: accentGold,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (simplifiedText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFFFC857).withOpacity(0.1)
                              : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFFFFC857).withOpacity(0.3)
                                : const Color(0xFFFDE68A),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: accentGold, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Simplified Explanation',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: accentGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              simplifiedText!,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: textPrimary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      FormattedDefinitionText(
                        text: definition,
                        onVerseTap: (ref) => _showVersePreview(ref),
                      ),
                    const SizedBox(height: 24),
                    if (simplifiedText == null)
                      GestureDetector(
                        onTap: isSimplifying
                            ? null
                            : () async {
                                setModalState(() {
                                  isSimplifying = true;
                                });
                                final simple = await DictionaryService.instance.simplifyConcept(term, definition);
                                setModalState(() {
                                  isSimplifying = false;
                                  simplifiedText = simple;
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSimplifying
                                ? LinearGradient(colors: [cardBg, cardBg])
                                : ImagoColors.violetGradient,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSimplifying)
                                const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                isSimplifying ? 'Simplifying...' : 'Explain it Simply',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showVersePreview(String rawRef) async {
    final normalized = FormattedDefinitionText.normalizeReference(rawRef);
    final verses = await BibleService.instance.getVerseByReference(normalized);

    if (!mounted) return;

    final isDark = ImagoColors.isDark;
    final modalBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
    final accentGold = isDark ? const Color(0xFFFFC857) : const Color(0xFFD97706);

    showModalBottomSheet(
      context: context,
      backgroundColor: modalBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rawRef.trim(),
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: accentGold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: Text(
                      BibleService.instance.currentTranslation,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (verses.isEmpty)
                Text(
                  'Verse text not found in local database.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: verses.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SelectableText(
                      '${v.verse}. ${v.text}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: textPrimary,
                        fontSize: 14.5,
                        height: 1.6,
                      ),
                    ),
                  )).toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (verses.isNotEmpty) {
                          final fullText = verses.map((v) => '${v.verse}. ${v.text}').join('\n');
                          Clipboard.setData(ClipboardData(text: '$fullText — $rawRef (${BibleService.instance.currentTranslation})'));
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$rawRef copied!'),
                              backgroundColor: const Color(0xFF4F46E5),
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: border),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy_rounded, color: accentGold, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Copy Verse',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
