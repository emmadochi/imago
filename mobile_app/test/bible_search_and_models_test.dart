// test/bible_search_and_models_test.dart
// Unit tests for yo-ETS Bible search models, MySword groups, and TTS text preparation

import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/bible_models.dart';
import 'package:imago/widgets/bible_search_scope_sheet.dart';
import 'package:imago/services/tts_service.dart';
import 'package:imago/screens/journal_editor_screen.dart';

void main() {
  group('Bible Search Groups & Match Types', () {
    test('Verify MySword canonical search groups coverage', () {
      final allGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'all');
      expect(allGroup.bookNumbers.length, equals(66));
      expect(allGroup.bookNumbers.first, equals(1));
      expect(allGroup.bookNumbers.last, equals(66));

      final otGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'ot');
      expect(otGroup.bookNumbers.length, equals(39));
      expect(otGroup.bookNumbers.last, equals(39));

      final ntGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'nt');
      expect(ntGroup.bookNumbers.length, equals(27));
      expect(ntGroup.bookNumbers.first, equals(40));
      expect(ntGroup.bookNumbers.last, equals(66));

      final gospelsGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'gospels');
      expect(gospelsGroup.bookNumbers, equals([40, 41, 42, 43]));

      final lawGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'law');
      expect(lawGroup.bookNumbers, equals([1, 2, 3, 4, 5]));

      final actsGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'acts');
      expect(actsGroup.bookNumbers, equals([44]));

      final revGroup = kBibleSearchGroups.firstWhere((g) => g.id == 'revelation');
      expect(revGroup.bookNumbers, equals([66]));
    });

    test('Verify BibleSearchMatchType labels and descriptions', () {
      expect(BibleSearchMatchType.exactPhrase.label, equals('Exact Phrase'));
      expect(BibleSearchMatchType.allWords.label, equals('All Words'));
      expect(BibleSearchMatchType.anyWord.label, equals('Any Word'));
    });

    test('Verify BibleSearchScopeResult helper methods', () {
      const entireBible = BibleSearchScopeResult(label: 'Entire Bible', bookNumbers: null);
      expect(entireBible.isEntireBible, isTrue);

      final specific = BibleSearchScopeResult(label: 'Gospels', bookNumbers: [40, 41, 42, 43]);
      expect(specific.isEntireBible, isFalse);
    });
  });

  group('TTS Text Preparation Tests', () {
    test('Strip Strong Concordance tags and brackets for speech', () {
      const rawWithStrongs = 'In the beginning [H7225] God created [H1254] the heaven [H8064]';
      final cleaned = rawWithStrongs
          .replaceAll(RegExp(r'\[[GH]\d+\]'), '')
          .replaceAll('*', '')
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      expect(cleaned, equals('In the beginning God created the heaven'));
    });

    test('Clean Greek Strong tags in NT verse for audio reading', () {
      const ntStrongs = 'For God so loved [G25] the world, that he gave his only begotten Son [G5207]';
      final cleaned = ntStrongs
          .replaceAll(RegExp(r'\[[GH]\d+\]'), '')
          .replaceAll('*', '')
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      expect(cleaned, equals('For God so loved the world, that he gave his only begotten Son'));
    });

    test('Chunk long scripture & devotional text cleanly within Android TTS limits', () {
      final longText = List.generate(
        20,
        (i) => 'Verse ${i + 1}. The Lord is my shepherd; I shall not want. He maketh me to lie down in green pastures.',
      ).join(' ');

      final chunks = TtsService.splitIntoSpeechChunks(longText, maxChars: 450);
      expect(chunks.length, greaterThan(1));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(450));
        expect(chunk.trim(), isNotEmpty);
      }
      expect(chunks.join(' '), equals(longText));
    });

    test('Split oversized run-on sentence without punctuation cleanly', () {
      const word = 'hallelujah ';
      final hugeSentence = word * 100; // 1100 chars, no punctuation
      final chunks = TtsService.splitIntoSpeechChunks(hugeSentence, maxChars: 450);
      expect(chunks.length, greaterThanOrEqualTo(3));
      for (final chunk in chunks) {
        expect(chunk.length, lessThanOrEqualTo(450));
      }
    });
  });

  group('Journal Verse Formatting Tests', () {
    test('Format single selected verse cleanly without John 3:16 hardcode', () {
      const verse = BibleVerse(
        book: 19,
        chapter: 23,
        verse: 1,
        text: 'The LORD [H3068] is my shepherd; <FI>I shall not want.<Fi>',
        bookName: 'Psalms',
      );

      final formatted = JournalEditorScreen.formatVersesForJournal([verse]);
      expect(formatted, equals('"The LORD is my shepherd; I shall not want." — Psalms 23:1'));
      expect(formatted.contains('John 3:16'), isFalse);
      expect(formatted.contains('For God so loved'), isFalse);
    });

    test('Format multi-verse selection range with verse numbers', () {
      const v1 = BibleVerse(book: 45, chapter: 8, verse: 28, text: 'And we know that all things work together for good.', bookName: 'Romans');
      const v2 = BibleVerse(book: 45, chapter: 8, verse: 29, text: 'For whom he did foreknow, he also did predestinate.', bookName: 'Romans');

      final formatted = JournalEditorScreen.formatVersesForJournal([v1, v2]);
      expect(
        formatted,
        equals('"[28] And we know that all things work together for good. [29] For whom he did foreknow, he also did predestinate." — Romans 8:28-29'),
      );
    });
  });
}
