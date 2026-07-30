import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class CrossrefService {
  CrossrefService._();
  static final CrossrefService instance = CrossrefService._();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'bible', 'crossref.db');

    // Overwrite database from assets to ensure it's not corrupted
    if (File(dbPath).existsSync()) {
      await File(dbPath).delete();
    }
    
    await Directory(join(dir.path, 'bible')).create(recursive: true);
    final bytes = await rootBundle.load('assets/bible/crossref.db');
    await File(dbPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), 
      flush: true
    );

    _db = await openDatabase(dbPath, readOnly: true);
  }

  /// Retrieves target cross-reference strings for a source verse (e.g. book 43, chapter 3, verse 16)
  Future<List<String>> getCrossReferences(int book, int chapter, int verse) async {
    if (_db == null) await init();

    final rows = await _db!.rawQuery(
      'SELECT target_ref FROM crossref WHERE source_book = ? AND source_chapter = ? AND source_verse = ? ORDER BY id ASC',
      [book, chapter, verse],
    );

    return rows.map((r) => r['target_ref'] as String).toList();
  }
}
