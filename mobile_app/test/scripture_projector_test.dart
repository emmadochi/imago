// test/scripture_projector_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/screens/scripture_projector_screen.dart';
import 'package:imago/services/projector_broadcast_service.dart';
import 'package:imago/services/scripture_suggestion_service.dart';

void main() {
  group('ScriptureReferenceParser Tests', () {
    test('Parses standard reference with colon (John 3:16)', () {
      final parsed = ScriptureReferenceParser.parse('John 3:16');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 43); // John
      expect(parsed.chapter, 3);
      expect(parsed.verse, 16);
    });

    test('Parses space-delimited abbreviated reference (jn 3 16)', () {
      final parsed = ScriptureReferenceParser.parse('jn 3 16');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 43);
      expect(parsed.chapter, 3);
      expect(parsed.verse, 16);
    });

    test('Parses numbered book with space (1 cor 13 4)', () {
      final parsed = ScriptureReferenceParser.parse('1 cor 13 4');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 46); // 1 Corinthians
      expect(parsed.chapter, 13);
      expect(parsed.verse, 4);
    });

    test('Parses numbered book without space (2tim 1 7)', () {
      final parsed = ScriptureReferenceParser.parse('2tim 1 7');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 55); // 2 Timothy
      expect(parsed.chapter, 1);
      expect(parsed.verse, 7);
    });

    test('Parses Psalms shorthand (ps 23 1)', () {
      final parsed = ScriptureReferenceParser.parse('ps 23 1');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 19); // Psalms
      expect(parsed.chapter, 23);
      expect(parsed.verse, 1);
    });

    test('Parses Romans shorthand (rom 8 28)', () {
      final parsed = ScriptureReferenceParser.parse('rom 8 28');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 45); // Romans
      expect(parsed.chapter, 8);
      expect(parsed.verse, 28);
    });

    test('Parses Genesis shorthand (gen 1 1)', () {
      final parsed = ScriptureReferenceParser.parse('gen 1 1');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 1); // Genesis
      expect(parsed.chapter, 1);
      expect(parsed.verse, 1);
    });

    test('Parses chapter-only lookup defaults verse to 1 (Matt 5)', () {
      final parsed = ScriptureReferenceParser.parse('Matt 5');
      expect(parsed, isNotNull);
      expect(parsed!.book.number, 40); // Matthew
      expect(parsed.chapter, 5);
      expect(parsed.verse, 1);
    });

    test('Returns null for empty or invalid query', () {
      expect(ScriptureReferenceParser.parse(''), isNull);
      expect(ScriptureReferenceParser.parse('nonexistentbook 99 99'), isNull);
    });
  });

  group('Projector Theme Tests', () {
    test('Contains curated high-contrast church projection themes', () {
      expect(kProjectorThemes.length, greaterThanOrEqualTo(5));
      expect(kProjectorThemes.any((t) => t.id == 'midnight_gold'), isTrue);
      expect(kProjectorThemes.any((t) => t.id == 'worship_navy'), isTrue);
      expect(kProjectorThemes.any((t) => t.id == 'royal_crimson'), isTrue);
      expect(kProjectorThemes.any((t) => t.id == 'oled_black'), isTrue);
    });
  });

  group('ProjectorBroadcastService & Dual-Monitor Bus Tests', () {
    test('ProjectorBroadcastFrame copyWith preserves unmodified fields', () {
      const initial = ProjectorBroadcastFrame(
        bookName: 'Romans',
        chapter: 8,
        verseNumber: 28,
        themeId: 'worship_navy',
        isBlackout: false,
      );

      final updated = initial.copyWith(isBlackout: true, fontSize: 50.0);
      expect(updated.bookName, 'Romans');
      expect(updated.chapter, 8);
      expect(updated.verseNumber, 28);
      expect(updated.themeId, 'worship_navy');
      expect(updated.isBlackout, isTrue);
      expect(updated.fontSize, 50.0);
    });

    test('ProjectorBroadcastService broadcasts frame updates to listeners', () async {
      final broadcast = ProjectorBroadcastService.instance;
      const testFrame = ProjectorBroadcastFrame(
        bookName: 'Genesis',
        chapter: 1,
        verseNumber: 1,
        translation: 'KJV',
      );

      final expectation = expectLater(
        broadcast.frameStream,
        emits(predicate<ProjectorBroadcastFrame>((f) =>
            f.bookName == 'Genesis' && f.chapter == 1 && f.verseNumber == 1)),
      );

      broadcast.broadcast(testFrame);
      await expectation;
      expect(broadcast.currentFrame.bookName, 'Genesis');
    });

    test('ProjectorBroadcastService window status stream tracks stage window open/close', () async {
      final broadcast = ProjectorBroadcastService.instance;

      final expectation = expectLater(
        broadcast.windowStatusStream,
        emitsInOrder([true, false]),
      );

      broadcast.isStageWindowOpen = true;
      expect(broadcast.isStageWindowOpen, isTrue);

      broadcast.isStageWindowOpen = false;
      expect(broadcast.isStageWindowOpen, isFalse);

      await expectation;
    });

    test('ProjectorBroadcastService bidirectional hooks dispatch correctly', () {
      final broadcast = ProjectorBroadcastService.instance;
      bool nextCalled = false;
      bool prevCalled = false;
      bool blackoutCalled = false;
      bool clearCalled = false;

      broadcast.onNextVerse = () => nextCalled = true;
      broadcast.onPreviousVerse = () => prevCalled = true;
      broadcast.onToggleBlackout = () => blackoutCalled = true;
      broadcast.onToggleClear = () => clearCalled = true;

      broadcast.onNextVerse?.call();
      broadcast.onPreviousVerse?.call();
      broadcast.onToggleBlackout?.call();
      broadcast.onToggleClear?.call();

      expect(nextCalled, isTrue);
      expect(prevCalled, isTrue);
      expect(blackoutCalled, isTrue);
      expect(clearCalled, isTrue);

      // Clean up hooks
      broadcast.onNextVerse = null;
      broadcast.onPreviousVerse = null;
      broadcast.onToggleBlackout = null;
      broadcast.onToggleClear = null;
    });
  });
}
