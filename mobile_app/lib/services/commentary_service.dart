// lib/services/commentary_service.dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CommentaryModule {
  final String id;
  final String name;
  final String shortName;
  final String author;
  final String iconEmoji;
  final String dbName;

  const CommentaryModule({
    required this.id,
    required this.name,
    required this.shortName,
    required this.author,
    required this.iconEmoji,
    required this.dbName,
  });
}

const List<CommentaryModule> kCommentaryModules = [
  CommentaryModule(
    id: 'matthew_henry',
    name: "Matthew Henry's Concise Commentary",
    shortName: 'Matthew Henry',
    author: 'Matthew Henry',
    iconEmoji: '💡',
    dbName: 'matthew_henry.db',
  ),
  CommentaryModule(
    id: 'adam_clarke',
    name: "Adam Clarke's Commentary on the Bible",
    shortName: 'Adam Clarke',
    author: 'Dr. Adam Clarke',
    iconEmoji: '🏛️',
    dbName: 'adam_clarke.db',
  ),
  CommentaryModule(
    id: 'barnes',
    name: "Barnes' Notes on the Old & New Testaments",
    shortName: "Barnes' Notes",
    author: 'Albert Barnes',
    iconEmoji: '📖',
    dbName: 'barnes.db',
  ),
  CommentaryModule(
    id: 'jfb',
    name: 'Jamieson-Fausset-Brown Commentary',
    shortName: 'JFB Exegetical',
    author: 'Robert Jamieson, A.R. Fausset, David Brown',
    iconEmoji: '📜',
    dbName: 'jfb.db',
  ),
  CommentaryModule(
    id: 'scofield',
    name: 'Scofield Reference Notes',
    shortName: 'Scofield Study',
    author: 'C.I. Scofield',
    iconEmoji: '✝️',
    dbName: 'scofield.db',
  ),
  CommentaryModule(
    id: 'bible_map',
    name: 'Bible Maps & Sacred Geography',
    shortName: 'Bible Maps',
    author: 'Biblical Topography & Archaeological Society',
    iconEmoji: '🗺️',
    dbName: 'bible_maps.db',
  ),
  CommentaryModule(
    id: 'biblepic',
    name: 'BiblePic Sacred Illustrations & Art',
    shortName: 'BiblePic Art',
    author: 'Classical Masters & Gustave Doré',
    iconEmoji: '🎨',
    dbName: 'biblepic.db',
  ),
];

class CommentaryService {
  static final CommentaryService instance = CommentaryService._internal();
  CommentaryService._internal();

  final Map<String, Database> _dbCache = {};

  Future<Database> _getDatabase(String moduleId) async {
    if (_dbCache.containsKey(moduleId)) {
      return _dbCache[moduleId]!;
    }

    final module = kCommentaryModules.firstWhere(
      (m) => m.id == moduleId,
      orElse: () => kCommentaryModules.first,
    );

    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = join(docsDir.path, 'bible', module.dbName);

    if (!await File(dbPath).exists()) {
      await Directory(dirname(dbPath)).create(recursive: true);
      try {
        final data = await rootBundle.load('assets/bible/${module.dbName}');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(dbPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        return await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS commentary (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                book INTEGER,
                chapter INTEGER,
                verse INTEGER,
                reference TEXT,
                title TEXT,
                text TEXT
              )
            ''');
          },
        );
      }
    }

    final db = await openDatabase(dbPath, readOnly: true);
    _dbCache[moduleId] = db;
    return db;
  }

  /// Gets commentary from a specific commentary module for a verse
  Future<Map<String, dynamic>?> getCommentary({
    required String moduleId,
    required int book,
    required int chapter,
    required int verse,
  }) async {
    final db = await _getDatabase(moduleId);
    final results = await db.query(
      'commentary',
      where: 'book = ? AND chapter = ? AND (verse = ? OR verse = 0)',
      whereArgs: [book, chapter, verse],
      limit: 1,
    );

    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }
}
