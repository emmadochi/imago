// lib/services/user_data_service.dart

import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_data_models.dart';

class UserDataService {
  UserDataService._();
  static final UserDataService instance = UserDataService._();

  Database? _db;
  Database get database => _db!;

  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'bible', 'user_data.db');

    _db = await openDatabase(
      dbPath,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE journal_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            content TEXT,
            tags TEXT,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE highlights (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            color_hex TEXT,
            UNIQUE(book, chapter, verse)
          )
        ''');
        
        await db.execute('''
          CREATE TABLE bookmarks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            title TEXT,
            created_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE notes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            content TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            UNIQUE(book, chapter, verse)
          )
        ''');

        await db.execute('''
          CREATE TABLE verse_tags (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            book INTEGER,
            chapter INTEGER,
            verse INTEGER,
            tag TEXT,
            UNIQUE(book, chapter, verse, tag)
          )
        ''');

        await db.execute('''
          CREATE TABLE reading_plan_progress (
            plan_id TEXT PRIMARY KEY,
            started_at INTEGER,
            completed_days TEXT,
            last_read_at INTEGER
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS verse_tags (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book INTEGER,
              chapter INTEGER,
              verse INTEGER,
              tag TEXT,
              UNIQUE(book, chapter, verse, tag)
            )
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS journal_entries (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              content TEXT,
              tags TEXT,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS highlights (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book INTEGER,
              chapter INTEGER,
              verse INTEGER,
              color_hex TEXT,
              UNIQUE(book, chapter, verse)
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS notes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              book INTEGER,
              chapter INTEGER,
              verse INTEGER,
              content TEXT,
              created_at INTEGER,
              updated_at INTEGER,
              UNIQUE(book, chapter, verse)
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS reading_plan_progress (
              plan_id TEXT PRIMARY KEY,
              started_at INTEGER,
              completed_days TEXT,
              last_read_at INTEGER
            )
          ''');
        }
      },
    );
  }

  // --- Highlights ---
  
  Future<void> saveHighlight(BibleHighlight highlight) async {
    if (_db == null) await init();
    await _db!.insert(
      'highlights',
      highlight.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteHighlight(int book, int chapter, int verse) async {
    if (_db == null) await init();
    await _db!.delete(
      'highlights',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
    );
  }

  Future<List<BibleHighlight>> getHighlightsForChapter(int book, int chapter) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'highlights',
      where: 'book = ? AND chapter = ?',
      whereArgs: [book, chapter],
    );
    return maps.map((m) => BibleHighlight.fromMap(m)).toList();
  }

  // --- Bookmarks ---
  
  Future<void> saveBookmark(BibleBookmark bookmark) async {
    if (_db == null) await init();
    await _db!.insert(
      'bookmarks',
      bookmark.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteBookmark(int id) async {
    if (_db == null) await init();
    await _db!.delete(
      'bookmarks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<BibleBookmark>> getBookmarks() async {
    if (_db == null) await init();
    final maps = await _db!.query('bookmarks', orderBy: 'created_at DESC');
    return maps.map((m) => BibleBookmark.fromMap(m)).toList();
  }

  Future<bool> isBookmarked(int book, int chapter, int verse) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'bookmarks',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  // --- Notes ---
  
  Future<void> saveNote(BibleNote note) async {
    if (_db == null) await init();
    await _db!.insert(
      'notes',
      note.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteNote(int book, int chapter, int verse) async {
    if (_db == null) await init();
    await _db!.delete(
      'notes',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
    );
  }

  Future<BibleNote?> getNoteForVerse(int book, int chapter, int verse) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'notes',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return BibleNote.fromMap(maps.first);
    }
    return null;
  }
  
  Future<List<BibleNote>> getNotesForChapter(int book, int chapter) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'notes',
      where: 'book = ? AND chapter = ?',
      whereArgs: [book, chapter],
    );
    return maps.map((m) => BibleNote.fromMap(m)).toList();
  }

  // --- Tags ---

  Future<void> addTag(BibleTag tag) async {
    if (_db == null) await init();
    await _db!.insert(
      'verse_tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> removeTag(int book, int chapter, int verse, String tag) async {
    if (_db == null) await init();
    await _db!.delete(
      'verse_tags',
      where: 'book = ? AND chapter = ? AND verse = ? AND tag = ?',
      whereArgs: [book, chapter, verse, tag],
    );
  }

  Future<List<BibleTag>> getTagsForVerse(int book, int chapter, int verse) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'verse_tags',
      where: 'book = ? AND chapter = ? AND verse = ?',
      whereArgs: [book, chapter, verse],
    );
    return maps.map((m) => BibleTag.fromMap(m)).toList();
  }

  Future<List<BibleTag>> getTagsForChapter(int book, int chapter) async {
    if (_db == null) await init();
    final maps = await _db!.query(
      'verse_tags',
      where: 'book = ? AND chapter = ?',
      whereArgs: [book, chapter],
    );
    return maps.map((m) => BibleTag.fromMap(m)).toList();
  }

  // --- Journal Entries ---
  
  Future<int> saveJournalEntry(JournalEntry entry) async {
    if (_db == null) await init();
    if (entry.id != null) {
      await _db!.update(
        'journal_entries',
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      return entry.id!;
    } else {
      return await _db!.insert(
        'journal_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> deleteJournalEntry(int id) async {
    if (_db == null) await init();
    await _db!.delete(
      'journal_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<JournalEntry>> getJournalEntries() async {
    if (_db == null) await init();
    final maps = await _db!.query('journal_entries', orderBy: 'updated_at DESC');
    return maps.map((m) => JournalEntry.fromMap(m)).toList();
  }
}

