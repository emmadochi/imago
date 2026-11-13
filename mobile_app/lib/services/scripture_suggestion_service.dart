// lib/services/scripture_suggestion_service.dart
// Intelligent As-You-Type Scripture Autocomplete & Suggestion Engine for yo-ETS
// Resolves fuzzy references, topical concepts, book key verses, and offline full-text phrase matches.

import 'dart:async';
import 'package:flutter/material.dart';

import '../data/topical_index.dart';
import '../models/bible_models.dart';
import 'bible_service.dart';

enum SuggestionKind {
  exactReference, // e.g. "John 3:16"
  chapterVerses,  // e.g. "John 3" -> 3:16, 3:3, 3:1
  bookPopular,    // e.g. "Romans" -> 8:28, 12:2
  topicMatch,     // e.g. "peace" -> John 14:27, Phil 4:7
  phraseMatch,    // e.g. "light of the world" -> Matt 5:14
}

class ScriptureSearchSuggestion {
  final BibleBook book;
  final int chapter;
  final int verse;
  final String reference;
  final String snippet;
  final SuggestionKind kind;
  final String badgeLabel;
  final Color badgeColor;

  const ScriptureSearchSuggestion({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.reference,
    required this.snippet,
    required this.kind,
    required this.badgeLabel,
    required this.badgeColor,
  });

  String get uniqueKey => '${book.number}:$chapter:$verse';
}

/// Smart Reference Parser for quick omnibar jumps like "jn 3 16", "rom 8:28", "2 tim 1 7"
class ScriptureReferenceParser {
  static final Map<String, int> bookAliases = {
    // Old Testament
    'gen': 1, 'genesis': 1, 'ge': 1, 'gn': 1,
    'exo': 2, 'exod': 2, 'exodus': 2, 'ex': 2,
    'lev': 3, 'leviticus': 3, 'le': 3, 'lv': 3,
    'num': 4, 'numbers': 4, 'nu': 4, 'nm': 4,
    'deut': 5, 'deuteronomy': 5, 'de': 5, 'dt': 5,
    'josh': 6, 'joshua': 6, 'jos': 6,
    'judg': 7, 'judges': 7, 'jdg': 7, 'jg': 7,
    'ruth': 8, 'ru': 8,
    '1 sam': 9, '1sam': 9, '1 samuel': 9, '1sa': 9,
    '2 sam': 10, '2sam': 10, '2 samuel': 10, '2sa': 10,
    '1 kgs': 11, '1kgs': 11, '1 kings': 11, '1ki': 11,
    '2 kgs': 12, '2kgs': 12, '2 kings': 12, '2ki': 12,
    '1 chr': 13, '1chr': 13, '1 chronicles': 13, '1ch': 13,
    '2 chr': 14, '2chr': 14, '2 chronicles': 14, '2ch': 14,
    'ezra': 15, 'ezr': 15,
    'neh': 16, 'nehemiah': 16,
    'est': 17, 'esther': 17,
    'job': 18, 'jb': 18,
    'ps': 19, 'psa': 19, 'psalm': 19, 'psalms': 19,
    'prov': 20, 'prv': 20, 'proverbs': 20, 'pr': 20,
    'eccl': 21, 'ecclesiastes': 21, 'ecc': 21,
    'song': 22, 'songs': 22, 'song of solomon': 22, 'sos': 22, 'canticles': 22,
    'isa': 23, 'isaiah': 23, 'is': 23,
    'jer': 24, 'jeremiah': 24, 'jr': 24,
    'lam': 25, 'lamentations': 25, 'la': 25,
    'ezek': 26, 'ezekiel': 26, 'eze': 26,
    'dan': 27, 'daniel': 27, 'dn': 27,
    'hos': 28, 'hosea': 28,
    'joel': 29, 'jl': 29,
    'amos': 30, 'am': 30,
    'obad': 31, 'obadiah': 31, 'ob': 31,
    'jonah': 32, 'jon': 32,
    'mic': 33, 'micah': 33,
    'nah': 34, 'nahum': 34,
    'hab': 35, 'habakkuk': 35,
    'zeph': 36, 'zephaniah': 36, 'zep': 36,
    'hag': 37, 'haggai': 37,
    'zech': 38, 'zechariah': 38, 'zec': 38,
    'mal': 39, 'malachi': 39,

    // New Testament
    'matt': 40, 'matthew': 40, 'mat': 40, 'mt': 40,
    'mark': 41, 'mrk': 41, 'mk': 41,
    'luke': 42, 'luk': 42, 'lk': 42,
    'john': 43, 'jhn': 43, 'jn': 43,
    'acts': 44, 'act': 44, 'ac': 44,
    'rom': 45, 'romans': 45, 'ro': 45, 'rm': 45,
    '1 cor': 46, '1cor': 46, '1 corinthians': 46, '1co': 46,
    '2 cor': 47, '2cor': 47, '2 corinthians': 47, '2co': 47,
    'gal': 48, 'galatians': 48, 'ga': 48,
    'eph': 49, 'ephesians': 49, 'ep': 49,
    'phil': 50, 'philippians': 50, 'php': 50,
    'col': 51, 'colossians': 51,
    '1 thess': 52, '1thess': 52, '1 th': 52, '1th': 52, '1 thessalonians': 52,
    '2 thess': 53, '2thess': 53, '2 th': 53, '2th': 53, '2 thessalonians': 53,
    '1 tim': 54, '1tim': 54, '1 ti': 54, '1ti': 54, '1 timothy': 54,
    '2 tim': 55, '2tim': 55, '2 ti': 55, '2ti': 55, '2 timothy': 55,
    'titus': 56, 'tit': 56,
    'philem': 57, 'philemon': 57, 'phm': 57,
    'heb': 58, 'hebrews': 58,
    'james': 59, 'jas': 59, 'jm': 59,
    '1 pet': 60, '1pet': 60, '1 pe': 60, '1pe': 60, '1 peter': 60,
    '2 pet': 61, '2pet': 61, '2 pe': 61, '2pe': 61, '2 peter': 61,
    '1 john': 62, '1john': 62, '1 jn': 62, '1jn': 62,
    '2 john': 63, '2john': 63, '2 jn': 63, '2jn': 63,
    '3 john': 64, '3john': 64, '3 jn': 64, '3jn': 64,
    'jude': 65, 'jud': 65,
    'rev': 66, 'revelation': 66, 'revelations': 66,
  };

  static ParsedScriptureRef? parse(String raw) {
    String q = raw.trim().toLowerCase();
    if (q.isEmpty) return null;

    // Normalizing punctuation: convert ':' or '.' or ',' into space
    q = q.replaceAll(RegExp(r'[:.,\-]'), ' ');
    final parts = q.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return null;

    int? bookNumber;
    int? chapter;
    int? verse;

    // Check for multi-word books like "1 cor", "2 tim", "song of solomon"
    if (parts.length >= 3 && bookAliases.containsKey('${parts[0]} ${parts[1]} ${parts[2]}')) {
      bookNumber = bookAliases['${parts[0]} ${parts[1]} ${parts[2]}'];
      if (parts.length > 3) chapter = int.tryParse(parts[3]);
      if (parts.length > 4) verse = int.tryParse(parts[4]);
    } else if (parts.length >= 2 && bookAliases.containsKey('${parts[0]} ${parts[1]}')) {
      bookNumber = bookAliases['${parts[0]} ${parts[1]}'];
      if (parts.length > 2) chapter = int.tryParse(parts[2]);
      if (parts.length > 3) verse = int.tryParse(parts[3]);
    } else if (bookAliases.containsKey(parts[0])) {
      bookNumber = bookAliases[parts[0]];
      if (parts.length > 1) chapter = int.tryParse(parts[1]);
      if (parts.length > 2) verse = int.tryParse(parts[2]);
    } else {
      // Direct prefix search among canonical book names
      for (final book in kBibleBooks) {
        if (book.name.toLowerCase().startsWith(parts[0])) {
          bookNumber = book.number;
          if (parts.length > 1) chapter = int.tryParse(parts[1]);
          if (parts.length > 2) verse = int.tryParse(parts[2]);
          break;
        }
      }
    }

    if (bookNumber == null) return null;

    final canonicalBook = kBibleBooks.firstWhere(
      (b) => b.number == bookNumber,
      orElse: () => kBibleBooks.first,
    );

    return ParsedScriptureRef(
      book: canonicalBook,
      chapter: chapter ?? 1,
      verse: verse ?? 1,
      hasExplicitChapter: chapter != null,
      hasExplicitVerse: verse != null,
    );
  }
}

class ParsedScriptureRef {
  final BibleBook book;
  final int chapter;
  final int verse;
  final bool hasExplicitChapter;
  final bool hasExplicitVerse;

  ParsedScriptureRef({
    required this.book,
    required this.chapter,
    required this.verse,
    this.hasExplicitChapter = true,
    this.hasExplicitVerse = true,
  });
}

/// Popular benchmark verses to suggest when an operator starts typing a book name or chapter
const Map<int, List<Map<String, int>>> kPopularBookVerses = {
  1: [{'c': 1, 'v': 1}, {'c': 1, 'v': 3}, {'c': 12, 'v': 2}], // Genesis
  19: [{'c': 23, 'v': 1}, {'c': 91, 'v': 1}, {'c': 119, 'v': 105}, {'c': 103, 'v': 1}], // Psalms
  20: [{'c': 3, 'v': 5}, {'c': 18, 'v': 10}, {'c': 27, 'v': 17}], // Proverbs
  23: [{'c': 40, 'v': 31}, {'c': 53, 'v': 5}, {'c': 41, 'v': 10}], // Isaiah
  24: [{'c': 29, 'v': 11}, {'c': 33, 'v': 3}], // Jeremiah
  40: [{'c': 5, 'v': 14}, {'c': 6, 'v': 33}, {'c': 28, 'v': 19}], // Matthew
  43: [{'c': 3, 'v': 16}, {'c': 1, 'v': 1}, {'c': 14, 'v': 6}, {'c': 10, 'v': 10}], // John
  44: [{'c': 1, 'v': 8}, {'c': 2, 'v': 38}, {'c': 16, 'v': 31}], // Acts
  45: [{'c': 8, 'v': 28}, {'c': 12, 'v': 2}, {'c': 8, 'v': 31}, {'c': 10, 'v': 9}], // Romans
  46: [{'c': 13, 'v': 4}, {'c': 13, 'v': 13}, {'c': 10, 'v': 13}], // 1 Cor
  47: [{'c': 5, 'v': 17}, {'c': 12, 'v': 9}], // 2 Cor
  48: [{'c': 5, 'v': 22}, {'c': 2, 'v': 20}], // Galatians
  49: [{'c': 2, 'v': 8}, {'c': 6, 'v': 10}], // Ephesians
  50: [{'c': 4, 'v': 13}, {'c': 4, 'v': 6}, {'c': 4, 'v': 19}], // Philippians
  51: [{'c': 3, 'v': 2}, {'c': 3, 'v': 15}], // Colossians
  55: [{'c': 1, 'v': 7}, {'c': 3, 'v': 16}], // 2 Timothy
  58: [{'c': 11, 'v': 1}, {'c': 12, 'v': 1}, {'c': 4, 'v': 12}], // Hebrews
  59: [{'c': 1, 'v': 2}, {'c': 1, 'v': 5}, {'c': 4, 'v': 7}], // James
  60: [{'c': 5, 'v': 7}, {'c': 2, 'v': 9}], // 1 Peter
  62: [{'c': 4, 'v': 8}, {'c': 1, 'v': 9}, {'c': 5, 'v': 14}], // 1 John
  66: [{'c': 21, 'v': 4}, {'c': 3, 'v': 20}], // Revelation
};

class ScriptureSuggestionService {
  ScriptureSuggestionService._();
  static final ScriptureSuggestionService instance = ScriptureSuggestionService._();

  int _queryCounter = 0;
  final Map<String, List<ScriptureSearchSuggestion>> _cache = {};

  /// Retrieves up to [maxResults] relevant suggestions for [rawQuery]
  Future<List<ScriptureSearchSuggestion>> getSuggestions(
    String rawQuery, {
    String? translation,
    int maxResults = 6,
  }) async {
    final query = rawQuery.trim();
    if (query.length < 2) return [];

    final cacheKey = '${translation ?? "default"}_$query';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    final int currentSeq = ++_queryCounter;
    final List<ScriptureSearchSuggestion> results = [];
    final Set<String> seenKeys = {};

    void addSuggestion(ScriptureSearchSuggestion s) {
      if (!seenKeys.contains(s.uniqueKey)) {
        seenKeys.add(s.uniqueKey);
        results.add(s);
      }
    }

    // ── Tier 1: Structured Scripture Reference Match ──────────────────────
    final parsed = ScriptureReferenceParser.parse(query);
    if (parsed != null) {
      final book = parsed.book;
      final int chapter = parsed.chapter;
      final int verse = parsed.verse;

      try {
        final chapterVerses = await BibleService.instance.getVerses(
          book.number,
          chapter,
          translationAbbreviation: translation,
        );

        if (chapterVerses.isNotEmpty) {
          if (parsed.hasExplicitVerse) {
            // Exact Verse Match
            final match = chapterVerses.firstWhere(
              (v) => v.verse == verse,
              orElse: () => chapterVerses.first,
            );
            addSuggestion(
              ScriptureSearchSuggestion(
                book: book,
                chapter: match.chapter,
                verse: match.verse,
                reference: '${book.name} ${match.chapter}:${match.verse}',
                snippet: match.text,
                kind: SuggestionKind.exactReference,
                badgeLabel: 'Reference',
                badgeColor: const Color(0xFF6366F1), // Indigo
              ),
            );

            // Context: Next Verse
            if (match.verse < chapterVerses.length) {
              final nextV = chapterVerses.firstWhere(
                (v) => v.verse == match.verse + 1,
                orElse: () => match,
              );
              if (nextV.verse != match.verse) {
                addSuggestion(
                  ScriptureSearchSuggestion(
                    book: book,
                    chapter: nextV.chapter,
                    verse: nextV.verse,
                    reference: '${book.name} ${nextV.chapter}:${nextV.verse}',
                    snippet: nextV.text,
                    kind: SuggestionKind.exactReference,
                    badgeLabel: 'Next Verse',
                    badgeColor: const Color(0xFF8B5CF6), // Violet
                  ),
                );
              }
            }
          } else if (parsed.hasExplicitChapter) {
            // Chapter only (e.g. "John 3", "Rom 8", "Psalm 23")
            // Prioritize famous verses within chapter if any, else first 3 verses
            final List<int> famousInChapter = [];
            if (book.number == 43 && chapter == 3) famousInChapter.addAll([16, 3, 17, 1]);
            if (book.number == 45 && chapter == 8) famousInChapter.addAll([28, 31, 1, 38]);
            if (book.number == 19 && chapter == 23) famousInChapter.addAll([1, 4, 6]);
            if (book.number == 46 && chapter == 13) famousInChapter.addAll([4, 13, 1]);
            if (book.number == 50 && chapter == 4) famousInChapter.addAll([13, 6, 19]);

            final Set<int> targetVerses = {};
            targetVerses.addAll(famousInChapter);
            targetVerses.add(1);
            targetVerses.add(2);

            for (final tv in targetVerses) {
              final found = chapterVerses.where((v) => v.verse == tv).toList();
              if (found.isNotEmpty) {
                final v = found.first;
                addSuggestion(
                  ScriptureSearchSuggestion(
                    book: book,
                    chapter: v.chapter,
                    verse: v.verse,
                    reference: '${book.name} ${v.chapter}:${v.verse}',
                    snippet: v.text,
                    kind: SuggestionKind.chapterVerses,
                    badgeLabel: famousInChapter.contains(v.verse) ? 'Key Passage' : 'Chapter ${v.chapter}',
                    badgeColor: const Color(0xFF8B5CF6),
                  ),
                );
              }
              if (results.length >= 4) break;
            }
          }
        }
      } catch (e) {
        // Fallback gracefully
      }
    }

    // ── Tier 2: Book Name Prefix Hints (e.g. "rom", "ps", "prov") ──────────
    if (parsed == null || (!parsed.hasExplicitChapter && !parsed.hasExplicitVerse)) {
      final lowerQ = query.toLowerCase();
      for (final book in kBibleBooks) {
        if (book.name.toLowerCase().startsWith(lowerQ) ||
            ScriptureReferenceParser.bookAliases.keys.any((k) => k.startsWith(lowerQ) && ScriptureReferenceParser.bookAliases[k] == book.number)) {
          final benchmarks = kPopularBookVerses[book.number];
          if (benchmarks != null) {
            for (final bm in benchmarks) {
              final ch = bm['c']!;
              final vs = bm['v']!;
              try {
                final verses = await BibleService.instance.getVerses(
                  book.number,
                  ch,
                  translationAbbreviation: translation,
                );
                final verseItem = verses.firstWhere(
                  (v) => v.verse == vs,
                  orElse: () => verses.isNotEmpty ? verses.first : BibleVerse(book: book.number, chapter: ch, verse: vs, text: '', bookName: book.name),
                );
                if (verseItem.text.isNotEmpty) {
                  addSuggestion(
                    ScriptureSearchSuggestion(
                      book: book,
                      chapter: ch,
                      verse: vs,
                      reference: '${book.name} $ch:$vs',
                      snippet: verseItem.text,
                      kind: SuggestionKind.bookPopular,
                      badgeLabel: 'Key Verse',
                      badgeColor: const Color(0xFF06B6D4), // Cyan
                    ),
                  );
                }
              } catch (_) {}
              if (results.length >= 3) break;
            }
          }
          break; // Stop after first matched book
        }
      }
    }

    // ── Tier 3: Semantic Topical Matches (e.g. "peace", "healing", "faith") ──
    final lower = query.toLowerCase();
    final matchingTopics = kTopicalIndex.keys.where((topic) {
      return topic == lower || topic.startsWith(lower) || lower.startsWith(topic);
    }).toList();

    for (final topic in matchingTopics) {
      final references = kTopicalIndex[topic] ?? [];
      for (final ref in references.take(3)) {
        try {
          final verses = await BibleService.instance.getVerseByReference(ref);
          if (verses.isNotEmpty) {
            final v = verses.first;
            final book = kBibleBooks.firstWhere(
              (b) => b.number == v.book,
              orElse: () => kBibleBooks.first,
            );
            addSuggestion(
              ScriptureSearchSuggestion(
                book: book,
                chapter: v.chapter,
                verse: v.verse,
                reference: '${v.bookName} ${v.chapter}:${v.verse}',
                snippet: v.text,
                kind: SuggestionKind.topicMatch,
                badgeLabel: 'Topic: ${topic.toUpperCase()}',
                badgeColor: const Color(0xFF10B981), // Emerald
              ),
            );
          }
        } catch (_) {}
        if (results.length >= maxResults) break;
      }
      if (results.length >= maxResults) break;
    }

    // ── Tier 4: Offline SQLite Full-Text Phrase Matching ───────────────────
    if (results.length < maxResults && query.length >= 3) {
      try {
        final matches = await BibleService.instance.search(
          query,
          limit: maxResults - results.length,
        );

        for (final m in matches) {
          final book = kBibleBooks.firstWhere(
            (b) => b.number == m.book,
            orElse: () => kBibleBooks.first,
          );
          addSuggestion(
            ScriptureSearchSuggestion(
              book: book,
              chapter: m.chapter,
              verse: m.verse,
              reference: '${m.bookName} ${m.chapter}:${m.verse}',
              snippet: m.text,
              kind: SuggestionKind.phraseMatch,
              badgeLabel: 'Phrase Match',
              badgeColor: const Color(0xFFF59E0B), // Amber
            ),
          );
        }
      } catch (_) {}
    }

    // Stale async result guard
    if (currentSeq != _queryCounter) {
      return [];
    }

    final trimmed = results.take(maxResults).toList();
    if (_cache.length > 50) _cache.clear();
    _cache[cacheKey] = trimmed;
    return trimmed;
  }

  void clearCache() {
    _cache.clear();
  }
}
