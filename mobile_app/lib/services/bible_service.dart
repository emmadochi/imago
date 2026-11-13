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
import '../models/user_data_models.dart';
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
    
    // Ensure the saved translation actually exists in our models
    if (kBibleTranslations.any((t) => t.abbreviation == savedTranslation)) {
      _currentTranslation = savedTranslation;
    } else {
      _currentTranslation = 'KJV';
      await prefs.setString('bible_translation', 'KJV');
    }

    // Lazy Loading: Only open the active translation database on boot.
    // Other translations are opened lazily on-demand when selected, saving hundreds of MBs of RAM and CPU.
    try {
      await _getDb(_currentTranslation);
    } catch (_) {
      _currentTranslation = 'KJV';
      await _getDb('KJV');
      await prefs.setString('bible_translation', 'KJV');
    }
  }

  Future<void> setTranslation(String abbreviation) async {
    _currentTranslation = abbreviation;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bible_translation', abbreviation);
  }

  bool isTranslationAvailable(String abbreviation) {
    return _dbs.containsKey(abbreviation) ||
        kBibleTranslations.any((t) => t.abbreviation == abbreviation && t.isBundled);
  }

  /// Checks if a translation database exists offline on device
  Future<bool> isTranslationDownloaded(String abbreviation) async {
    final translation = kBibleTranslations.firstWhere(
      (t) => t.abbreviation == abbreviation,
      orElse: () => kBibleTranslations.first,
    );
    if (translation.isBundled) return true;

    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'bible', translation.fileName);
    final file = File(dbPath);
    // Ignore dummy stub 16KB asset files, requiring > 50KB for a real translation DB
    return file.existsSync() && file.lengthSync() > 50000;
  }

  /// Downloads and decompresses an on-demand translation with progress callback
  Future<bool> downloadTranslation(
    String abbreviation, {
    Function(double progress)? onProgress,
  }) async {
    try {
      final translation = kBibleTranslations.firstWhere((t) => t.abbreviation == abbreviation);
      if (translation.remoteUrl.isEmpty) return false;

      final dir = await getApplicationDocumentsDirectory();
      final bibleDir = Directory(join(dir.path, 'bible'));
      if (!bibleDir.existsSync()) {
        await bibleDir.create(recursive: true);
      }

      final targetPath = join(dir.path, 'bible', translation.fileName);
      final tempGzPath = join(dir.path, 'bible', '${translation.fileName}.tmp.gz');

      // Instant fallback: check if asset exists locally and is a full database (> 50KB)
      try {
        final assetData = await rootBundle.load('assets/bible/${translation.fileName}');
        if (assetData.lengthInBytes > 50000) {
          final bytes = assetData.buffer.asUint8List(assetData.offsetInBytes, assetData.lengthInBytes);
          await File(targetPath).writeAsBytes(bytes, flush: true);
          if (onProgress != null) onProgress(1.0);
          return true;
        }
      } catch (_) {}

      // Request streamed download
      final request = http.Request('GET', Uri.parse(translation.remoteUrl));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        // Fallback: try raw uncompressed .bbl.mybible URL if .gz URL is not ready
        final rawUrl = translation.remoteUrl.replaceAll('.gz', '');
        final rawReq = http.Request('GET', Uri.parse(rawUrl));
        final rawRes = await http.Client().send(rawReq);
        if (rawRes.statusCode != 200) return false;

        final totalBytes = rawRes.contentLength ?? 0;
        int receivedBytes = 0;
        final file = File(targetPath);
        final sink = file.openWrite();

        await for (var chunk in rawRes.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.close();
      } else {
        final totalBytes = response.contentLength ?? 0;
        int receivedBytes = 0;
        final gzFile = File(tempGzPath);
        final sink = gzFile.openWrite();

        await for (var chunk in response.stream) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0 && onProgress != null) {
            onProgress(receivedBytes / totalBytes);
          }
        }
        await sink.close();

        // Decompress GZip file to targetPath
        final gzBytes = await gzFile.readAsBytes();
        final decompressedBytes = GZipCodec().decode(gzBytes);
        await File(targetPath).writeAsBytes(decompressedBytes, flush: true);
        if (gzFile.existsSync()) {
          await gzFile.delete();
        }
      }

      // Register in memory cache
      await _getDb(abbreviation);
      return true;
    } catch (e) {
      print("ERROR: Failed to download Bible translation $abbreviation: $e");
      return false;
    }
  }

  /// Deletes a downloaded translation from local storage
  Future<bool> deleteDownloadedTranslation(String abbreviation) async {
    try {
      final translation = kBibleTranslations.firstWhere((t) => t.abbreviation == abbreviation);
      if (translation.isBundled) return false;

      if (_dbs.containsKey(abbreviation)) {
        await _dbs[abbreviation]!.close();
        _dbs.remove(abbreviation);
      }

      final dir = await getApplicationDocumentsDirectory();
      final dbPath = join(dir.path, 'bible', translation.fileName);
      final file = File(dbPath);

      if (file.existsSync()) {
        await file.delete();
        if (_currentTranslation == abbreviation) {
          await setTranslation('KJV');
        }
        return true;
      }
      return false;
    } catch (e) {
      print("ERROR: Deleting downloaded translation $abbreviation: $e");
      return false;
    }
  }

  Future<Database> _getDb(String abbreviation) async {
    if (_dbs.containsKey(abbreviation)) return _dbs[abbreviation]!;

    try {
      final translation = kBibleTranslations.firstWhere((t) => t.abbreviation == abbreviation);
      final dir = await getApplicationDocumentsDirectory();
      final dbPath = join(dir.path, 'bible', translation.fileName);
      
      final prefs = await SharedPreferences.getInstance();
      final int cachedVersion = prefs.getInt('db_version_$abbreviation') ?? 0;
      const int currentDbVersion = 13;

      if (translation.isBundled) {
        final file = File(dbPath);
        // Copy from assets if not already on disk, or if it's an older version, or if file size is a stub (< 100KB)
        if (!file.existsSync() || file.lengthSync() < 100000 || cachedVersion < currentDbVersion) {
          await Directory(join(dir.path, 'bible')).create(recursive: true);
          final bytes = await rootBundle.load('assets/bible/${translation.fileName}');
          final uint8List = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
          await file.writeAsBytes(uint8List, flush: true);
          await prefs.setInt('db_version_$abbreviation', currentDbVersion);
        }
      } else {
        // Non-bundled translation must exist locally after on-demand download
        if (!File(dbPath).existsSync() || File(dbPath).lengthSync() < 100000) {
          throw Exception("Translation '$abbreviation' is not downloaded yet.");
        }
      }

      final db = await openDatabase(dbPath, readOnly: true);
      _dbs[abbreviation] = db;
      return db;
    } catch (e) {
      print("ERROR loading Bible translation '$abbreviation': $e");
      if (abbreviation != 'KJV') {
        print("WARNING: Falling back to KJV for '$abbreviation'.");
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
    try {
      final db = await _getDb(_currentTranslation);
      final isMySword = await _isMySwordFormat(db);
      final table = isMySword ? 'Bible' : 'verses';
      final colChapter = isMySword ? 'Chapter' : 'chapter';
      final colBook = isMySword ? 'Book' : 'book';

      final result = await db.rawQuery(
        'SELECT MAX($colChapter) as max_chapter FROM $table WHERE $colBook = ?',
        [bookNumber],
      );
      final count = (result.first['max_chapter'] as int?) ?? 0;
      if (count > 0) return count;
    } catch (e) {
      print("WARNING: Error getting chapter count for $_currentTranslation: $e");
    }
    return kStandardBookChapterCounts[bookNumber] ?? 1;
  }

  /// Returns verse count for a given book + chapter.
  Future<int> getVerseCount(int bookNumber, int chapter) async {
    try {
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
      final count = (result.first['max_verse'] as int?) ?? 0;
      if (count > 0) return count;
    } catch (e) {
      print("WARNING: Error getting verse count: $e");
    }
    return 30;
  }

  final Map<String, List<BibleVerse>> _aiVersesCache = {};

  /// Returns all verses for a given book + chapter.
  Future<List<BibleVerse>> getVerses(int bookNumber, int chapter, {String? translationAbbreviation}) async {
    final trans = translationAbbreviation ?? _currentTranslation;
    final Map<String, String> dynamicAiLangs = {
      'TLB': 'The Living Bible',
    };

    final bool isDynamicAi = dynamicAiLangs.containsKey(trans);
    final String cacheKey = "${trans}_${bookNumber}_${chapter}";

    // Check memory cache for dynamic AI-translated chapters
    if (isDynamicAi && _aiVersesCache.containsKey(cacheKey)) {
      return _aiVersesCache[cacheKey]!;
    }

    // Try reading directly from the translation's offline SQLite database
    List<BibleVerse> targetVerses = [];
    try {
      final db = await _getDb(trans);
      final isMySword = await _isMySwordFormat(db);
      final table = isMySword ? 'Bible' : 'verses';
      final colChapter = isMySword ? 'Chapter' : 'chapter';
      final colBook = isMySword ? 'Book' : 'book';
      final colVerse = isMySword ? 'Verse' : 'verse';
      final colScripture = isMySword ? 'Scripture' : 'text';

      final bookName = kBibleBooks.firstWhere((b) => b.number == bookNumber, orElse: () => kBibleBooks.first).name;
      final rows = await db.rawQuery(
        'SELECT $colVerse as v, $colScripture as s FROM $table WHERE $colBook = ? AND $colChapter = ? ORDER BY $colVerse',
        [bookNumber, chapter],
      );

      targetVerses = rows
          .map((r) => BibleVerse(
                book: bookNumber,
                chapter: chapter,
                verse: r['v'] as int,
                text: BibleVerse.cleanText(r['s'] as String),
                bookName: bookName,
              ))
          .toList();
    } catch (e) {
      print("WARNING: Failed fetching verses from DB for $trans: $e");
    }

    // If native offline translation verses exist and this is not a dynamic AI request, return offline verses directly
    if (!isDynamicAi && targetVerses.isNotEmpty) {
      return targetVerses;
    }

    // Baseline fallback if needed
    List<BibleVerse> baseVerses = targetVerses;
    if (baseVerses.isEmpty) {
      try {
        final kjvDb = await _getDb('KJV');
        final isMySword = await _isMySwordFormat(kjvDb);
        final table = isMySword ? 'Bible' : 'verses';
        final colChapter = isMySword ? 'Chapter' : 'chapter';
        final colBook = isMySword ? 'Book' : 'book';
        final colVerse = isMySword ? 'Verse' : 'verse';
        final colScripture = isMySword ? 'Scripture' : 'text';
        final bookName = kBibleBooks.firstWhere((b) => b.number == bookNumber, orElse: () => kBibleBooks.first).name;

        final kjvRows = await kjvDb.rawQuery(
          'SELECT $colVerse as v, $colScripture as s FROM $table WHERE $colBook = ? AND $colChapter = ? ORDER BY $colVerse',
          [bookNumber, chapter],
        );
        baseVerses = kjvRows
            .map((r) => BibleVerse(
                  book: bookNumber,
                  chapter: chapter,
                  verse: r['v'] as int,
                  text: BibleVerse.cleanText(r['s'] as String),
                  bookName: bookName,
                ))
            .toList();
      } catch (e) {
        print("ERROR fetching fallback KJV verses: $e");
      }
    }

    // If dynamic AI translation is requested (e.g. TLB paraphrase), query the translation endpoint
    if (isDynamicAi && baseVerses.isNotEmpty) {
      try {
        final targetLang = dynamicAiLangs[trans]!;
        final bookName = kBibleBooks.firstWhere((b) => b.number == bookNumber, orElse: () => kBibleBooks.first).name;
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
            final result = baseVerses.map((v) {
              return BibleVerse(
                book: v.book,
                chapter: v.chapter,
                verse: v.verse,
                text: BibleVerse.cleanText(transMap[v.verse] ?? v.text),
                bookName: v.bookName,
              );
            }).toList();

            _aiVersesCache[cacheKey] = result;
            return result;
          }
        }
      } catch (e) {
        print("WARNING: Bible dynamic translation API error for $trans: $e");
      }
    }

    return baseVerses;
  }


  /// Full-text and scoped search across verses.
  /// Supports:
  /// - Exact phrase, all words (AND), or any word (OR) matching
  /// - Book filters (specific books or MySword Bible groups)
  Future<List<BibleVerse>> search(
    String query, {
    int limit = 150,
    BibleSearchMatchType matchType = BibleSearchMatchType.exactPhrase,
    List<int>? bookFilter,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // Filter set for quick lookup
    final Set<int>? allowedBooks = (bookFilter != null && bookFilter.isNotEmpty && bookFilter.length < 66)
        ? bookFilter.toSet()
        : null;

    // 1. Fetch topical matches first
    final List<BibleVerse> topicalMatches = [];
    final lowerQuery = q.toLowerCase();

    if (kTopicalIndex.containsKey(lowerQuery)) {
      final references = kTopicalIndex[lowerQuery]!;
      for (final ref in references) {
        final verses = await getVerseByReference(ref);
        for (final v in verses) {
          if (allowedBooks == null || allowedBooks.contains(v.book)) {
            topicalMatches.add(v);
          }
        }
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

      String whereClause = '$cS LIKE ?';
      List<dynamic> whereArgs = ['%[$upperQuery]%'];

      if (allowedBooks != null && allowedBooks.isNotEmpty) {
        final placeholders = List.filled(allowedBooks.length, '?').join(',');
        whereClause += ' AND $cB IN ($placeholders)';
        whereArgs.addAll(allowedBooks.toList());
      }

      // Find references in KJV+
      final kjvRows = await kjvDb.rawQuery(
        'SELECT $cB as b, $cC as c, $cV as v, $cS as s FROM $t WHERE $whereClause ORDER BY $cB, $cC, $cV LIMIT ?',
        [...whereArgs, limit],
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
      // Standard full text search with matchType and bookFilter
      db = await _getDb(_currentTranslation);
      isMySword = await _isMySwordFormat(db);
      table = isMySword ? 'Bible' : 'verses';
      colChapter = isMySword ? 'Chapter' : 'chapter';
      colBook = isMySword ? 'Book' : 'book';
      colVerse = isMySword ? 'Verse' : 'verse';
      colScripture = isMySword ? 'Scripture' : 'text';

      // Build WHERE conditions based on matchType
      String textCondition;
      List<dynamic> textArgs = [];

      switch (matchType) {
        case BibleSearchMatchType.exactPhrase:
          textCondition = '$colScripture LIKE ?';
          textArgs.add('%$q%');
          break;

        case BibleSearchMatchType.allWords:
          final words = q
              .split(RegExp(r'\s+'))
              .map((w) => w.trim().replaceAll(RegExp(r'[^\w\s]'), ''))
              .where((w) => w.isNotEmpty)
              .toList();
          if (words.isEmpty) {
            textCondition = '$colScripture LIKE ?';
            textArgs.add('%$q%');
          } else {
            textCondition = words.map((_) => '$colScripture LIKE ?').join(' AND ');
            textArgs.addAll(words.map((w) => '%$w%'));
          }
          break;

        case BibleSearchMatchType.anyWord:
          final words = q
              .split(RegExp(r'\s+'))
              .map((w) => w.trim().replaceAll(RegExp(r'[^\w\s]'), ''))
              .where((w) => w.isNotEmpty)
              .toList();
          if (words.isEmpty) {
            textCondition = '$colScripture LIKE ?';
            textArgs.add('%$q%');
          } else {
            textCondition = '(${words.map((_) => '$colScripture LIKE ?').join(' OR ')})';
            textArgs.addAll(words.map((w) => '%$w%'));
          }
          break;
      }

      String whereClause = textCondition;
      List<dynamic> whereArgs = [...textArgs];

      if (allowedBooks != null && allowedBooks.isNotEmpty) {
        final placeholders = List.filled(allowedBooks.length, '?').join(',');
        whereClause += ' AND $colBook IN ($placeholders)';
        whereArgs.addAll(allowedBooks.toList());
      }

      rows = await db.rawQuery(
        'SELECT $colBook as b, $colChapter as c, $colVerse as v, $colScripture as s FROM $table WHERE $whereClause ORDER BY $colBook, $colChapter, $colVerse LIMIT ?',
        [...whereArgs, limit],
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
        text: BibleVerse.cleanText(r['s'] as String),
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

  static const Map<String, int> _bookAliases = {
    'psalm': 19,
    'psalms': 19,
    'ps': 19,
    'psa': 19,
    'pss': 19,
    'prov': 20,
    'proverbs': 20,
    'proverb': 20,
    'pro': 20,
    'prv': 20,
    'song of songs': 22,
    'song of solomon': 22,
    'songs': 22,
    'canticles': 22,
    'eccl': 21,
    'ecclesiastes': 21,
    'ecc': 21,
    'matt': 40,
    'matthew': 40,
    'mt': 40,
    'mrk': 41,
    'mark': 41,
    'luk': 42,
    'luke': 42,
    'jhn': 43,
    'john': 43,
    'act': 44,
    'acts': 44,
    'rom': 45,
    'romans': 45,
    '1 cor': 46,
    '1 corinthians': 46,
    '2 cor': 47,
    '2 corinthians': 47,
    'gal': 48,
    'galatians': 48,
    'eph': 49,
    'ephesians': 49,
    'phil': 50,
    'philippians': 50,
    'col': 51,
    'colossians': 51,
    '1 thess': 52,
    '1 thessalonians': 52,
    '2 thess': 53,
    '2 thessalonians': 53,
    '1 tim': 54,
    '1 timothy': 54,
    '2 tim': 55,
    '2 timothy': 55,
    'tit': 56,
    'titus': 56,
    'philem': 57,
    'philemon': 57,
    'heb': 58,
    'hebrews': 58,
    'jas': 59,
    'james': 59,
    '1 pet': 60,
    '1 peter': 60,
    '2 pet': 61,
    '2 peter': 61,
    '1 jn': 62,
    '1 john': 62,
    '2 jn': 63,
    '2 john': 63,
    '3 jn': 64,
    '3 john': 64,
    'jud': 65,
    'jude': 65,
    'rev': 66,
    'revelation': 66,
    'revelations': 66,
    'gen': 1,
    'genesis': 1,
    'ex': 2,
    'exod': 2,
    'exodus': 2,
    'lev': 3,
    'leviticus': 3,
    'num': 4,
    'numbers': 4,
    'deut': 5,
    'deuteronomy': 5,
    'josh': 6,
    'joshua': 6,
    'judg': 7,
    'judges': 7,
    'ruth': 8,
    '1 sam': 9,
    '1 samuel': 9,
    '2 sam': 10,
    '2 samuel': 10,
    '1 ki': 11,
    '1 kgs': 11,
    '1 kings': 11,
    '2 ki': 12,
    '2 kgs': 12,
    '2 kings': 12,
    '1 chr': 13,
    '1 chron': 13,
    '1 chronicles': 13,
    '2 chr': 14,
    '2 chron': 14,
    '2 chronicles': 14,
    'ezra': 15,
    'neh': 16,
    'nehemiah': 16,
    'esth': 17,
    'esther': 17,
    'job': 18,
    'isa': 23,
    'isaiah': 23,
    'jer': 24,
    'jeremiah': 24,
    'lam': 25,
    'lamentations': 25,
    'ezek': 26,
    'ezekiel': 26,
    'dan': 27,
    'daniel': 27,
    'hos': 28,
    'hosea': 28,
    'joel': 29,
    'amos': 30,
    'obad': 31,
    'obadiah': 31,
    'jon': 32,
    'jonah': 32,
    'mic': 33,
    'micah': 33,
    'nah': 34,
    'nahum': 34,
    'hab': 35,
    'habakkuk': 35,
    'zeph': 36,
    'zephaniah': 36,
    'hag': 37,
    'haggai': 37,
    'zech': 38,
    'zechariah': 38,
    'mal': 39,
    'malachi': 39,
  };

  /// Fetches verses based on a string reference like "John 3:16", "1 Corinthians 13:4-8", "Psalm 1", or "Psalm 23"
  Future<List<BibleVerse>> getVerseByReference(String reference) async {
    final ref = reference.trim();
    if (ref.isEmpty) return [];

    // Combine canonical book names and aliases, sorted longest-first to match specific names first
    final Map<String, int> lookup = {};
    for (final b in kBibleBooks) {
      lookup[b.name.toLowerCase()] = b.number;
    }
    lookup.addAll(_bookAliases);

    final sortedKeys = lookup.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final lowerRef = ref.toLowerCase();
    for (final key in sortedKeys) {
      if (lowerRef.startsWith(key)) {
        final bookNumber = lookup[key]!;
        final remaining = ref.substring(key.length).trim();

        // 1. Check for Chapter:Verse or Chapter:Verse-Verse (e.g. 3:16 or 3:16-18)
        final matchRange = RegExp(r'^(\d+):(\d+)(?:-(\d+))?$').firstMatch(remaining);
        if (matchRange != null) {
          final chapter = int.tryParse(matchRange.group(1)!);
          final startVerse = int.tryParse(matchRange.group(2)!);
          final endVerse = matchRange.group(3) != null ? int.tryParse(matchRange.group(3)!) : startVerse;

          if (chapter != null && startVerse != null && endVerse != null) {
            final allVerses = await getVerses(bookNumber, chapter);
            return allVerses.where((v) => v.verse >= startVerse && v.verse <= endVerse).toList();
          }
        }

        // 2. Check for Chapter only (e.g. "Psalm 23", "Psalm 1", or "John 3")
        final matchChapter = RegExp(r'^(\d+)$').firstMatch(remaining);
        if (matchChapter != null) {
          final chapter = int.tryParse(matchChapter.group(1)!);
          if (chapter != null) {
            return await getVerses(bookNumber, chapter);
          }
        }
      }
    }
    return [];
  }

  /// Parses multi-reference raw text input into resolved BiblePlaylistItem instances
  Future<List<BiblePlaylistItem>> parseScriptureList(String rawInput) async {
    final references = extractScriptureReferences(rawInput);
    final List<BiblePlaylistItem> items = [];

    for (final ref in references) {
      final verses = await getVerseByReference(ref);
      if (verses.isNotEmpty) {
        final startRef = verses.first.reference;
        final displayTitle = verses.length > 1
            ? '${verses.first.bookName} ${verses.first.chapter}:${verses.first.verse}-${verses.last.verse}'
            : startRef;

        items.add(BiblePlaylistItem(
          reference: ref,
          displayTitle: displayTitle,
          verses: verses,
        ));
      }
    }
    return items;
  }

  /// Extracts individual scripture reference strings from freeform text or input
  List<String> extractScriptureReferences(String rawInput) {
    if (rawInput.trim().isEmpty) return [];

    final lines = rawInput.split(RegExp(r'[\n;\r]+'));
    final List<String> result = [];

    for (final line in lines) {
      final subTokens = line.split(',');
      for (final token in subTokens) {
        final cleaned = token.trim();
        if (cleaned.isNotEmpty) {
          result.add(cleaned);
        }
      }
    }
    return result;
  }

  Future<void> dispose() async {
    for (final db in _dbs.values) {
      await db.close();
    }
    _dbs.clear();
  }
}
