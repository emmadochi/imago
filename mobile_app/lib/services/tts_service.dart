import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> _initTts() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for a calmer tone
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9); // Slightly lower pitch for pastoral feel
    
    // Attempt to set a high quality voice if available (iOS specific, or Google TTS on Android)
    // Fallback happens automatically
    
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    await _initTts();
    await _flutterTts.stop(); // Stop any ongoing speech
    
    // Clean up text (remove markdown asterisks, etc.)
    final cleanText = text.replaceAll('*', '');
    await _flutterTts.speak(cleanText);
  }

  Future<void> stop() async {
    if (!_isInitialized) return;
    await _flutterTts.stop();
  }
}
