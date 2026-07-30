import 'package:flutter_tts/flutter_tts.dart';

class AudioPronunciationService {
  AudioPronunciationService._();
  static final AudioPronunciationService instance = AudioPronunciationService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _isSpeaking = false;
  List<dynamic> _availableLanguages = [];

  bool get isSpeaking => _isSpeaking;

  Future<void> _init() async {
    if (_initialized) return;

    try {
      await _tts.setSpeechRate(0.42); // Clear, articulate speed for study
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
      });

      final languages = await _tts.getLanguages;
      if (languages is List) {
        _availableLanguages = languages;
      }
    } catch (_) {}

    _initialized = true;
  }

  /// Speaks a Greek, Hebrew, or English lexicon term
  Future<void> speak({
    required String term,
    String? translit,
    String? pron,
    required String type,
  }) async {
    await _init();

    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }

    String textToSpeak = '';
    String targetLang = 'en-US';

    final cleanType = type.toLowerCase();

    if (cleanType == 'greek') {
      final hasGreekVoice = _availableLanguages.any(
        (l) => l.toString().toLowerCase().contains('el') || l.toString().toLowerCase().contains('gr'),
      );

      if (hasGreekVoice) {
        targetLang = 'el-GR';
        textToSpeak = term.trim();
      } else {
        targetLang = 'en-US';
        textToSpeak = _formatPhonetic(pron ?? translit ?? term);
      }
    } else if (cleanType == 'hebrew') {
      final hasHebrewVoice = _availableLanguages.any(
        (l) => l.toString().toLowerCase().contains('he') || l.toString().toLowerCase().contains('iw'),
      );

      if (hasHebrewVoice) {
        targetLang = 'he-IL';
        textToSpeak = term.trim();
      } else {
        targetLang = 'en-US';
        textToSpeak = _formatPhonetic(pron ?? translit ?? term);
      }
    } else {
      targetLang = 'en-US';
      textToSpeak = term.trim();
    }

    try {
      await _tts.setLanguage(targetLang);
      await _tts.speak(textToSpeak);
    } catch (_) {
      try {
        await _tts.setLanguage('en-US');
        await _tts.speak(_formatPhonetic(pron ?? translit ?? term));
      } catch (_) {}
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _isSpeaking = false;
  }

  String _formatPhonetic(String text) {
    // Clean up accent marks and hyphens e.g. "ag-ah'-pay" -> "ag ah pay"
    return text.replaceAll("'", '').replaceAll('-', ' ').trim();
  }
}
