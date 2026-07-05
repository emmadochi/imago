// lib/models/bible_models.dart
// Data models for the MySword Bible integration

class BibleTranslation {
  final String abbreviation;
  final String description;
  final String fileName;

  const BibleTranslation({
    required this.abbreviation,
    required this.description,
    required this.fileName,
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

// Available translations bundled with the app
const List<BibleTranslation> kBibleTranslations = [
  BibleTranslation(abbreviation: 'KJV', description: 'King James Version',    fileName: 'KJV.bbl.mybible'),
  BibleTranslation(abbreviation: 'BBE', description: 'Bible in Basic English',   fileName: 'BBE.bbl.mybible'),
  BibleTranslation(abbreviation: 'BSB', description: 'Berean Standard Bible', fileName: 'BSB.bbl.mybible'),
];
