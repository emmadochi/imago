// lib/services/bible_service.dart
// Singleton service for reading MySword .bbl.mybible SQLite databases

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible_models.dart';
import '../data/topical_index.dart';

class BibleService {
  BibleService._();
  static final BibleService instance = BibleService._();

  final Map<String, Database> _dbs = {};
  String _currentTranslation = 'KJV';

  String get currentTranslation => _currentTranslation;

  BibleTranslation get currentTranslationInfo => kBibleTranslations.firstWhere(
        (t) => t.abbreviation == _currentTranslation,
        orElse: () => kBibleTranslations.first,
      );

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTranslation = prefs.getString('bible_translation') ?? 'KJV';
    
    // Ensure the saved translation actually exists in our models (fixes crash if a translation was removed)
    if (kBibleTranslations.any((t) => t.abbreviation == savedTranslation)) {
      _currentTranslation = savedTranslation;
    } else {
      _currentTranslation = 'KJV';
      await prefs.setString('bible_translation', 'KJV');
    }

    // Pre-copy all translation DBs so switching is instant
    for (final t in kBibleTranslations) {
      await _getDb(t.abbreviation);
    }

    // Ensure the saved translation actually loaded successfully (fixes silent fallback bug)
    if (!isTranslationAvailable(_currentTranslation)) {
      _currentTranslation = 'KJV';
      await prefs.setString('bible_translation', 'KJV');
    }
  }

  Future<void> setTranslation(String abbreviation) async {
    _currentTranslation = abbreviation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bible_translation', abbreviation);
  }

  bool isTranslationAvailable(String abbreviation) {
    return _dbs.containsKey(abbreviation);
  }

  Future<Database> _getDb(String abbreviation) async {
    if (_dbs.containsKey(abbreviation)) return _dbs[abbreviation]!;

    try {
      final translation = kBibleTranslations.firstWhere((t) => t.abbreviation == abbreviation);
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = join(dir.path, 'bible', translation.fileName);
      
      final prefs = await SharedPreferences.getInstance();
      final int cachedVersion = prefs.getInt('db_version_$abbreviation') ?? 0;
      const int currentDbVersion = 7; // Bumped to 7 to load new ASV and EasyEnglish

      // Copy from assets if not already on disk OR if it's an older version
      if (!File(dbPath).existsSync() || cachedVersion < currentDbVersion) {
        await Directory(join(dir.path, 'bible')).create(recursive: true);
        final bytes = await rootBundle.load('assets/bible/${translation.fileName}');
        await File(dbPath).writeAsBytes(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), 
          flush: true
        );
        await prefs.setInt('db_version_$abbreviation', currentDbVersion);
      }

      final db = await openDatabase(dbPath, readOnly: true);
      _dbs[abbreviation] = db;
      return db;
    } catch (e) {
      if (abbreviation != 'KJV') {
        print("WARNING: Could not load Bible translation '$abbreviation'. Falling back to KJV. Error: $e");
        return await _getDb('KJV');
      }
      rethrow;
    }
  }

  Future<bool> _isMySwordFormat(Database db) async {
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Bible'"
    );
    return result.isNotEmpty;
  }

  /// Returns all chapter counts for a given book number (1-based).
  Future<int> getChapterCount(int bookNumber) async {
    final db = await _getDb(_currentTranslation);
    final isMySword = await _isMySwordFormat(db);
    final table = isMySword ? 'Bible' : 'verses';
    final colChapter = isMySword ? 'Chapter' : 'chapter';
    final colBook = isMySword ? 'Book' : 'book';

    final result = await db.rawQuery(
      'SELECT MAX($colChapter) as max_chapter FROM $table WHERE $colBook = ?',
      [bookNumber],
    );
    return (result.first['max_chapter'] as int?) ?? 0;
  }

  /// Returns verse count for a given book + chapter.
  Future<int> getVerseCount(int bookNumber, int chapter) async {
    final db = await _getDb(_currentTranslation);
    final isMySword = await _isMySwordFormat(db);
    final table = isMySword ? 'Bible' : 'verses';
    final colChapter = isMySword ? 'Chapter' : 'chapter';
    final colBook = isMySword ? 'Book' : 'book';
    final colVerse = isMySword ? 'Verse' : 'verse';

    final result = await db.rawQuery(
      'SELECT MAX($colVerse) as max_verse FROM $table WHERE $colBook = ? AND $colChapter = ?',
      [bookNumber, chapter],
    );
    return (result.first['max_verse'] as int?) ?? 0;
  }

  /// Returns all verses for a given book + chapter.
  Future<List<BibleVerse>> getVerses(int bookNumber, int chapter, {String? translationAbbreviation}) async {
    final trans = translationAbbreviation ?? _currentTranslation;
    final Map<String, String> localLangs = {
      'NPB': 'Pidgin',
      'IGBO': 'Igbo',
      'HAUSA': 'Hausa',
      'YORUBA': 'Yoruba',
    };

    final String baseTrans = localLangs.containsKey(trans) ? 'KJV' : trans;
    final db = await _getDb(baseTrans);
    final isMySword = await _isMySwordFormat(db);
    final table = isMySword ? 'Bible' : 'verses';
    final colChapter = isMySword ? 'Chapter' : 'chapter';
    final colBook = isMySword ? 'Book' : 'book';
    final colVerse = isMySword ? 'Verse' : 'verse';
    final colScripture = isMySword ? 'Scripture' : 'text';

    final bookName = kBibleBooks.firstWhere((b) => b.number == bookNumber).name;
    final rows = await db.rawQuery(
      'SELECT $colVerse as v, $colScripture as s FROM $table WHERE $colBook = ? AND $colChapter = ? ORDER BY $colVerse',
      [bookNumber, chapter],
    );

    List<BibleVerse> baseVerses = rows
        .map((r) => BibleVerse(
              book: bookNumber,
              chapter: chapter,
              verse: r['v'] as int,
              text: (r['s'] as String).trim(),
              bookName: bookName,
            ))
        .toList();

    if (localLangs.containsKey(trans) && baseVerses.isNotEmpty) {
      try {
        final targetLang = localLangs[trans]!;
        final payload = {
          'book': bookName,
          'chapter': chapter,
          'language': targetLang,
          'verses': baseVerses.map((v) => {'verse': v.verse, 'text': v.text}).toList(),
        };

        final res = await http.post(
          Uri.parse('https://imago-1-wkzl.onrender.com/api/bible/translate'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        ).timeout(const Duration(seconds: 25));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'success' && data['verses'] != null) {
            final List<dynamic> translatedList = data['verses'];
            final Map<int, String> transMap = {
              for (var item in translatedList) (item['verse'] as int): (item['text'] as String)
            };
            return baseVerses.map((v) {
              return BibleVerse(
                book: v.book,
                chapter: v.chapter,
                verse: v.verse,
                text: transMap[v.verse] ?? v.text,
                bookName: v.bookName,
              );
            }).toList();
          }
        }
      } catch (e) {
        print("WARNING: Bible local translation error for $trans: $e");
      }
    }

    return baseVerses;
  }

  /// Full-text search across all verses.
  Future<List<BibleVerse>> search(String query, {int limit = 100}) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    
    // 1. Fetch topical matches first
    final List<BibleVerse> topicalMatches = [];
    final lowerQuery = q.toLowerCase();
    
    if (kTopicalIndex.containsKey(lowerQuery)) {
      final references = kTopicalIndex[lowerQuery]!;
      for (final ref in references) {
        final verses = await getVerseByReference(ref);
        topicalMatches.addAll(verses);
      }
    }

    // 2. Check if this is a Strong's Number Concordance search
    final isStrongsSearch = RegExp(r'^[GH]\d+$', caseSensitive: false).hasMatch(q);
    
    Database db;
    String table, colChapter, colBook, colVerse, colScripture;
    bool isMySword;

    List<Map<String, Object?>> rows = [];

    if (isStrongsSearch) {
      // Concordance search: query KJV+ which contains the Strong's tags [G26]
      final upperQuery = q.toUpperCase();
      final kjvDb = await _getDb('KJV+');
      final isKjvMySword = await _isMySwordFormat(kjvDb);
      final t = isKjvMySword ? 'Bible' : 'verses';
      final cB = isKjvMySword ? 'Book' : 'book';
      final cC = isKjvMySword ? 'Chapter' : 'chapter';
      final cV = isKjvMySword ? 'Verse' : 'verse';
      final cS = isKjvMySword ? 'Scripture' : 'text';

      // Find references in KJV+
      final kjvRows = await kjvDb.rawQuery(
        'SELECT $cB as b, $cC as c, $cV as v, $cS as s FROM $t WHERE $cS LIKE ? ORDER BY $cB, $cC, $cV LIMIT ?',
        ['%[$upperQuery]%', limit],
      );

      if (_currentTranslation == 'KJV+') {
        rows = kjvRows;
        db = kjvDb;
      } else {
        // We have the coordinates, now fetch the text in the user's current translation
        db = await _getDb(_currentTranslation);
        isMySword = await _isMySwordFormat(db);
        table = isMySword ? 'Bible' : 'verses';
        colChapter = isMySword ? 'Chapter' : 'chapter';
        colBook = isMySword ? 'Book' : 'book';
        colVerse = isMySword ? 'Verse' : 'verse';
        colScripture = isMySword ? 'Scripture' : 'text';

        for (final r in kjvRows) {
          final translatedRow = await db.rawQuery(
            'SELECT $colBook as b, $colChapter as c, $colVerse as v, $colScripture as s FROM $table WHERE $colBook = ? AND $colChapter = ? AND $colVerse = ? LIMIT 1',
            [r['b'], r['c'], r['v']],
          );
          if (translatedRow.isNotEmpty) {
            rows.add(translatedRow.first);
          }
        }
      }
    } else {
      // Standard full text search
      db = await _getDb(_currentTranslation);
      isMySword = await _isMySwordFormat(db);
      table = isMySword ? 'Bible' : 'verses';
      colChapter = isMySword ? 'Chapter' : 'chapter';
      colBook = isMySword ? 'Book' : 'book';
      colVerse = isMySword ? 'Verse' : 'verse';
      colScripture = isMySword ? 'Scripture' : 'text';

      rows = await db.rawQuery(
        'SELECT $colBook as b, $colChapter as c, $colVerse as v, $colScripture as s FROM $table WHERE $colScripture LIKE ? ORDER BY $colBook, $colChapter, $colVerse LIMIT ?',
        ['%$q%', limit],
      );
    }
    
    final fullTextMatches = rows.map((r) {
      final bookNum = r['b'] as int;
      final bookName = bookNum >= 1 && bookNum <= 66
          ? kBibleBooks.firstWhere((b) => b.number == bookNum).name
          : 'Unknown';
      return BibleVerse(
        book: bookNum,
        chapter: r['c'] as int,
        verse: r['v'] as int,
        text: (r['s'] as String).trim(),
        bookName: bookName,
      );
    }).toList();
    
    // 3. Combine and deduplicate
    final Set<String> seenRefs = {};
    final List<BibleVerse> combinedResults = [];
    
    for (final v in topicalMatches) {
      if (seenRefs.add(v.reference)) {
        combinedResults.add(v);
      }
    }
    for (final v in fullTextMatches) {
      if (seenRefs.add(v.reference)) {
        combinedResults.add(v);
      }
    }
    
    return combinedResults;
  }

  /// Fetches verses based on a string reference like "John 3:16" or "1 Corinthians 13:4-8"
  Future<List<BibleVerse>> getVerseByReference(String reference) async {
    if (reference.trim().isEmpty) return [];
    
    // Sort books by name length descending to match "1 John" before "John"
    final booksList = List<BibleBook>.from(kBibleBooks)
      ..sort((a, b) => b.name.length.compareTo(a.name.length));

    for (final b in booksList) {
      final bookName = b.name;
      if (reference.toLowerCase().startsWith(bookName.toLowerCase())) {
        final remaining = reference.substring(bookName.length).trim();
        final match = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(remaining);
        if (match != null) {
          final chapter = int.tryParse(match.group(1)!);
          final startVerse = int.tryParse(match.group(2)!);
          final endVerse = match.group(3) != null ? int.tryParse(match.group(3)!) : startVerse;
          
          if (chapter != null && startVerse != null && endVerse != null) {
            final db = await _getDb(_currentTranslation);
            final isMySword = await _isMySwordFormat(db);
            final table = isMySword ? 'Bible' : 'verses';
            final colChapter = isMySword ? 'Chapter' : 'chapter';
            final colBook = isMySword ? 'Book' : 'book';
            final colVerse = isMySword ? 'Verse' : 'verse';
            final colScripture = isMySword ? 'Scripture' : 'text';

            final rows = await db.rawQuery(
              'SELECT $colVerse as v, $colScripture as s FROM $table WHERE $colBook = ? AND $colChapter = ? AND $colVerse >= ? AND $colVerse <= ? ORDER BY $colVerse',
              [b.number, chapter, startVerse, endVerse],
            );
            return rows.map((r) => BibleVerse(
              book: b.number,
              chapter: chapter,
              verse: r['v'] as int,
              text: (r['s'] as String).trim(),
              bookName: b.name,
            )).toList();
          }
        }
      }
    }
    return [];
  }

  Future<void> dispose() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
  }
}
