// test/scripture_suggestion_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/services/scripture_suggestion_service.dart';

void main() {
  group('ScriptureReferenceParser Unit Tests', () {
    test('parses exact verse references with punctuation and spaces', () {
      final ref1 = ScriptureReferenceParser.parse('Jn 3:16');
      expect(ref1, isNotNull);
      expect(ref1!.book.number, equals(43)); // John
      expect(ref1.chapter, equals(3));
      expect(ref1.verse, equals(16));
      expect(ref1.hasExplicitChapter, isTrue);
      expect(ref1.hasExplicitVerse, isTrue);

      final ref2 = ScriptureReferenceParser.parse('rom 8 28');
      expect(ref2, isNotNull);
      expect(ref2!.book.number, equals(45)); // Romans
      expect(ref2.chapter, equals(8));
      expect(ref2.verse, equals(28));

      final ref3 = ScriptureReferenceParser.parse('2 tim 1:7');
      expect(ref3, isNotNull);
      expect(ref3!.book.number, equals(55)); // 2 Timothy
      expect(ref3.chapter, equals(1));
      expect(ref3.verse, equals(7));
    });

    test('parses chapter-only references properly', () {
      final ref = ScriptureReferenceParser.parse('Psalm 23');
      expect(ref, isNotNull);
      expect(ref!.book.number, equals(19)); // Psalms
      expect(ref.chapter, equals(23));
      expect(ref.hasExplicitChapter, isTrue);
      expect(ref.hasExplicitVerse, isFalse);
    });

    test('parses book-only prefixes properly', () {
      final ref = ScriptureReferenceParser.parse('Romans');
      expect(ref, isNotNull);
      expect(ref!.book.number, equals(45));
      expect(ref.hasExplicitChapter, isFalse);
      expect(ref.hasExplicitVerse, isFalse);
    });
  });
}
