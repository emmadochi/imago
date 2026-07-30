import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;

class DictionaryService {
  DictionaryService._();
  static final DictionaryService instance = DictionaryService._();

  Database? _db;
  final String _backendUrl = 'https://imago-nthk.onrender.com';

  Future<void> init() async {
    if (_db != null) return;
    
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'bible', 'dictionary.db');
    
    // For development: overwrite existing dictionary.db to reflect new updates
    if (File(dbPath).existsSync()) {
      await File(dbPath).delete();
    }
    
    await Directory(join(dir.path, 'bible')).create(recursive: true);
    final bytes = await rootBundle.load('assets/bible/dictionary.db');
    await File(dbPath).writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes), 
      flush: true
    );
    
    _db = await openDatabase(dbPath, readOnly: true);
  }

  /// Looks up a term, strongs number, or word in the dictionary.
  Future<Map<String, dynamic>?> lookupWord(String query) async {
    if (_db == null) await init();
    
    final cleanQuery = query.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (cleanQuery.isEmpty) return null;
    
    // First try exact term match, strongs match, or translit match
    final results = await _db!.rawQuery(
      '''SELECT strongs, term, translit, pron, definition, type FROM dictionary 
         WHERE LOWER(term) = ? OR LOWER(strongs) = ? OR LOWER(translit) = ? 
         LIMIT 1''',
      [cleanQuery, cleanQuery, cleanQuery],
    );
    
    if (results.isNotEmpty) {
      return results.first;
    }

    // Fallback: substring search
    final partialResults = await _db!.rawQuery(
      '''SELECT strongs, term, translit, pron, definition, type FROM dictionary 
         WHERE LOWER(term) LIKE ? OR LOWER(definition) LIKE ? 
         LIMIT 1''',
      ['%$cleanQuery%', '%$cleanQuery%'],
    );

    if (partialResults.isNotEmpty) {
      return partialResults.first;
    }
    
    return null;
  }

  /// Retrieves terms in the dictionary by type ('easton', 'greek', 'hebrew').
  Future<List<Map<String, dynamic>>> getWords({String type = 'easton', int limit = 300}) async {
    if (_db == null) await init();
    return await _db!.rawQuery(
      'SELECT strongs, term, translit, pron, definition, type FROM dictionary WHERE type = ? ORDER BY id ASC LIMIT ?',
      [type, limit],
    );
  }

  /// Searches for terms matching the query by type.
  Future<List<Map<String, dynamic>>> searchWords(String query, {String type = 'easton', int limit = 300}) async {
    if (_db == null) await init();
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return getWords(type: type, limit: limit);
    
    return await _db!.rawQuery(
      '''SELECT strongs, term, translit, pron, definition, type FROM dictionary 
         WHERE type = ? AND (LOWER(term) LIKE ? OR LOWER(strongs) LIKE ? OR LOWER(translit) LIKE ? OR LOWER(definition) LIKE ?) 
         ORDER BY id ASC LIMIT ?''',
      [type, '%$cleanQuery%', '%$cleanQuery%', '%$cleanQuery%', '%$cleanQuery%', limit],
    );
  }

  /// AI Simplification Route
  Future<String> simplifyConcept(String term, String context) async {
    try {
      final res = await http.post(
        Uri.parse('$_backendUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'message': 'Explain this theological concept simply: $term - $context',
          'mood': 'Neutral',
          'history': []
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return data['response'] ?? 'I could not simplify this concept at this time.';
      }
      return 'Connection error (${res.statusCode}). Unable to simplify concept.';
    } catch (_) {
      return 'Failed to reach the ministry servers. Please check your connection.';
    }
  }
}
