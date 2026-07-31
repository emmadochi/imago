import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isPlaying = false;
  String? _currentText;

  bool get isPlaying => _isPlaying;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for a calmer tone
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9); // Slightly lower pitch for pastoral feel
    
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      _currentText = null;
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      _currentText = null;
    });

    _flutterTts.setErrorHandler((msg) {
      _isPlaying = false;
      _currentText = null;
    });

    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await _initTts();
    if (_isPlaying) {
      await _flutterTts.stop();
    }
    
    _currentText = text;
    // Clean up text (remove markdown asterisks, curly braces, etc.)
    final cleanText = text.replaceAll('*', '').replaceAll('{', '').replaceAll('}', '');
    await _flutterTts.speak(cleanText);
  }

  Future<void> toggleSpeak(String text) async {
    if (_isPlaying && _currentText == text) {
      await stop();
    } else {
      await speak(text);
    }
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
    _isPlaying = false;
    _currentText = null;
  }
}
