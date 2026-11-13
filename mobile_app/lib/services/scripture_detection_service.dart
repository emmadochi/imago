// lib/services/scripture_detection_service.dart
// Phase 1: Spoken Scripture Citation Detection & Parsing Engine
// Converts natural speech transcripts into validated DetectedScripture objects.
// 100% offline — no network required. Uses multi-pass regex and dictionary
// normalization to handle spoken English, ordinals, aliases, and context memory.

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bible_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

/// The result of a successful scripture citation detection from a spoken phrase.
class DetectedScripture {
  final BibleBook book;
  final int chapter;
  final int verse;

  /// Optional end verse for ranged citations: "verse 14 through 18"
  final int? endVerse;

  /// The raw spoken phrase that triggered this detection.
  final String rawSnippet;

  /// Confidence score [0.0 – 1.0]. Used by Auto Mode to suppress low-confidence results.
  final double confidence;

  /// True when chapter was inferred from context memory, not explicitly spoken.
  final bool chapterFromContext;

  DetectedScripture({
    required this.book,
    required this.chapter,
    required this.verse,
    this.endVerse,
    required this.rawSnippet,
    required this.confidence,
    this.chapterFromContext = false,
  });

  /// Human-readable formatted reference, e.g. "Romans 8:28" or "John 3:16-18"
  String get formattedRef {
    final base = '${book.name} $chapter:$verse';
    return endVerse != null ? '$base-$endVerse' : base;
  }

  @override
  String toString() =>
      'DetectedScripture($formattedRef, confidence: ${confidence.toStringAsFixed(2)})';
}

// ─────────────────────────────────────────────────────────────────────────────
// SPOKEN NUMBER NORMALIZER
// ─────────────────────────────────────────────────────────────────────────────

class _SpokenNumberNormalizer {
  static const Map<String, int> _ones = {
    'zero': 0, 'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5,
    'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
    'eleven': 11, 'twelve': 12, 'thirteen': 13, 'fourteen': 14,
    'fifteen': 15, 'sixteen': 16, 'seventeen': 17, 'eighteen': 18,
    'nineteen': 19, 'twenty': 20, 'thirty': 30, 'forty': 40,
    'fifty': 50, 'sixty': 60, 'seventy': 70, 'eighty': 80, 'ninety': 90,
    // Ordinals
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
    'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10,
    'eleventh': 11, 'twelfth': 12, 'thirteenth': 13, 'fourteenth': 14,
    'fifteenth': 15, 'sixteenth': 16, 'seventeenth': 17, 'eighteenth': 18,
    'nineteenth': 19, 'twentieth': 20, 'thirtieth': 30,
  };

  static const Map<String, int> _hundreds = {
    'hundred': 100, 'hundreds': 100,
  };

  static const Map<String, int> _ordinalPrefixes = {
    '1st': 1, '2nd': 2, '3rd': 3,
    '4th': 4, '5th': 5,
  };

  /// Attempts to parse a word sequence starting at [startIndex] as an English number.
  /// Returns a MapEntry(parsedInt, wordCount consumed) or null if no match.
  static MapEntry<int, int>? tryParseNumber(List<String> words, int startIndex) {
    if (startIndex >= words.length) return null;

    final word = words[startIndex];

    // Plain digit
    final digit = int.tryParse(word);
    if (digit != null) {
      // Handle split digit combos like "20 1" -> 21
      if (digit % 10 == 0 && startIndex + 1 < words.length) {
        final nextDigit = int.tryParse(words[startIndex + 1]);
        if (nextDigit != null && nextDigit >= 1 && nextDigit <= 9) {
          return MapEntry(digit + nextDigit, 2);
        }
      }
      return MapEntry(digit, 1);
    }

    // Ordinal shorthand: 1st, 2nd, 3rd
    if (_ordinalPrefixes.containsKey(word)) {
      return MapEntry(_ordinalPrefixes[word]!, 1);
    }

    // English word number
    if (!_ones.containsKey(word)) return null;

    int value = _ones[word]!;
    int consumed = 1;

    if (startIndex + 1 < words.length) {
      final next = words[startIndex + 1].replaceAll('-', '');
      if (_ones.containsKey(next) && _ones[next]! < 20) {
        if (value >= 20 && _ones[next]! < 10) {
          value += _ones[next]!;
          consumed++;
        }
      } else if (_hundreds.containsKey(next)) {
        value *= 100;
        consumed++;
        int afterIdx = startIndex + consumed;
        if (afterIdx < words.length && words[afterIdx] == 'and') {
          afterIdx++;
          consumed++;
        }
        if (afterIdx < words.length) {
          final remParsed = tryParseNumber(words, afterIdx);
          if (remParsed != null) {
            value += remParsed.key;
            consumed += remParsed.value;
          }
        }
      }
    }

    return MapEntry(value, consumed);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCRIPTURE DETECTION SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ScriptureDetectionService {
  ScriptureDetectionService._();
  static final ScriptureDetectionService instance = ScriptureDetectionService._();

  // Context memory: when a pastor says "look at verse 8", we remember
  // the last projected book and chapter to resolve it.
  BibleBook? _contextBook;
  int? _contextChapter;

  // Pending book memory: when a preacher mentions a book (e.g. "Turn to Galatians"),
  // pauses, and then says "chapter 2 verse 20", we resolve it across chunks.
  BibleBook? _pendingBook;
  DateTime? _pendingBookTime;

  /// Updates the context memory from the operator's current projector state.
  void updateContext(BibleBook? book, int? chapter) {
    _contextBook = book;
    _contextChapter = chapter;
  }

  /// Clears context memory.
  void clearContext() {
    _contextBook = null;
    _contextChapter = null;
  }

  /// Remembers a standalone book mention across preacher pauses for up to 25 seconds.
  void recordPendingBook(BibleBook book) {
    _pendingBook = book;
    _pendingBookTime = DateTime.now();
  }

  BibleBook? get activePendingBook {
    if (_pendingBook == null || _pendingBookTime == null) return null;
    if (DateTime.now().difference(_pendingBookTime!).inSeconds > 25) {
      _pendingBook = null;
      _pendingBookTime = null;
      return null;
    }
    return _pendingBook;
  }

  void clearPendingBook() {
    _pendingBook = null;
    _pendingBookTime = null;
  }

  // ── Book alias dictionary (spoken & written) ──────────────────────────────
  static final Map<String, int> _bookAliases = {
    'genesis': 1, 'gen': 1, 'ge': 1, 'gn': 1,
    'exodus': 2, 'exo': 2, 'exod': 2, 'ex': 2,
    'leviticus': 3, 'lev': 3, 'le': 3, 'lv': 3,
    'numbers': 4, 'num': 4, 'nu': 4, 'nm': 4, 'nb': 4,
    'deuteronomy': 5, 'deut': 5, 'de': 5, 'dt': 5,
    'joshua': 6, 'josh': 6, 'jos': 6, 'jsh': 6,
    'judges': 7, 'judg': 7, 'jdg': 7, 'jg': 7, 'jdgs': 7,
    'ruth': 8, 'rth': 8, 'ru': 8,
    'first samuel': 9, '1 samuel': 9, 'one samuel': 9, 'first sam': 9, '1sam': 9, '1sa': 9, '1s': 9,
    '1st samuel': 9, '1st sam': 9, 'i samuel': 9, 'i sam': 9,
    'second samuel': 10, '2 samuel': 10, 'two samuel': 10, 'second sam': 10, '2sam': 10, '2sa': 10, '2s': 10,
    '2nd samuel': 10, '2nd sam': 10, 'ii samuel': 10, 'ii sam': 10,
    'first kings': 11, '1 kings': 11, 'one kings': 11, '1kings': 11, '1ki': 11, '1k': 11,
    '1st kings': 11, '1st king': 11, 'i kings': 11, 'i king': 11,
    'second kings': 12, '2 kings': 12, 'two kings': 12, '2kings': 12, '2ki': 12, '2k': 12,
    '2nd kings': 12, '2nd king': 12, 'ii kings': 12, 'ii king': 12,
    'first chronicles': 13, '1 chronicles': 13, 'one chronicles': 13, '1chr': 13, '1ch': 13,
    '1st chronicles': 13, 'i chronicles': 13,
    'second chronicles': 14, '2 chronicles': 14, 'two chronicles': 14, '2chr': 14, '2ch': 14,
    '2nd chronicles': 14, 'ii chronicles': 14,
    'ezra': 15, 'ezr': 15,
    'nehemiah': 16, 'neh': 16, 'ne': 16,
    'esther': 17, 'est': 17, 'esth': 17, 'es': 17,
    'job': 18, 'jb': 18,
    'psalm': 19, 'psalms': 19, 'ps': 19, 'psa': 19, 'psm': 19, 'pss': 19,
    'proverbs': 20, 'prov': 20, 'prv': 20, 'pr': 20, 'pro': 20,
    'ecclesiastes': 21, 'eccl': 21, 'ecc': 21, 'ec': 21, 'ecclesiastis': 21,
    'song of solomon': 22, 'song of songs': 22, 'song': 22, 'songs': 22, 'sos': 22, 'canticles': 22, 'song of song': 22, 'songs of songs': 22, 'songs of solomon': 22,
    'isaiah': 23, 'isa': 23, 'is': 23, 'isiah': 23,
    'jeremiah': 24, 'jer': 24, 'je': 24, 'jr': 24,
    'lamentations': 25, 'lam': 25, 'la': 25,
    'ezekiel': 26, 'ezek': 26, 'eze': 26, 'ezk': 26,
    'daniel': 27, 'dan': 27, 'da': 27, 'dn': 27,
    'hosea': 28, 'hos': 28, 'ho': 28,
    'joel': 29, 'jl': 29,
    'amos': 30, 'am': 30,
    'obadiah': 31, 'obad': 31, 'ob': 31,
    'jonah': 32, 'jon': 32, 'jnh': 32,
    'micah': 33, 'mic': 33, 'mc': 33,
    'nahum': 34, 'nah': 34, 'na': 34,
    'habakkuk': 35, 'hab': 35, 'habakuk': 35, 'hbk': 35,
    'zephaniah': 36, 'zeph': 36, 'zep': 36, 'zp': 36,
    'haggai': 37, 'hag': 37, 'hg': 37,
    'zechariah': 38, 'zech': 38, 'zec': 38, 'zc': 38,
    'malachi': 39, 'mal': 39, 'ml': 39,
    'matthew': 40, 'matt': 40, 'mat': 40, 'mt': 40, 'mathew': 40,
    'mark': 41, 'mrk': 41, 'mk': 41, 'mr': 41,
    'luke': 42, 'luk': 42, 'lk': 42, 'lu': 42,
    'john': 43, 'jhn': 43, 'jn': 43, 'joh': 43,
    'acts': 44, 'act': 44, 'ac': 44, 'acts of the apostles': 44,
    'romans': 45, 'rom': 45, 'ro': 45, 'rm': 45, 'roman': 45,
    'first corinthians': 46, '1 corinthians': 46, 'one corinthians': 46, '1cor': 46, '1co': 46, '1c': 46,
    '1st corinthians': 46, '1st cor': 46, 'i corinthians': 46, 'i cor': 46, 'corinthian': 46, 'corinthians': 46,
    'second corinthians': 47, '2 corinthians': 47, 'two corinthians': 47, '2cor': 47, '2co': 47, '2c': 47,
    '2nd corinthians': 47, '2nd cor': 47, 'ii corinthians': 47, 'ii cor': 47,
    'galatians': 48, 'gal': 48, 'ga': 48, 'galatian': 48,
    'ephesians': 49, 'eph': 49, 'ep': 49, 'ephesian': 49,
    'philippians': 50, 'phil': 50, 'php': 50, 'pp': 50, 'phillipians': 50, 'philippian': 50,
    'colossians': 51, 'col': 51, 'cl': 51, 'colossian': 51,
    'first thessalonians': 52, '1 thessalonians': 52, 'one thessalonians': 52, '1thess': 52, '1th': 52,
    '1st thessalonians': 52, '1st thess': 52, 'i thessalonians': 52, 'i thess': 52, 'thessalonians': 52,
    'second thessalonians': 53, '2 thessalonians': 53, 'two thessalonians': 53, '2thess': 53, '2th': 53,
    '2nd thessalonians': 53, '2nd thess': 53, 'ii thessalonians': 53, 'ii thess': 53,
    'first timothy': 54, '1 timothy': 54, 'one timothy': 54, '1tim': 54, '1ti': 54, '1t': 54,
    '1st timothy': 54, '1st tim': 54, 'i timothy': 54, 'i tim': 54,
    'second timothy': 55, '2 timothy': 55, 'two timothy': 55, '2tim': 55, '2ti': 55, '2t': 55,
    '2nd timothy': 55, '2nd tim': 55, 'ii timothy': 55, 'ii tim': 55,
    'titus': 56, 'tit': 56, 'ti': 56,
    'philemon': 57, 'philem': 57, 'phm': 57, 'pm': 57,
    'hebrews': 58, 'heb': 58, 'he': 58, 'hebrew': 58,
    'james': 59, 'jas': 59, 'jm': 59, 'jam': 59,
    'first peter': 60, '1 peter': 60, 'one peter': 60, '1pet': 60, '1pe': 60, '1p': 60,
    '1st peter': 60, '1st pet': 60, 'i peter': 60, 'i pet': 60,
    'second peter': 61, '2 peter': 61, 'two peter': 61, '2pet': 61, '2pe': 61, '2p': 61,
    '2nd peter': 61, '2nd pet': 61, 'ii peter': 61, 'ii pet': 61,
    'first john': 62, '1 john': 62, 'one john': 62, '1john': 62, '1jn': 62, '1j': 62,
    '1st john': 62, '1st jn': 62, 'i john': 62, 'i jn': 62,
    'second john': 63, '2 john': 63, 'two john': 63, '2john': 63, '2jn': 63, '2j': 63,
    '2nd john': 63, '2nd jn': 63, 'ii john': 63, 'ii jn': 63,
    'third john': 64, '3 john': 64, 'three john': 64, '3john': 64, '3jn': 64, '3j': 64,
    '3rd john': 64, '3rd jn': 64, 'iii john': 64, 'iii jn': 64,
    'jude': 65, 'jud': 65, 'jd': 65,
    'revelation': 66, 'revelations': 66, 'rev': 66, 're': 66, 'apocalypse': 66,
  };

  static const Set<String> _stripWords = {
    'turn', 'with', 'me', 'your', 'bibles', 'bible', 'open',
    'read', 'reading', 'look', 'at', 'in', 'from', 'the', 'let',
    'us', 'see', 'what', 'says', 'written', 'is', 'it', 'that',
    'also', 'find', 'go', 'now', 'please', 'everyone',
    'scripture', 'reference', 'passage', 'text', 'book',
    'found', 'a', 'an', 'as',
  };

  static const Set<String> _chapterKeywords = {'chapter', 'ch', 'chap', 'chapters'};
  static const Set<String> _verseKeywords  = {'verse', 'verses', 'v', 'vs', 'ver'};
  static const Set<String> _throughKeywords = {'through', 'thru', 'till', 'until', 'to', 'and'};

  // ── Main Public API ───────────────────────────────────────────────────────

  /// Processes a rolling speech transcript and returns all citations detected.
  List<DetectedScripture> detect(String transcript) {
    if (transcript.trim().isEmpty) return [];
    final results = <DetectedScripture>[];
    final segments = _splitIntoSegments(transcript);
    for (final segment in segments) {
      final hit = _parseSegment(segment);
      if (hit != null) results.add(hit);
    }
    return results;
  }

  List<String> _splitIntoSegments(String transcript) {
    // Protect decimal notations (e.g. "Matthew 2.8" -> "Matthew 2:8")
    // and book abbreviations with dot (e.g. "1 Cor. 13:4" -> "1 Cor 13:4")
    // before sentence splitting so periods aren't treated as sentence cuts.
    final sanitized = transcript
        .replaceAllMapped(RegExp(r'(\d+)\.(\d+)'), (m) => '${m[1]}:${m[2]}')
        .replaceAllMapped(RegExp(r'\b([A-Za-z]{2,})\.\s*(\d+)'), (m) => '${m[1]} ${m[2]}');

    return sanitized
        .split(RegExp(r'[.!?;]+'))
        .map((s) => s.trim())
        .where((s) => s.length > 2)
        .toList();
  }

  DetectedScripture? _parseSegment(String segment) {
    String normalized = segment.toLowerCase()
        .replaceAll(RegExp(r'[,()"\x27\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Strategy 1: Inverted verse-first notation e.g. "verse 28 of Romans 8", "verse 16 of John chapter 3"
    final invertedResult = _tryInvertedCitation(normalized, segment);
    if (invertedResult != null) return invertedResult;

    // Strategy 2: Chapter-first notation e.g. "chapter 8 of Romans verse 28", "chapter 3 of John, verse 16"
    final chapterFirstResult = _tryChapterFirstCitation(normalized, segment);
    if (chapterFirstResult != null) return chapterFirstResult;

    // Strategy 3: Ordinal Psalm & Chapter notation e.g. "the 23rd Psalm", "the third chapter of Philippians verse 14"
    final ordinalResult = _tryOrdinalChapterAndPsalm(normalized, segment);
    if (ordinalResult != null) return ordinalResult;

    final spaceSeparated = normalized.replaceAll('-', ' ');

    // Strategy 4: Spoken Ordinal Psalm e.g. "the twenty third psalm", "the ninety first psalm"
    final spokenPsalmResult = _trySpokenOrdinalPsalm(spaceSeparated, segment);
    if (spokenPsalmResult != null) return spokenPsalmResult;

    // Strategy 5: Explicit digit notation  e.g. "John 3:16", "Romans 8 verse 28", "Psalm 23", "1 John 3:16-18"
    final digitResult = _tryDigitNotation(normalized, segment);
    if (digitResult != null) return digitResult;

    // Strategy 6: Fully spoken form e.g. "John chapter three verse sixteen", "Psalm twenty three"
    final spokenResult = _trySpokenForm(spaceSeparated, segment);
    if (spokenResult != null) return spokenResult;

    // Strategy 7: Pending Book citation across preacher pauses e.g. "Turn to Galatians... [pause] ...chapter 2 verse 20"
    final pendingResult = _tryPendingBookCitation(spaceSeparated, segment);
    if (pendingResult != null) return pendingResult;

    // Strategy 8: Context-memory verse-only e.g. "look at verse eight"
    final contextResult = _tryContextVerseOnly(spaceSeparated, segment);
    if (contextResult != null) return contextResult;

    // If no citation matched, check if this segment mentioned a standalone Bible book
    // so we remember it for the next chunk if the preacher paused.
    _checkAndRecordPendingBook(spaceSeparated);

    return null;
  }

  // ── Strategy 1: Digit Notation ────────────────────────────────────────────

  static final RegExp _digitPattern = RegExp(
    r'\b(?:(1|2|3|first|second|third|one|two|three|1st|2nd|3rd|i{1,3})\s+)?'
    r'((?:song\s+of\s+(?:solomon|songs))|[a-z]{2,})'
    r'(?:\s+(?:chapter|ch|chap))?'
    r'\s+(\d{1,3})'
    r'(?:'
      r'(?:\s*(?:[:\s]|(?:verse|verses|v|vs|ver)\s*)\s*)(\d{1,3})'
      r'(?:\s*(?:through|thru|to|-)\s*(\d{1,3}))?'
    r')?\b',
    caseSensitive: false,
  );

  DetectedScripture? _tryDigitNotation(String normalized, String raw) {
    final matches = _digitPattern.allMatches(normalized);
    for (final match in matches) {
      final prefixGroup = match.group(1);
      final rawBook = match.group(2)!;
      final bookString = prefixGroup != null && prefixGroup.trim().isNotEmpty
          ? '${prefixGroup.trim()} $rawBook'
          : rawBook;

      final bookNumber = _resolveBookName(bookString);
      if (bookNumber == null) continue;

      final chapter = int.tryParse(match.group(3) ?? '');
      if (chapter == null || chapter <= 0) continue;

      final verseGroup = match.group(4);
      final verse = verseGroup != null ? int.tryParse(verseGroup) : 1;
      if (verse == null || verse <= 0) continue;

      final endVerseGroup = match.group(5);
      final endVerse = endVerseGroup != null ? int.tryParse(endVerseGroup) : null;

      final book = kBibleBooks.firstWhere(
        (b) => b.number == bookNumber,
        orElse: () => kBibleBooks.first,
      );

      // Validate biblical chapter bounds
      final maxChapters = _maxChaptersForBook(bookNumber);
      if (chapter > maxChapters) continue;

      // Explicit verse provided gets 0.95; valid chapter-only gets 0.90
      final confidence = verseGroup != null ? 0.95 : 0.90;

      return DetectedScripture(
        book: book, chapter: chapter, verse: verse,
        endVerse: endVerse, rawSnippet: raw, confidence: confidence,
      );
    }
    return null;
  }

  // ── Strategy 2: Inverted Verse-First Notation ──────────────────────────────
  // e.g. "verse 28 of Romans 8", "verse 16 from John chapter 3", "verses 14 to 17 of Romans 8"
  static final RegExp _invertedPattern = RegExp(
    r'\b(?:verses?|v|vs|ver)\s+(\d{1,3})(?:\s*(?:through|thru|to|-)\s*(\d{1,3}))?\s+(?:of|in|from)\s+(?:(1|2|3|first|second|third|1st|2nd|3rd|i{1,3})\s+)?([a-z]{2,})(?:\s+(?:chapter|ch|chap))?\s+(\d{1,3})\b',
    caseSensitive: false,
  );

  DetectedScripture? _tryInvertedCitation(String normalized, String raw) {
    final match = _invertedPattern.firstMatch(normalized);
    if (match == null) return null;

    final verse = int.tryParse(match.group(1) ?? '');
    if (verse == null || verse <= 0) return null;

    final endVerse = int.tryParse(match.group(2) ?? '');

    final prefixGroup = match.group(3);
    final rawBook = match.group(4)!;
    final bookString = prefixGroup != null && prefixGroup.trim().isNotEmpty
        ? '${prefixGroup.trim()} $rawBook'
        : rawBook;

    final bookNumber = _resolveBookName(bookString);
    if (bookNumber == null) return null;

    final chapter = int.tryParse(match.group(5) ?? '');
    if (chapter == null || chapter <= 0) return null;

    final maxChapters = _maxChaptersForBook(bookNumber);
    if (chapter > maxChapters) return null;

    final book = kBibleBooks.firstWhere(
      (b) => b.number == bookNumber,
      orElse: () => kBibleBooks.first,
    );

    return DetectedScripture(
      book: book, chapter: chapter, verse: verse,
      endVerse: endVerse, rawSnippet: raw, confidence: 0.95,
    );
  }

  // ── Strategy 3: Chapter-First Citation ────────────────────────────────────
  // e.g. "chapter 8 of Romans verse 28", "chapter 3 of John, verse 16", "chapter 14 of John"
  static final RegExp _chapterFirstPattern = RegExp(
    r'\b(?:chapter|ch|chap)\s+(\d{1,3})\s+(?:of|in|from)\s+(?:(1|2|3|first|second|third|1st|2nd|3rd|i{1,3})\s+)?([a-z]{2,})(?:(?:\s*(?:[:\s]|(?:verse|verses|v|vs|ver)\s*)\s*)(\d{1,3})(?:\s*(?:through|thru|to|-)\s*(\d{1,3}))?)?\b',
    caseSensitive: false,
  );

  DetectedScripture? _tryChapterFirstCitation(String normalized, String raw) {
    final match = _chapterFirstPattern.firstMatch(normalized);
    if (match == null) return null;

    final chapter = int.tryParse(match.group(1) ?? '');
    if (chapter == null || chapter <= 0) return null;

    final prefixGroup = match.group(2);
    final rawBook = match.group(3)!;
    final bookString = prefixGroup != null && prefixGroup.trim().isNotEmpty
        ? '${prefixGroup.trim()} $rawBook'
        : rawBook;

    final bookNumber = _resolveBookName(bookString);
    if (bookNumber == null) return null;

    final maxChapters = _maxChaptersForBook(bookNumber);
    if (chapter > maxChapters) return null;

    final verseStr = match.group(4);
    final verse = verseStr != null ? (int.tryParse(verseStr) ?? 1) : 1;
    final endVerseStr = match.group(5);
    final endVerse = endVerseStr != null ? int.tryParse(endVerseStr) : null;

    final book = kBibleBooks.firstWhere(
      (b) => b.number == bookNumber,
      orElse: () => kBibleBooks.first,
    );

    return DetectedScripture(
      book: book,
      chapter: chapter,
      verse: verse,
      endVerse: endVerse,
      rawSnippet: raw,
      confidence: verseStr != null ? 0.95 : 0.90,
    );
  }

  // ── Strategy 4: Ordinal Psalm & Chapter Notation ───────────────────────────
  // e.g. "the 23rd Psalm", "the 23rd Psalm verse 4", "the third chapter of Philippians verse 14"
  static final RegExp _ordinalPsalmPattern = RegExp(
    r'\b(?:the\s+)?(\d{1,3})(?:st|nd|rd|th)?\s+(?:psalm|psalms)(?:(?:\s*(?:[:\s]|(?:verse|verses|v|vs|ver)\s*)\s*)(\d{1,3}))?\b',
    caseSensitive: false,
  );

  static final RegExp _ordinalChapterPattern = RegExp(
    r'\b(?:the\s+)?(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|\d{1,3}(?:st|nd|rd|th)?)\s+chapter\s+of\s+(?:(1|2|3|first|second|third|1st|2nd|3rd|i{1,3})\s+)?([a-z]{2,})(?:(?:\s*(?:at|and|comma|,)?\s*(?:the\s+)?(?:verse|verses|v|vs|ver)?\s*)(\d{1,3}))?\b',
    caseSensitive: false,
  );

  DetectedScripture? _tryOrdinalChapterAndPsalm(String normalized, String raw) {
    // 1. Ordinal Psalms: e.g. "the 23rd Psalm" or "the 23rd Psalm verse 4"
    final psalmMatch = _ordinalPsalmPattern.firstMatch(normalized);
    if (psalmMatch != null) {
      final psalmNumber = int.tryParse(psalmMatch.group(1) ?? '');
      if (psalmNumber != null && psalmNumber >= 1 && psalmNumber <= 150) {
        final book = kBibleBooks.firstWhere(
          (b) => b.number == 19,
          orElse: () => kBibleBooks.first,
        );
        final verseStr = psalmMatch.group(2);
        final verse = verseStr != null ? (int.tryParse(verseStr) ?? 1) : 1;
        return DetectedScripture(
          book: book, chapter: psalmNumber, verse: verse,
          rawSnippet: raw, confidence: verseStr != null ? 0.95 : 0.90,
        );
      }
    }

    // 2. Ordinal Chapter: e.g. "the third chapter of Philippians, verse 14"
    final chapMatch = _ordinalChapterPattern.firstMatch(normalized);
    if (chapMatch != null) {
      final chapStr = chapMatch.group(1)!.toLowerCase();
      final chapterParsed = _SpokenNumberNormalizer.tryParseNumber([chapStr], 0);
      final chapter = chapterParsed?.key ?? int.tryParse(chapStr.replaceAll(RegExp(r'[^\d]'), ''));
      if (chapter == null || chapter <= 0) return null;

      final prefixGroup = chapMatch.group(2);
      final rawBook = chapMatch.group(3)!;
      final bookString = prefixGroup != null && prefixGroup.trim().isNotEmpty
          ? '${prefixGroup.trim()} $rawBook'
          : rawBook;

      final bookNumber = _resolveBookName(bookString);
      if (bookNumber == null) return null;

      final maxChapters = _maxChaptersForBook(bookNumber);
      if (chapter > maxChapters) return null;

      final verseStr = chapMatch.group(4);
      final verse = verseStr != null ? (int.tryParse(verseStr) ?? 1) : 1;

      final book = kBibleBooks.firstWhere(
        (b) => b.number == bookNumber,
        orElse: () => kBibleBooks.first,
      );

      return DetectedScripture(
        book: book, chapter: chapter, verse: verse,
        rawSnippet: raw, confidence: verseStr != null ? 0.95 : 0.90,
      );
    }

    return null;
  }

  // ── Strategy 4: Spoken Ordinal Psalm ──────────────────────────────────────
  // e.g. "the twenty third psalm", "the ninety first psalm", "the twenty third psalm verse four"
  DetectedScripture? _trySpokenOrdinalPsalm(String normalized, String raw) {
    final match = RegExp(
      r'(?:psalm|psalms)(?:(?:\s*(?:verse|verses|v|vs|ver)\s*)(\d{1,3}|[a-z\s-]+))?\b',
      caseSensitive: false,
    ).firstMatch(normalized);

    if (match != null) {
      final beforePsalm = normalized.substring(0, match.start).trim().split(RegExp(r'\s+'));
      if (beforePsalm.isNotEmpty) {
        // Try parsing the number from the end of beforePsalm (e.g. ['twenty', 'third'])
        for (int i = 0; i < beforePsalm.length; i++) {
          final parsed = _SpokenNumberNormalizer.tryParseNumber(beforePsalm, i);
          if (parsed != null && i + parsed.value == beforePsalm.length) {
            final psalmNumber = parsed.key;
            if (psalmNumber >= 1 && psalmNumber <= 150) {
              final book = kBibleBooks.firstWhere((b) => b.number == 19, orElse: () => kBibleBooks.first);
              int verse = 1;
              final verseGroup = match.group(1);
              if (verseGroup != null && verseGroup.trim().isNotEmpty) {
                final directVerse = int.tryParse(verseGroup.trim());
                if (directVerse != null && directVerse > 0) {
                  verse = directVerse;
                } else {
                  final vWords = verseGroup.trim().split(RegExp(r'[\s-]+'));
                  final vParsed = _SpokenNumberNormalizer.tryParseNumber(vWords, 0);
                  if (vParsed != null && vParsed.key > 0) {
                    verse = vParsed.key;
                  }
                }
              }
              return DetectedScripture(
                book: book,
                chapter: psalmNumber,
                verse: verse,
                rawSnippet: raw,
                confidence: verseGroup != null ? 0.95 : 0.92,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ── Strategy 7: Pending Book Citation Across Pauses ─────────────────────────
  static final RegExp _pendingCitationPattern = RegExp(
    r'\b(?:(?:chapter|ch|chap)\s+)?(\d{1,3})\s*(?:[:\s]|(?:verse|verses|v|vs|ver)\s*)(\d{1,3})(?:\s*(?:through|thru|to|-)\s*(\d{1,3}))?\b',
    caseSensitive: false,
  );

  DetectedScripture? _tryPendingBookCitation(String normalized, String raw) {
    final book = activePendingBook;
    if (book == null) return null;

    final match = _pendingCitationPattern.firstMatch(normalized);
    if (match != null) {
      final chapter = int.tryParse(match.group(1) ?? '');
      final verse = int.tryParse(match.group(2) ?? '');
      if (chapter != null && verse != null && chapter > 0 && verse > 0) {
        final maxChapters = _maxChaptersForBook(book.number);
        if (chapter <= maxChapters) {
          final endVerse = int.tryParse(match.group(3) ?? '');
          clearPendingBook();
          return DetectedScripture(
            book: book, chapter: chapter, verse: verse,
            endVerse: endVerse, rawSnippet: raw, confidence: 0.92,
          );
        }
      }
    }

    // Also handle spoken words with pending book: e.g. "turn to chapter two verse twenty", "in chapter 2 verse 20"
    final words = normalized.split(RegExp(r'\s+'));
    int i = 0;
    while (i < words.length) {
      if (_chapterKeywords.contains(words[i])) {
        i++;
        break;
      }
      final numTest = _SpokenNumberNormalizer.tryParseNumber(words, i);
      if (numTest != null && numTest.key > 0) {
        break;
      }
      i++;
    }

    if (i < words.length) {
      final chapterParsed = _SpokenNumberNormalizer.tryParseNumber(words, i);
      if (chapterParsed != null && chapterParsed.key > 0) {
        final chapter = chapterParsed.key;
        i += chapterParsed.value;
        if (i < words.length && _verseKeywords.contains(words[i])) i++;
        final verseParsed = _SpokenNumberNormalizer.tryParseNumber(words, i);
        final verse = verseParsed != null ? verseParsed.key : 1;
        final maxChapters = _maxChaptersForBook(book.number);
        if (chapter <= maxChapters && verse > 0) {
          clearPendingBook();
          return DetectedScripture(
            book: book, chapter: chapter, verse: verse,
            rawSnippet: raw, confidence: 0.90,
          );
        }
      }
    }

    return null;
  }

  void _checkAndRecordPendingBook(String normalized) {
    final words = normalized.split(RegExp(r'\s+'));
    const ambiguousBooks = {'job', 'mark', 'acts', 'song', 'songs', 'am'};

    for (int i = 0; i < words.length; i++) {
      for (final windowSize in [3, 2, 1]) {
        if (i + windowSize > words.length) continue;
        final candidate = _normalizeOrdinalPrefix(words.sublist(i, i + windowSize).join(' '));
        final bookNumber = _resolveBookName(candidate);
        if (bookNumber != null) {
          if (ambiguousBooks.contains(candidate)) {
            final hasIndicator = i > 0 && {'book', 'of', 'in', 'to', 'from', 'read'}.contains(words[i - 1]);
            if (!hasIndicator) continue;
          }
          final book = kBibleBooks.firstWhere(
            (b) => b.number == bookNumber,
            orElse: () => kBibleBooks.first,
          );
          recordPendingBook(book);
          return;
        }
      }
    }
  }

  /// AI Semantic Extractor Fallback via Groq API (openai/gpt-oss-20b, ~800 tok/s).
  Future<DetectedScripture?> detectWithGroqAI(String transcript, String groqApiKey) async {
    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
      const prompt =
          'Extract Bible reference from spoken preaching. Return JSON: {"book": "<Canonical Book Name>", "chapter": <int>, "verse": <int>, "endVerse": <int or null>}. If none, return {"book": null}. Output valid JSON only.';

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $groqApiKey',
          'Content-Type': 'application/json',
          'User-Agent': 'Imago/1.0',
        },
        body: jsonEncode({
          'model': 'openai/gpt-oss-20b',
          'messages': [
            {'role': 'system', 'content': prompt},
            {'role': 'user', 'content': transcript},
          ],
          'temperature': 0.0,
          'response_format': {'type': 'json_object'},
        }),
      ).timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices']?[0]?['message']?['content'];
        if (content != null) {
          final parsed = jsonDecode(content);
          final bookName = parsed['book'] as String?;
          if (bookName != null && bookName.trim().isNotEmpty && bookName != 'null') {
            final bookNumber = _resolveBookName(bookName);
            final chapter = parsed['chapter'] as int?;
            final verse = (parsed['verse'] as int?) ?? 1;
            final endVerse = parsed['endVerse'] as int?;

            if (bookNumber != null && chapter != null && chapter > 0 && verse > 0) {
              final maxChaps = _maxChaptersForBook(bookNumber);
              if (chapter <= maxChaps) {
                final book = kBibleBooks.firstWhere(
                  (b) => b.number == bookNumber,
                  orElse: () => kBibleBooks.first,
                );
                return DetectedScripture(
                  book: book,
                  chapter: chapter,
                  verse: verse,
                  endVerse: endVerse,
                  rawSnippet: transcript,
                  confidence: 0.95,
                );
              }
            }
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Strategy 2: Fully Spoken Form ─────────────────────────────────────────

  DetectedScripture? _trySpokenForm(String normalized, String raw) {
    final rawWords = normalized.split(RegExp(r'\s+'));
    final words = rawWords.where((w) => w.isNotEmpty && !_stripWords.contains(w)).toList();
    if (words.length < 2) return null;

    int? bookNumber;
    int bookWordsConsumed = 0;
    int i = 0;

    // Scan forward to locate book name (handles conversational speech & preamble)
    while (i < words.length) {
      for (final windowSize in [4, 3, 2, 1]) {
        if (i + windowSize > words.length) continue;
        final candidate = _normalizeOrdinalPrefix(words.sublist(i, i + windowSize).join(' '));
        bookNumber = _resolveBookName(candidate);
        if (bookNumber != null) {
          bookWordsConsumed = windowSize;
          break;
        }
      }
      if (bookNumber != null) break;
      i++;
    }

    if (bookNumber == null) return null;
    i += bookWordsConsumed;
    if (i >= words.length) return null;

    int chapter = 0, verse = 0;
    int? endVerse;

    // Skip optional "chapter" keyword
    if (i < words.length && _chapterKeywords.contains(words[i])) i++;

    final chapterParsed = _SpokenNumberNormalizer.tryParseNumber(words, i);
    if (chapterParsed == null) return null;
    chapter = chapterParsed.key;
    i += chapterParsed.value;

    // Skip optional "verse" keyword
    bool explicitVerseSpoken = false;
    if (i < words.length && _verseKeywords.contains(words[i])) {
      explicitVerseSpoken = true;
      i++;
    }

    final verseParsed = _SpokenNumberNormalizer.tryParseNumber(words, i);
    if (verseParsed != null) {
      verse = verseParsed.key;
      i += verseParsed.value;
      explicitVerseSpoken = true;
    } else {
      verse = 1;
    }

    // Parse optional range: "through 18" or "to 18"
    if (i < words.length && _throughKeywords.contains(words[i])) {
      i++;
      final endParsed = _SpokenNumberNormalizer.tryParseNumber(words, i);
      if (endParsed != null) endVerse = endParsed.key;
    }

    final maxChapters = _maxChaptersForBook(bookNumber);
    if (chapter <= 0 || chapter > maxChapters || verse < 1) return null;

    final book = kBibleBooks.firstWhere(
      (b) => b.number == bookNumber,
      orElse: () => kBibleBooks.first,
    );

    // Spoken with verse: 0.90; valid spoken chapter-only: 0.88
    final confidence = explicitVerseSpoken ? 0.90 : 0.88;

    return DetectedScripture(
      book: book, chapter: chapter, verse: verse,
      endVerse: endVerse, rawSnippet: raw,
      confidence: confidence,
    );
  }

  // ── Strategy 3: Context-Memory Verse-Only ─────────────────────────────────

  DetectedScripture? _tryContextVerseOnly(String normalized, String raw) {
    if (_contextBook == null || _contextChapter == null) return null;

    final match = RegExp(r'\bverses?\s+(.+)').firstMatch(normalized);
    if (match == null) return null;

    final rest = match.group(1)!.trim().split(RegExp(r'\s+'));
    final verseParsed = _SpokenNumberNormalizer.tryParseNumber(rest, 0);
    if (verseParsed == null) return null;

    final verse = verseParsed.key;
    int? endVerse;
    int consumed = verseParsed.value;

    if (consumed < rest.length && _throughKeywords.contains(rest[consumed])) {
      consumed++;
      if (consumed < rest.length) {
        final endParsed = _SpokenNumberNormalizer.tryParseNumber(rest, consumed);
        if (endParsed != null) endVerse = endParsed.key;
      }
    }

    if (verse <= 0) return null;

    return DetectedScripture(
      book: _contextBook!, chapter: _contextChapter!, verse: verse,
      endVerse: endVerse, rawSnippet: raw, confidence: 0.90,
      chapterFromContext: true,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _normalizeOrdinalPrefix(String text) {
    return text
        .replaceAll(RegExp(r'^(?:first|1st|one|i)\s+', caseSensitive: false), '1 ')
        .replaceAll(RegExp(r'^(?:second|2nd|two|ii)\s+', caseSensitive: false), '2 ')
        .replaceAll(RegExp(r'^(?:third|3rd|three|iii)\s+', caseSensitive: false), '3 ')
        .trim();
  }

  int? _resolveBookName(String name) {
    final key = name.trim().toLowerCase();
    if (_bookAliases.containsKey(key)) return _bookAliases[key];
    // Prefix match fallback (min 3 chars) e.g. "corinth" -> Corinthians
    for (final entry in _bookAliases.entries) {
      if (entry.key.startsWith(key) && key.length >= 3) return entry.value;
    }
    return null;
  }

  /// Returns total chapters for biblical validation to prevent false positives.
  int _maxChaptersForBook(int bookNumber) {
    const chapters = {
      1: 50, 2: 40, 3: 27, 4: 36, 5: 34, 6: 24, 7: 21, 8: 4, 9: 31, 10: 24,
      11: 22, 12: 25, 13: 29, 14: 36, 15: 10, 16: 13, 17: 10, 18: 42, 19: 150, 20: 31,
      21: 12, 22: 8, 23: 66, 24: 52, 25: 5, 26: 48, 27: 12, 28: 14, 29: 3, 30: 9,
      31: 1, 32: 4, 33: 7, 34: 3, 35: 3, 36: 3, 37: 2, 38: 14, 39: 4, 40: 28,
      41: 16, 42: 24, 43: 21, 44: 28, 45: 16, 46: 16, 47: 13, 48: 6, 49: 6, 50: 4,
      51: 4, 52: 5, 53: 3, 54: 6, 55: 4, 56: 3, 57: 1, 58: 13, 59: 5, 60: 5,
      61: 3, 62: 5, 63: 1, 64: 1, 65: 1, 66: 22,
    };
    return chapters[bookNumber] ?? 150;
  }

  // ── Deduplication ─────────────────────────────────────────────────────────

  /// Filters detections to unique book/chapter/verse — highest confidence wins.
  static List<DetectedScripture> deduplicate(List<DetectedScripture> hits) {
    final Map<String, DetectedScripture> seen = {};
    for (final hit in hits) {
      final key = '${hit.book.number}_${hit.chapter}_${hit.verse}';
      if (!seen.containsKey(key) || hit.confidence > seen[key]!.confidence) {
        seen[key] = hit;
      }
    }
    return seen.values.toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }
}
