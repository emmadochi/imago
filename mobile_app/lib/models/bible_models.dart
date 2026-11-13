// lib/models/bible_models.dart
// Data models for the MySword Bible integration

class BibleTranslation {
  final String abbreviation;
  final String description;
  final String fileName;
  final String language;
  final String languageCategory;
  final String flagEmoji;
  final bool isBundled;
  final String downloadSize;
  final String remoteUrl;

  const BibleTranslation({
    required this.abbreviation,
    required this.description,
    required this.fileName,
    this.language = 'English',
    this.languageCategory = 'English',
    this.flagEmoji = '🇬🇧',
    this.isBundled = true,
    this.downloadSize = '',
    this.remoteUrl = '',
  });
}

class BibleBook {
  final int number; // 1-66
  final String name;
  final bool isOldTestament;

  const BibleBook({
    required this.number,
    required this.name,
    required this.isOldTestament,
  });
}

class BibleVerse {
  final int book;
  final int chapter;
  final int verse;
  final String text;
  final String bookName;

  const BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    required this.bookName,
  });

  String get reference => '$bookName $chapter:$verse';

  /// Cleans raw markup and tags from Bible verse text (MyBible tags, HTML tags, USFM tags)
  static String cleanText(String raw) {
    if (raw.isEmpty) return '';

    String s = raw;
    // 1. Remove footnotes, cross-references and their content (<RF>...<Rf>, <RF>...</RF>, <f>...</f>, <x>...</x>, etc.)
    s = s.replaceAll(RegExp(r'<RF[^>]*>[\s\S]*?(?:<\/[Rr][Ff]>|<[Rr][f]>)'), '');
    s = s.replaceAll(RegExp(r'<f[^>]*>[\s\S]*?<\/f>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<x[^>]*>[\s\S]*?<\/x>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<note[^>]*>[\s\S]*?<\/note>', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'<sup[^>]*>[\s\S]*?<\/sup>', caseSensitive: false), '');

    // 2. Convert break and paragraph tags to line breaks
    s = s.replaceAll(RegExp(r'<\/?(?:br|pb|p|P)[\s\/]*>'), '\n');
    s = s.replaceAll(RegExp(r'<\/?(?:CI|PI)[0-9]*>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<\/t>', caseSensitive: false), '\n');
    s = s.replaceAll(RegExp(r'<t>', caseSensitive: false), '');

    // 3. Remove all remaining angle bracket tags (<FO>, <FI>, <i>, <b>, <e>, <J>, etc.)
    // Note: KJV+ Strong's numbers [G1234] and [H1234] use square brackets, so they are preserved
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');

    // 4. Remove MySword / KJV curly-bracket margin notes and Hebrew/Greek cross notes (e.g. "{by...: Heb. of the bow}", "{weep...: Heb. be bitter}")
    s = s.replaceAll(RegExp(r'\{[^{}]*(?:Heb|Grk|Greek|Hebrew|or|i\.e\.|that is|meaning|see|Lit|margin|MS)[\.\:][^{}]*\}', caseSensitive: false), '');
    // Remove isolated footnote markers inside curly brackets like {1}, {a}, {*}
    s = s.replaceAll(RegExp(r'\{[0-9a-zA-Z*#†‡§]{1,3}\}'), '');
    // Unwrap supplied translation words in curly braces e.g. "{men are}" -> "men are"
    s = s.replaceAllMapped(RegExp(r'\{([^{}]+)\}'), (m) => m.group(1) ?? '');

    // 5. Normalize spaces and newlines
    s = s.replaceAll(RegExp(r'[ \t\f\v]+'), ' ');
    s = s.replaceAll(RegExp(r'[ \t]*\n+[ \t]*'), '\n');
    return s.trim();
  }
}

// All 66 Bible books in canonical order
const List<BibleBook> kBibleBooks = [
  // Old Testament
  BibleBook(number: 1,  name: 'Genesis',          isOldTestament: true),
  BibleBook(number: 2,  name: 'Exodus',            isOldTestament: true),
  BibleBook(number: 3,  name: 'Leviticus',         isOldTestament: true),
  BibleBook(number: 4,  name: 'Numbers',           isOldTestament: true),
  BibleBook(number: 5,  name: 'Deuteronomy',       isOldTestament: true),
  BibleBook(number: 6,  name: 'Joshua',            isOldTestament: true),
  BibleBook(number: 7,  name: 'Judges',            isOldTestament: true),
  BibleBook(number: 8,  name: 'Ruth',              isOldTestament: true),
  BibleBook(number: 9,  name: '1 Samuel',          isOldTestament: true),
  BibleBook(number: 10, name: '2 Samuel',          isOldTestament: true),
  BibleBook(number: 11, name: '1 Kings',           isOldTestament: true),
  BibleBook(number: 12, name: '2 Kings',           isOldTestament: true),
  BibleBook(number: 13, name: '1 Chronicles',      isOldTestament: true),
  BibleBook(number: 14, name: '2 Chronicles',      isOldTestament: true),
  BibleBook(number: 15, name: 'Ezra',              isOldTestament: true),
  BibleBook(number: 16, name: 'Nehemiah',          isOldTestament: true),
  BibleBook(number: 17, name: 'Esther',            isOldTestament: true),
  BibleBook(number: 18, name: 'Job',               isOldTestament: true),
  BibleBook(number: 19, name: 'Psalms',            isOldTestament: true),
  BibleBook(number: 20, name: 'Proverbs',          isOldTestament: true),
  BibleBook(number: 21, name: 'Ecclesiastes',      isOldTestament: true),
  BibleBook(number: 22, name: 'Song of Solomon',   isOldTestament: true),
  BibleBook(number: 23, name: 'Isaiah',            isOldTestament: true),
  BibleBook(number: 24, name: 'Jeremiah',          isOldTestament: true),
  BibleBook(number: 25, name: 'Lamentations',      isOldTestament: true),
  BibleBook(number: 26, name: 'Ezekiel',           isOldTestament: true),
  BibleBook(number: 27, name: 'Daniel',            isOldTestament: true),
  BibleBook(number: 28, name: 'Hosea',             isOldTestament: true),
  BibleBook(number: 29, name: 'Joel',              isOldTestament: true),
  BibleBook(number: 30, name: 'Amos',              isOldTestament: true),
  BibleBook(number: 31, name: 'Obadiah',           isOldTestament: true),
  BibleBook(number: 32, name: 'Jonah',             isOldTestament: true),
  BibleBook(number: 33, name: 'Micah',             isOldTestament: true),
  BibleBook(number: 34, name: 'Nahum',             isOldTestament: true),
  BibleBook(number: 35, name: 'Habakkuk',          isOldTestament: true),
  BibleBook(number: 36, name: 'Zephaniah',         isOldTestament: true),
  BibleBook(number: 37, name: 'Haggai',            isOldTestament: true),
  BibleBook(number: 38, name: 'Zechariah',         isOldTestament: true),
  BibleBook(number: 39, name: 'Malachi',           isOldTestament: true),
  // New Testament
  BibleBook(number: 40, name: 'Matthew',           isOldTestament: false),
  BibleBook(number: 41, name: 'Mark',              isOldTestament: false),
  BibleBook(number: 42, name: 'Luke',              isOldTestament: false),
  BibleBook(number: 43, name: 'John',              isOldTestament: false),
  BibleBook(number: 44, name: 'Acts',              isOldTestament: false),
  BibleBook(number: 45, name: 'Romans',            isOldTestament: false),
  BibleBook(number: 46, name: '1 Corinthians',     isOldTestament: false),
  BibleBook(number: 47, name: '2 Corinthians',     isOldTestament: false),
  BibleBook(number: 48, name: 'Galatians',         isOldTestament: false),
  BibleBook(number: 49, name: 'Ephesians',         isOldTestament: false),
  BibleBook(number: 50, name: 'Philippians',       isOldTestament: false),
  BibleBook(number: 51, name: 'Colossians',        isOldTestament: false),
  BibleBook(number: 52, name: '1 Thessalonians',   isOldTestament: false),
  BibleBook(number: 53, name: '2 Thessalonians',   isOldTestament: false),
  BibleBook(number: 54, name: '1 Timothy',         isOldTestament: false),
  BibleBook(number: 55, name: '2 Timothy',         isOldTestament: false),
  BibleBook(number: 56, name: 'Titus',             isOldTestament: false),
  BibleBook(number: 57, name: 'Philemon',          isOldTestament: false),
  BibleBook(number: 58, name: 'Hebrews',           isOldTestament: false),
  BibleBook(number: 59, name: 'James',             isOldTestament: false),
  BibleBook(number: 60, name: '1 Peter',           isOldTestament: false),
  BibleBook(number: 61, name: '2 Peter',           isOldTestament: false),
  BibleBook(number: 62, name: '1 John',            isOldTestament: false),
  BibleBook(number: 63, name: '2 John',            isOldTestament: false),
  BibleBook(number: 64, name: '3 John',            isOldTestament: false),
  BibleBook(number: 65, name: 'Jude',              isOldTestament: false),
  BibleBook(number: 66, name: 'Revelation',        isOldTestament: false),
];

/// Canonical chapter counts for all 66 books of the Bible
const Map<int, int> kStandardBookChapterCounts = {
  1: 50,  // Genesis
  2: 40,  // Exodus
  3: 27,  // Leviticus
  4: 36,  // Numbers
  5: 34,  // Deuteronomy
  6: 24,  // Joshua
  7: 21,  // Judges
  8: 4,   // Ruth
  9: 31,  // 1 Samuel
  10: 24, // 2 Samuel
  11: 22, // 1 Kings
  12: 25, // 2 Kings
  13: 29, // 1 Chronicles
  14: 36, // 2 Chronicles
  15: 10, // Ezra
  16: 13, // Nehemiah
  17: 10, // Esther
  18: 42, // Job
  19: 150,// Psalms
  20: 31, // Proverbs
  21: 12, // Ecclesiastes
  22: 8,  // Song of Solomon
  23: 66, // Isaiah
  24: 52, // Jeremiah
  25: 5,  // Lamentations
  26: 48, // Ezekiel
  27: 12, // Daniel
  28: 14, // Hosea
  29: 3,  // Joel
  30: 9,  // Amos
  31: 1,  // Obadiah
  32: 4,  // Jonah
  33: 7,  // Micah
  34: 3,  // Nahum
  35: 3,  // Habakkuk
  36: 3,  // Zephaniah
  37: 2,  // Haggai
  38: 14, // Zechariah
  39: 4,  // Malachi
  40: 28, // Matthew
  41: 16, // Mark
  42: 24, // Luke
  43: 21, // John
  44: 28, // Acts
  45: 16, // Romans
  46: 16, // 1 Corinthians
  47: 13, // 2 Corinthians
  48: 6,  // Galatians
  49: 6,  // Ephesians
  50: 4,  // Philippians
  51: 4,  // Colossians
  52: 5,  // 1 Thessalonians
  53: 3,  // 2 Thessalonians
  54: 6,  // 1 Timothy
  55: 4,  // 2 Timothy
  56: 3,  // Titus
  57: 1,  // Philemon
  58: 13, // Hebrews
  59: 5,  // James
  60: 5,  // 1 Peter
  61: 3,  // 2 Peter
  62: 5,  // 1 John
  63: 1,  // 2 John
  64: 1,  // 3 John
  65: 1,  // Jude
  66: 22, // Revelation
};


// Available translations bundled or downloadable on-demand
const List<BibleTranslation> kBibleTranslations = [
  // --- Bundled English Core Translations ---
  BibleTranslation(
    abbreviation: 'KJV',
    description: 'King James Version',
    fileName: 'KJV.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'KJV+',
    description: 'King James Version (Interlinear & Concordance)',
    fileName: 'KJV+.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'NIV',
    description: 'New International Version',
    fileName: 'NIV.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'AMP',
    description: 'Amplified Bible',
    fileName: 'AMP.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'MSG',
    description: 'The Message (MSG)',
    fileName: 'MSG.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'BSB',
    description: 'Berean Standard Bible',
    fileName: 'BSB.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'ASV',
    description: 'American Standard Version',
    fileName: 'ASV.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'NCV',
    description: 'New Century Version',
    fileName: 'NCV.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'TLB',
    description: 'The Living Bible',
    fileName: 'TLB.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'ERV',
    description: 'Easy-to-Read Version',
    fileName: 'ERV.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'TPT',
    description: 'The Passion Translation',
    fileName: 'TPT.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇺🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'GNB',
    description: 'Good News Bible (GNB/GNT)',
    fileName: 'GNB.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'YLT',
    description: "Young's Literal Translation",
    fileName: 'YLT.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'JMNT',
    description: 'Jonathan Mitchell New Testament',
    fileName: 'JMNT.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'EASY',
    description: 'Easy English Bible',
    fileName: 'EasyEnglish.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'BBE',
    description: 'Bible in Basic English',
    fileName: 'BBE.bbl.mybible',
    language: 'English',
    languageCategory: 'English',
    flagEmoji: '🇬🇧',
    isBundled: true,
  ),

  // --- International Global Languages (AI & Offline Translation) ---
  BibleTranslation(
    abbreviation: 'LSG',
    description: 'La Bible Louis Segond (1910)',
    fileName: 'LSG.bbl.mybible',
    language: 'French',
    languageCategory: 'International Languages',
    flagEmoji: '🇫🇷',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'CUV',
    description: 'Chinese Union Version (聖經和合本)',
    fileName: 'CUV.bbl.mybible',
    language: 'Chinese',
    languageCategory: 'International Languages',
    flagEmoji: '🇨🇳',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'RVR',
    description: 'Biblia Reina-Valera (1909)',
    fileName: 'RVR.bbl.mybible',
    language: 'Spanish',
    languageCategory: 'International Languages',
    flagEmoji: '🇪🇸',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'JFA',
    description: 'Bíblia Sagrada João Ferreira de Almeida',
    fileName: 'JFA.bbl.mybible',
    language: 'Portuguese',
    languageCategory: 'International Languages',
    flagEmoji: '🇵🇹',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'LUT',
    description: 'Lutherbibel (1912)',
    fileName: 'LUT.bbl.mybible',
    language: 'German',
    languageCategory: 'International Languages',
    flagEmoji: '🇩🇪',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'SUV',
    description: 'Biblia Takatifu (Swahili)',
    fileName: 'SUV.bbl.mybible',
    language: 'Swahili',
    languageCategory: 'International Languages',
    flagEmoji: '🇰🇪',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'SVD',
    description: 'الكتاب المقدس (Smith & Van Dyck)',
    fileName: 'SVD.bbl.mybible',
    language: 'Arabic',
    languageCategory: 'International Languages',
    flagEmoji: '🇸🇦',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'KO',
    description: '한국어 성경 (Korean Bible)',
    fileName: 'KO.bbl.mybible',
    language: 'Korean',
    languageCategory: 'International Languages',
    flagEmoji: '🇰🇷',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'RU',
    description: 'Русская Синодальная Библия',
    fileName: 'RU.bbl.mybible',
    language: 'Russian',
    languageCategory: 'International Languages',
    flagEmoji: '🇷🇺',
    isBundled: true,
  ),

  // --- Nigerian & African Local Languages (Offline Native Databases) ---
  BibleTranslation(
    abbreviation: 'NPB',
    description: 'Nigerian Pidgin Bible',
    fileName: 'NPB.bbl.mybible',
    language: 'Nigerian Pidgin',
    languageCategory: 'Nigerian Languages',
    flagEmoji: '🇳🇬',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'IGBO',
    description: 'Igbo Bible (Baịbụl Nsọ)',
    fileName: 'IGBO.bbl.mybible',
    language: 'Igbo',
    languageCategory: 'Nigerian Languages',
    flagEmoji: '🇳🇬',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'YORUBA',
    description: 'Yoruba Bible (Bíbélì Mímọ́)',
    fileName: 'YORUBA.bbl.mybible',
    language: 'Yoruba',
    languageCategory: 'Nigerian Languages',
    flagEmoji: '🇳🇬',
    isBundled: true,
  ),
  BibleTranslation(
    abbreviation: 'HAUSA',
    description: 'Hausa Bible (Littafi Mai Tsarki)',
    fileName: 'HAUSA.bbl.mybible',
    language: 'Hausa',
    languageCategory: 'Nigerian Languages',
    flagEmoji: '🇳🇬',
    isBundled: true,
  ),
];

// --- Search Modes & MySword Biblical Groups ---

enum BibleSearchMatchType {
  exactPhrase, // Matches "kingdom of God" as a literal string
  allWords,    // Every word must be present in the verse (AND)
  anyWord,     // Any of the words must be present in the verse (OR)
}

extension BibleSearchMatchTypeExt on BibleSearchMatchType {
  String get label {
    switch (this) {
      case BibleSearchMatchType.exactPhrase:
        return 'Exact Phrase';
      case BibleSearchMatchType.allWords:
        return 'All Words';
      case BibleSearchMatchType.anyWord:
        return 'Any Word';
    }
  }

  String get description {
    switch (this) {
      case BibleSearchMatchType.exactPhrase:
        return 'Matches exact phrase in order';
      case BibleSearchMatchType.allWords:
        return 'All words must appear';
      case BibleSearchMatchType.anyWord:
        return 'Any word may appear';
    }
  }
}

class BibleSearchGroup {
  final String id;
  final String name;
  final String description;
  final List<int> bookNumbers;

  const BibleSearchGroup({
    required this.id,
    required this.name,
    required this.description,
    required this.bookNumbers,
  });
}

// Canonical MySword Bible Groups
final List<BibleSearchGroup> kBibleSearchGroups = [
  BibleSearchGroup(
    id: 'all',
    name: 'Entire Bible',
    description: 'All 66 Books (Genesis to Revelation)',
    bookNumbers: List.generate(66, (i) => i + 1),
  ),
  BibleSearchGroup(
    id: 'ot',
    name: 'Old Testament',
    description: '39 Books (Genesis to Malachi)',
    bookNumbers: List.generate(39, (i) => i + 1),
  ),
  BibleSearchGroup(
    id: 'nt',
    name: 'New Testament',
    description: '27 Books (Matthew to Revelation)',
    bookNumbers: List.generate(27, (i) => i + 40),
  ),
  BibleSearchGroup(
    id: 'law',
    name: 'Pentateuch / Law',
    description: '5 Books (Genesis to Deuteronomy)',
    bookNumbers: const [1, 2, 3, 4, 5],
  ),
  BibleSearchGroup(
    id: 'history_ot',
    name: 'Historical Books (OT)',
    description: '12 Books (Joshua to Esther)',
    bookNumbers: const [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
  ),
  BibleSearchGroup(
    id: 'poetry',
    name: 'Poetry & Wisdom',
    description: '5 Books (Job to Song of Solomon)',
    bookNumbers: const [18, 19, 20, 21, 22],
  ),
  BibleSearchGroup(
    id: 'major_prophets',
    name: 'Major Prophets',
    description: '5 Books (Isaiah to Daniel)',
    bookNumbers: const [23, 24, 25, 26, 27],
  ),
  BibleSearchGroup(
    id: 'minor_prophets',
    name: 'Minor Prophets',
    description: '12 Books (Hosea to Malachi)',
    bookNumbers: const [28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
  ),
  BibleSearchGroup(
    id: 'gospels',
    name: 'Gospels',
    description: '4 Books (Matthew to John)',
    bookNumbers: const [40, 41, 42, 43],
  ),
  BibleSearchGroup(
    id: 'acts',
    name: 'Acts / Church History',
    description: '1 Book (Acts of the Apostles)',
    bookNumbers: const [44],
  ),
  BibleSearchGroup(
    id: 'pauline',
    name: 'Pauline Epistles',
    description: '14 Books (Romans to Hebrews)',
    bookNumbers: const [45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58],
  ),
  BibleSearchGroup(
    id: 'general_epistles',
    name: 'General Epistles',
    description: '7 Books (James to Jude)',
    bookNumbers: const [59, 60, 61, 62, 63, 64, 65],
  ),
  BibleSearchGroup(
    id: 'revelation',
    name: 'Apocalyptic / Prophecy',
    description: '1 Book (Revelation)',
    bookNumbers: const [66],
  ),
];
