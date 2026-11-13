// lib/services/user_data_service.dart

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
      version: 6,
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

        await db.execute('''
          CREATE TABLE bible_lists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT,
            color_hex TEXT,
            is_preset INTEGER DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE bible_list_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            list_id INTEGER,
            reference TEXT,
            custom_title TEXT,
            sort_order INTEGER,
            created_at INTEGER,
            FOREIGN KEY (list_id) REFERENCES bible_lists (id) ON DELETE CASCADE
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
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS bible_lists (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              description TEXT,
              color_hex TEXT,
              is_preset INTEGER DEFAULT 0,
              created_at INTEGER,
              updated_at INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS bible_list_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              list_id INTEGER,
              reference TEXT,
              custom_title TEXT,
              sort_order INTEGER,
              created_at INTEGER,
              FOREIGN KEY (list_id) REFERENCES bible_lists (id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
    await _seedPresetsIfEmpty();
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

  // --- Bible Lists ---

  Future<void> _seedPresetsIfEmpty() async {
    if (_db == null) return;
    final count = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM bible_lists')) ?? 0;
    if (count > 0) return;

    final presets = [
      {
        'title': 'Peace & Rest',
        'description': 'Scriptures to soothe anxiety, quiet the heart, and anchor your soul in divine peace.',
        'color': '#3D5AFE',
        'items': ['Psalm 23:1-6', 'Philippians 4:6-7', 'John 14:27', 'Matthew 11:28-30', 'Psalm 91:1-4'],
      },
      {
        'title': 'Divine Healing & Renewal',
        'description': 'Scriptures of health, restoration, and life-giving strength for body and mind.',
        'color': '#00E676',
        'items': ['Isaiah 53:4-5', 'Psalm 103:1-5', 'Jeremiah 30:17', '1 Peter 2:24', 'Exodus 15:26'],
      },
      {
        'title': 'Victory & Faith Declarations',
        'description': 'Unshakable promises of victory, boldness, and conquering faith in Christ.',
        'color': '#FFC857',
        'items': ['Romans 8:31-39', 'Hebrews 11:1-6', '2 Timothy 1:7', 'Joshua 1:9', '1 John 4:4'],
      },
      {
        'title': 'Morning Blessings & Strength',
        'description': 'Begin your day aligned with God\'s grace, renewed strength, and fresh mercy.',
        'color': '#FF4081',
        'items': ['Psalm 5:3', 'Lamentations 3:22-24', 'Isaiah 40:29-31', 'Psalm 118:24', 'Proverbs 3:5-6'],
      },
    ];

    final now = DateTime.now().millisecondsSinceEpoch;
    for (final p in presets) {
      final listId = await _db!.insert('bible_lists', {
        'title': p['title'],
        'description': p['description'],
        'color_hex': p['color'],
        'is_preset': 1,
        'created_at': now,
        'updated_at': now,
      });

      final items = p['items'] as List<String>;
      for (int i = 0; i < items.length; i++) {
        await _db!.insert('bible_list_items', {
          'list_id': listId,
          'reference': items[i],
          'custom_title': '',
          'sort_order': i,
          'created_at': now,
        });
      }
    }
  }

  Future<List<BibleList>> getBibleLists() async {
    if (_db == null) await init();
    final listMaps = await _db!.query('bible_lists', orderBy: 'updated_at DESC');
    final List<BibleList> lists = [];

    for (final map in listMaps) {
      final listId = map['id'] as int;
      final itemMaps = await _db!.query(
        'bible_list_items',
        where: 'list_id = ?',
        whereArgs: [listId],
        orderBy: 'sort_order ASC',
      );
      final items = itemMaps.map((m) => BibleListItem.fromMap(m)).toList();
      lists.add(BibleList.fromMap(map, items: items));
    }
    return lists;
  }

  Future<BibleList?> getBibleListWithItems(int listId) async {
    if (_db == null) await init();
    final listMaps = await _db!.query('bible_lists', where: 'id = ?', whereArgs: [listId], limit: 1);
    if (listMaps.isEmpty) return null;

    final itemMaps = await _db!.query(
      'bible_list_items',
      where: 'list_id = ?',
      whereArgs: [listId],
      orderBy: 'sort_order ASC',
    );
    final items = itemMaps.map((m) => BibleListItem.fromMap(m)).toList();
    return BibleList.fromMap(listMaps.first, items: items);
  }

  Future<int> saveBibleList(BibleList list, {List<String>? initialReferences}) async {
    if (_db == null) await init();
    final now = DateTime.now().millisecondsSinceEpoch;

    int listId;
    if (list.id != null) {
      listId = list.id!;
      await _db!.update(
        'bible_lists',
        {
          'title': list.title,
          'description': list.description,
          'color_hex': list.colorHex,
          'is_preset': list.isPreset ? 1 : 0,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [listId],
      );
    } else {
      listId = await _db!.insert('bible_lists', {
        'title': list.title,
        'description': list.description,
        'color_hex': list.colorHex,
        'is_preset': list.isPreset ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      });
    }

    if (initialReferences != null && initialReferences.isNotEmpty) {
      for (int i = 0; i < initialReferences.length; i++) {
        final ref = initialReferences[i].trim();
        if (ref.isNotEmpty) {
          await _db!.insert('bible_list_items', {
            'list_id': listId,
            'reference': ref,
            'custom_title': '',
            'sort_order': i,
            'created_at': now,
          });
        }
      }
    }
    return listId;
  }

  Future<void> deleteBibleList(int id) async {
    if (_db == null) await init();
    await _db!.delete('bible_list_items', where: 'list_id = ?', whereArgs: [id]);
    await _db!.delete('bible_lists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> addScriptureToList(int listId, String reference, {String customTitle = ''}) async {
    if (_db == null) await init();
    final countResult = await _db!.rawQuery(
      'SELECT MAX(sort_order) as max_order FROM bible_list_items WHERE list_id = ?',
      [listId],
    );
    final maxOrder = (countResult.first['max_order'] as int?) ?? -1;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db!.insert('bible_list_items', {
      'list_id': listId,
      'reference': reference.trim(),
      'custom_title': customTitle.trim(),
      'sort_order': maxOrder + 1,
      'created_at': now,
    });

    await _db!.update(
      'bible_lists',
      {'updated_at': now},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  Future<void> deleteListItem(int itemId, int listId) async {
    if (_db == null) await init();
    await _db!.delete('bible_list_items', where: 'id = ?', whereArgs: [itemId]);
    await _db!.update(
      'bible_lists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [listId],
    );
  }

  Future<void> reorderListItems(int listId, List<int> itemIdsInOrder) async {
    if (_db == null) await init();
    final batch = _db!.batch();
    for (int i = 0; i < itemIdsInOrder.length; i++) {
      batch.update(
        'bible_list_items',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [itemIdsInOrder[i]],
      );
    }
    batch.update(
      'bible_lists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [listId],
    );
    await batch.commit(noResult: true);
  }
}


