// lib/services/bible_service.dart
// Singleton service for reading MySword .bbl.mybible SQLite databases

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible_models.dart';

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

  /// Initialize — copies assets to writable storage on first run.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTranslation = prefs.getString('bible_translation') ?? 'KJV';
    // Pre-copy all translation DBs so switching is instant
    for (final t in kBibleTranslations) {
      await _getDb(t.abbreviation);
    }
  }

  Future<void> setTranslation(String abbreviation) async {
    _currentTranslation = abbreviation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bible_translation', abbreviation);
  }

  Future<Database> _getDb(String abbreviation) async {
    if (_dbs.containsKey(abbreviation)) return _dbs[abbreviation]!;

    final translation = kBibleTranslations.firstWhere((t) => t.abbreviation == abbreviation);
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'bible', translation.fileName);
    
    final prefs = await SharedPreferences.getInstance();
    final int cachedVersion = prefs.getInt('db_version_$abbreviation') ?? 0;
    const int currentDbVersion = 2; // Bumped to 2 to force overwrite of buggy DBs

    // Copy from assets if not already on disk OR if it's an older version
    if (!File(dbPath).existsSync() || cachedVersion < currentDbVersion) {
      await Directory(join(dir.path, 'bible')).create(recursive: true);
      final bytes = await rootBundle.load('assets/bible/${translation.fileName}');
      await File(dbPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      await prefs.setInt('db_version_$abbreviation', currentDbVersion);
    }

    final db = await openDatabase(dbPath, readOnly: true);
    _dbs[abbreviation] = db;
    return db;
  }

  /// Returns all chapter counts for a given book number (1-based).
  Future<int> getChapterCount(int bookNumber) async {
    final db = await _getDb(_currentTranslation);
    final result = await db.rawQuery(
      'SELECT MAX(Chapter) as max_chapter FROM Bible WHERE Book = ?',
      [bookNumber],
    );
    return (result.first['max_chapter'] as int?) ?? 0;
  }

  /// Returns verse count for a given book + chapter.
  Future<int> getVerseCount(int bookNumber, int chapter) async {
    final db = await _getDb(_currentTranslation);
    final result = await db.rawQuery(
      'SELECT MAX(Verse) as max_verse FROM Bible WHERE Book = ? AND Chapter = ?',
      [bookNumber, chapter],
    );
    return (result.first['max_verse'] as int?) ?? 0;
  }

  /// Returns all verses for a given book + chapter.
  Future<List<BibleVerse>> getVerses(int bookNumber, int chapter) async {
    final db = await _getDb(_currentTranslation);
    final bookName = kBibleBooks.firstWhere((b) => b.number == bookNumber).name;
    final rows = await db.rawQuery(
      'SELECT Verse, Scripture FROM Bible WHERE Book = ? AND Chapter = ? ORDER BY Verse',
      [bookNumber, chapter],
    );
    return rows
        .map((r) => BibleVerse(
              book: bookNumber,
              chapter: chapter,
              verse: r['Verse'] as int,
              text: (r['Scripture'] as String).trim(),
              bookName: bookName,
            ))
        .toList();
  }

  /// Full-text search across all verses.
  Future<List<BibleVerse>> search(String query, {int limit = 100}) async {
    if (query.trim().isEmpty) return [];
    final db = await _getDb(_currentTranslation);
    final rows = await db.rawQuery(
      'SELECT Book, Chapter, Verse, Scripture FROM Bible WHERE Scripture LIKE ? ORDER BY Book, Chapter, Verse LIMIT ?',
      ['%${query.trim()}%', limit],
    );
    return rows.map((r) {
      final bookNum = r['Book'] as int;
      final bookName = bookNum >= 1 && bookNum <= 66
          ? kBibleBooks.firstWhere((b) => b.number == bookNum).name
          : 'Unknown';
      return BibleVerse(
        book: bookNum,
        chapter: r['Chapter'] as int,
        verse: r['Verse'] as int,
        text: (r['Scripture'] as String).trim(),
        bookName: bookName,
      );
    }).toList();
  }

  Future<void> dispose() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
  }
}
