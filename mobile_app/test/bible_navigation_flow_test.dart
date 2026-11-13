import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/bible_models.dart';
import 'package:imago/screens/bible_screen.dart';

void main() {
  group('Bible 4-Tier Navigation Flow Tests (Book -> Chapter -> Verses -> Reader)', () {
    test('Standard books exist and have valid chapter counts', () {
      final genesis = kBibleBooks.firstWhere((b) => b.number == 1);
      expect(genesis.name, equals('Genesis'));
      expect(kStandardBookChapterCounts[1], equals(50));

      final john = kBibleBooks.firstWhere((b) => b.number == 43);
      expect(john.name, equals('John'));
      expect(kStandardBookChapterCounts[43], equals(21));
    });

    test('Verse count fallback is bounded and positive', () {
      final count = kStandardBookChapterCounts[66] ?? 1;
      expect(count, equals(22)); // Revelation has 22 chapters
    });

    test('BibleScreen.distractionFreeNotifier initial value is false and updates properly', () {
      expect(BibleScreen.distractionFreeNotifier.value, isFalse);
      BibleScreen.distractionFreeNotifier.value = true;
      expect(BibleScreen.distractionFreeNotifier.value, isTrue);
      BibleScreen.distractionFreeNotifier.value = false;
      expect(BibleScreen.distractionFreeNotifier.value, isFalse);
    });
  });
}
