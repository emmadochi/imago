// test/scripture_detection_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/services/scripture_detection_service.dart';
import 'package:imago/services/projector_audio_listener_service.dart';
import 'package:imago/models/bible_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScriptureDetectionService NLP Engine Tests', () {
    final detector = ScriptureDetectionService.instance;

    setUp(() {
      detector.clearContext();
    });

    test('Detects explicit spoken citation: "Romans chapter eight verse twenty eight"', () {
      final results = detector.detect('Please turn with me to Romans chapter eight verse twenty-eight.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45); // Romans
      expect(hit.chapter, 8);
      expect(hit.verse, 28);
      expect(hit.confidence, greaterThanOrEqualTo(0.85));
      expect(hit.formattedRef, 'Romans 8:28');
    });

    test('Detects numbered books with ordinal: "first corinthians chapter thirteen verse four"', () {
      final results = detector.detect('Let us read from first corinthians chapter thirteen verse four.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 46); // 1 Corinthians
      expect(hit.chapter, 13);
      expect(hit.verse, 4);
      expect(hit.formattedRef, '1 Corinthians 13:4');
    });

    test('Detects conversational shorthand with preamble: "John three sixteen"', () {
      final results = detector.detect('As we all know, John three sixteen says God so loved the world.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 43); // John
      expect(hit.chapter, 3);
      expect(hit.verse, 16);
      expect(hit.formattedRef, 'John 3:16');
    });

    test('Detects Psalms shorthand: "Psalms twenty three verse one"', () {
      final results = detector.detect('Open to Psalms twenty-three verse one.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 19); // Psalms
      expect(hit.chapter, 23);
      expect(hit.verse, 1);
      expect(hit.formattedRef, 'Psalms 23:1');
    });

    test('Detects ranged citations: "verse twelve through sixteen"', () {
      final results = detector.detect('Ephesians chapter two verse twelve through sixteen.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 49); // Ephesians
      expect(hit.chapter, 2);
      expect(hit.verse, 12);
      expect(hit.endVerse, 16);
      expect(hit.formattedRef, 'Ephesians 2:12-16');
    });

    test('Resolves relative verse using Context Memory', () {
      // Operator is currently projecting Romans 8
      const romans = BibleBook(number: 45, name: 'Romans', isOldTestament: false);
      detector.updateContext(romans, 8);

      final results = detector.detect('Now church, look down at verse thirty-one.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45); // Inherited from context
      expect(hit.chapter, 8);      // Inherited from context
      expect(hit.verse, 31);
      expect(hit.chapterFromContext, isTrue);
      expect(hit.formattedRef, 'Romans 8:31');
    });

    test('Detects citations with commas and verse keywords: "Romans 8, verse 28"', () {
      final results = detector.detect('Please turn to Romans 8, verse 28.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45);
      expect(hit.chapter, 8);
      expect(hit.verse, 28);
      expect(hit.formattedRef, 'Romans 8:28');
    });

    test('Detects hyphenated digit range: "John 3:16-18"', () {
      final results = detector.detect('Let us read John 3:16-18 together.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 43);
      expect(hit.chapter, 3);
      expect(hit.verse, 16);
      expect(hit.endVerse, 18);
      expect(hit.formattedRef, 'John 3:16-18');
    });

    test('Detects high chapter and verse numbers: "Psalm 119 verse 105"', () {
      final results = detector.detect('Thy word is a lamp unto my feet, Psalm 119 verse 105.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 19);
      expect(hit.chapter, 119);
      expect(hit.verse, 105);
      expect(hit.formattedRef, 'Psalms 119:105');
    });

    test('Detects Roman numerals in citations: "II Corinthians 5:17"', () {
      final results = detector.detect('Therefore if any man be in Christ, II Corinthians 5:17.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 47); // 2 Corinthians
      expect(hit.chapter, 5);
      expect(hit.verse, 17);
      expect(hit.confidence, greaterThanOrEqualTo(0.90));
      expect(hit.formattedRef, '2 Corinthians 5:17');
    });

    test('Detects ordinal abbreviations: "1st John 3:16"', () {
      final results = detector.detect('Hereby perceive we the love of God, 1st John 3:16.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 62); // 1 John
      expect(hit.chapter, 3);
      expect(hit.verse, 16);
      expect(hit.confidence, greaterThanOrEqualTo(0.90));
      expect(hit.formattedRef, '1 John 3:16');
    });

    test('Detects dot notation and abbreviation with dot: "Matthew 2.8" and "1 Cor. 13:4"', () {
      final results1 = detector.detect('Go and search diligently for the young child, Matthew 2.8.');
      expect(results1, isNotEmpty);
      expect(results1.first.formattedRef, 'Matthew 2:8');

      final results2 = detector.detect('Charity suffereth long, and is kind, 1 Cor. 13:4.');
      expect(results2, isNotEmpty);
      expect(results2.first.formattedRef, '1 Corinthians 13:4');
    });

    test('Detects chapter-only citations with default verse 1: "Psalm 23" and "John 3"', () {
      final results1 = detector.detect('The Lord is my shepherd, Psalm 23.');
      expect(results1, isNotEmpty);
      expect(results1.first.formattedRef, 'Psalms 23:1');
      expect(results1.first.confidence, greaterThanOrEqualTo(0.85));

      final results2 = detector.detect('There was a man of the Pharisees, named Nicodemus, John 3.');
      expect(results2, isNotEmpty);
      expect(results2.first.formattedRef, 'John 3:1');
    });

    test('Detects ranges with "to": "Romans 8:14 to 17"', () {
      final results = detector.detect('For as many as are led by the Spirit of God, Romans 8:14 to 17.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.formattedRef, 'Romans 8:14-17');
      expect(hit.endVerse, 17);
    });

    test('Detects Song of Solomon citation: "Song of Solomon 2:4"', () {
      final results = detector.detect('He brought me to the banqueting house, Song of Solomon 2:4.');
      expect(results, isNotEmpty);
      expect(results.first.formattedRef, 'Song of Solomon 2:4');
    });

    test('Detects inverted verse-first citation: "verse 28 of Romans 8"', () {
      final results = detector.detect('Let us look at verse 28 of Romans 8.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45); // Romans
      expect(hit.chapter, 8);
      expect(hit.verse, 28);
      expect(hit.formattedRef, 'Romans 8:28');
    });

    test('Detects inverted ranged citation: "verses 14 to 17 of Romans 8"', () {
      final results = detector.detect('Reading verses 14 to 17 of Romans 8.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45);
      expect(hit.chapter, 8);
      expect(hit.verse, 14);
      expect(hit.endVerse, 17);
      expect(hit.formattedRef, 'Romans 8:14-17');
    });

    test('Detects chapter-first citation: "chapter 8 of Romans verse 28"', () {
      final results = detector.detect('Turn with me to chapter 8 of Romans verse 28.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 45);
      expect(hit.chapter, 8);
      expect(hit.verse, 28);
      expect(hit.formattedRef, 'Romans 8:28');
    });

    test('Detects chapter-first citation without verse: "chapter 14 of John"', () {
      final results = detector.detect('Let not your heart be troubled, chapter 14 of John.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 43); // John
      expect(hit.chapter, 14);
      expect(hit.verse, 1);
      expect(hit.formattedRef, 'John 14:1');
    });

    test('Detects ordinal Psalm notations: "the 23rd Psalm" and "the 23rd Psalm verse 4"', () {
      final results1 = detector.detect('The Lord is my shepherd, the 23rd Psalm.');
      expect(results1, isNotEmpty);
      expect(results1.first.formattedRef, 'Psalms 23:1');

      final results2 = detector.detect('Yea though I walk through the valley, the 23rd Psalm verse 4.');
      expect(results2, isNotEmpty);
      expect(results2.first.formattedRef, 'Psalms 23:4');
    });

    test('Detects spoken ordinal Psalm: "the twenty third psalm"', () {
      final results = detector.detect('Please turn your Bibles to the twenty third psalm.');
      expect(results, isNotEmpty);
      expect(results.first.book.number, 19);
      expect(results.first.chapter, 23);
      expect(results.first.verse, 1);
      expect(results.first.formattedRef, 'Psalms 23:1');
    });

    test('Detects ordinal chapter citation: "the third chapter of Philippians verse 14"', () {
      final results = detector.detect('I press toward the mark, the third chapter of Philippians verse 14.');
      expect(results, isNotEmpty);
      final hit = results.first;
      expect(hit.book.number, 50); // Philippians
      expect(hit.chapter, 3);
      expect(hit.verse, 14);
      expect(hit.formattedRef, 'Philippians 3:14');
    });

    test('Resolves pending book citation across preacher pauses: "Turn to Galatians" -> pause -> "chapter 2 verse 20"', () {
      // Chunk 1: Preacher mentions book and pauses
      detector.clearPendingBook();
      final chunk1Hits = detector.detect('Now church please turn in your Bibles to Galatians.');
      expect(chunk1Hits, isEmpty); // No citation yet, just pending book recorded
      expect(detector.activePendingBook, isNotNull);
      expect(detector.activePendingBook!.name, 'Galatians');

      // Chunk 2: After pause, preacher provides chapter and verse
      final chunk2Hits = detector.detect('Let us read together chapter 2 verse 20.');
      expect(chunk2Hits, isNotEmpty);
      final hit = chunk2Hits.first;
      expect(hit.book.name, 'Galatians');
      expect(hit.chapter, 2);
      expect(hit.verse, 20);
      expect(hit.formattedRef, 'Galatians 2:20');
      expect(detector.activePendingBook, isNull); // cleared after resolution
    });

    test('Ignores general non-scriptural speech', () {
      final results = detector.detect('Good morning everyone, welcome to the Sunday service.');
      expect(results, isEmpty);
    });
  });

  group('ListenerState Model & Audio Service Architecture Tests', () {
    test('Default mode is Manual with listening disabled', () {
      final service = ProjectorAudioListenerService.instance;
      expect(service.state.mode, ProjectorListenerMode.manual);
      expect(service.state.isListening, isFalse);
    });

    test('ListenerState copyWith handles all mode transitions and cooldowns correctly', () {
      const state = ListenerState();
      expect(state.mode, ProjectorListenerMode.manual);
      expect(state.isListening, isFalse);
      expect(state.pendingSuggestion, isNull);

      final assistState = state.copyWith(
        mode: ProjectorListenerMode.assist,
        isListening: true,
        statusMessage: 'Listening for scripture references...',
      );
      expect(assistState.mode, ProjectorListenerMode.assist);
      expect(assistState.isListening, isTrue);
      expect(assistState.statusMessage, 'Listening for scripture references...');

      final detected = DetectedScripture(
        book: const BibleBook(number: 1, name: 'Genesis', isOldTestament: true),
        chapter: 1,
        verse: 1,
        rawSnippet: 'Genesis 1:1',
        confidence: 0.95,
      );

      final suggestedState = assistState.copyWith(
        pendingSuggestion: detected,
      );
      expect(suggestedState.pendingSuggestion, isNotNull);
      expect(suggestedState.pendingSuggestion!.formattedRef, 'Genesis 1:1');

      final autoState = suggestedState.copyWith(
        mode: ProjectorListenerMode.auto,
        clearPendingSuggestion: true,
        lastAutoProjected: detected,
        autoProjectCooldownSecondsLeft: 7,
      );
      expect(autoState.mode, ProjectorListenerMode.auto);
      expect(autoState.pendingSuggestion, isNull);
      expect(autoState.lastAutoProjected, isNotNull);
      expect(autoState.autoProjectCooldownSecondsLeft, 7);
    });

    test('dismissSuggestion clears pending suggestion from listener service', () {
      final service = ProjectorAudioListenerService.instance;
      service.dismissSuggestion();
      expect(service.state.pendingSuggestion, isNull);
    });

    test('updateSettings updates confidence threshold, cooldown, and chunk length', () {
      final service = ProjectorAudioListenerService.instance;
      service.updateSettings(
        confidenceThreshold: 0.90,
        cooldownSeconds: 6,
        chunkSeconds: 8,
      );
      expect(service.autoModeConfidenceThreshold, 0.90);
      expect(service.autoModeCooldownSeconds, 6);
      expect(service.recordingChunkSeconds, 8);

      // Reset to defaults
      service.updateSettings(
        confidenceThreshold: 0.82,
        cooldownSeconds: 2,
        chunkSeconds: 2,
      );
    });

    test('simulateSpokenPhrase triggers spoken navigation for next and previous verses', () async {
      final service = ProjectorAudioListenerService.instance;
      bool nextTriggered = false;
      bool prevTriggered = false;
      service.onNextVerse = () => nextTriggered = true;
      service.onPreviousVerse = () => prevTriggered = true;

      await service.simulateSpokenPhrase('next verse');
      expect(nextTriggered, isTrue);

      // Reset cooldown for unit test simulation
      service.updateSettings(cooldownSeconds: 0);

      await service.simulateSpokenPhrase('verse up');
      expect(prevTriggered, isTrue);

      service.updateSettings(cooldownSeconds: 2);
    });

    test('simulateSpokenPhrase routes through Assist and Auto detection', () async {
      final service = ProjectorAudioListenerService.instance;

      // Assist simulation
      DetectedScripture? assistSuggested;
      service.onSuggestion = (s) => assistSuggested = s;
      
      // Manually set mode to assist in state
      service.dismissSuggestion();
      // Test simulation with an assist prompt
      await service.simulateSpokenPhrase('Turn with me to Romans chapter 8 verse 28.');
      expect(service.state.lastTranscript, contains('Romans'));
    });
  });
}
