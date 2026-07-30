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
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
      body: Stack(
        children: [
          const CosmicBackground(children: []),
          Positioned(
            top: -40, left: -40,
            child: CosmicOrb(size: 260, color: const Color(0xFF3D5AFE), opacity: 0.07),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildTabSelector(),
                _buildSearchBar(),
                if (!_initialized || _loading)
                  Expanded(child: Center(child: CircularProgressIndicator(color: ImagoColors.gold)))
                else
                  Expanded(child: _buildWordList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Holy Lexicon & Dictionary',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
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
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
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
                    gradient: isSelected ? ImagoColors.violetGradient : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [BoxShadow(color: ImagoColors.violet.withOpacity(0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: Text(
                    tab['label']!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildSearchBar() {
    String hintText = 'Search terms...';
    if (_selectedType == 'greek') hintText = 'Search Greek, G26, or transliteration...';
    if (_selectedType == 'hebrew') hintText = 'Search Hebrew, H2617, or transliteration...';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: Colors.white, fontFamily: 'Poppins'),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.35), fontFamily: 'Poppins', fontSize: 13),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withOpacity(0.5)),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _runSearch('');
                    },
                    child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.5)),
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

  Widget _buildWordList() {
    if (_words.isEmpty) {
      return Center(
        child: Text(
          'No entries found.',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Colors.white.withOpacity(0.5),
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
        final definition = item['definition'] as String;
        
        return GestureDetector(
          onTap: () => _showDefinitionModal(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Row(
              children: [
                if (strongs != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: ImagoColors.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ImagoColors.gold.withOpacity(0.3)),
                    ),
                    child: Text(
                      strongs,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        term,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (translit != null || pron != null) ...[
                        SizedBox(height: 2),
                        Text(
                          [if (translit != null) translit, if (pron != null) '($pron)'].join(' '),
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: ImagoColors.cream.withOpacity(0.6),
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
                SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDefinitionModal(Map<String, dynamic> item) async {
    if (!mounted) return;

    final term = item['term'] as String;
    final strongs = item['strongs'] as String?;
    final translit = item['translit'] as String?;
    final pron = item['pron'] as String?;
    final definition = item['definition'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0E0B24),
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
                              color: ImagoColors.gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: ImagoColors.gold.withOpacity(0.4)),
                            ),
                            child: Text(
                              strongs,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: ImagoColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            term.trim(),
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.cream,
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
                      SizedBox(height: 6),
                      Text(
                        'Transliteration: ${translit ?? ''} ${pron != null ? '($pron)' : ''}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: ImagoColors.gold.withOpacity(0.8),
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    SizedBox(height: 16),
                    if (simplifiedText != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: ImagoColors.gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ImagoColors.gold.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome, color: ImagoColors.gold, size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Simplified Explanation',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: ImagoColors.gold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              simplifiedText!,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
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
                    SizedBox(height: 24),
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
                                ? LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.1)])
                                : ImagoColors.violetGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isSimplifying)
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                isSimplifying ? 'Simplifying...' : 'Explain it Simply',
                                style: TextStyle(
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
                    SizedBox(height: 12),
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

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
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
                      color: ImagoColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      BibleService.instance.currentTranslation,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              if (verses.isEmpty)
                Text(
                  'Verse text not found in local database.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.5),
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
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14.5,
                        height: 1.6,
                      ),
                    ),
                  )).toList(),
                ),
              SizedBox(height: 16),
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
                              backgroundColor: ImagoColors.nebula,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.copy_rounded, color: ImagoColors.gold, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Copy Verse',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
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
              SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
