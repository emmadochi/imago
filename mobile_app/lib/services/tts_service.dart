import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a specific, user-friendly text-to-speech voice
class TtsVoice {
  final String name; // Raw engine voice identifier, e.g. "en-us-x-sfg#female_1-local"
  final String locale; // e.g. "en-US"
  final String displayName; // e.g. "Aria (US English Female)"
  final String languageName; // e.g. "English (United States)"
  final String countryFlag; // e.g. "🇺🇸"
  final String gender; // "Female", "Male", or "Natural"
  final String quality; // "HD Studio", "Offline Voice", or "Standard"

  const TtsVoice({
    required this.name,
    required this.locale,
    required this.displayName,
    required this.languageName,
    required this.countryFlag,
    required this.gender,
    required this.quality,
  });

  Map<String, String> toMap() => {
        'name': name,
        'locale': locale,
        'displayName': displayName,
        'gender': gender,
      };

  static TtsVoice fromMap(Map<String, dynamic> raw) {
    final name = raw['name']?.toString() ?? 'System Voice';
    final locale = raw['locale']?.toString() ?? 'en-US';
    final lowerName = name.toLowerCase();
    final lowerLocale = locale.toLowerCase().replaceAll('_', '-');

    // 1. Detect Gender
    String gender = 'Natural';
    if (lowerName.contains('female') ||
        lowerName.contains('#f') ||
        lowerName.contains('zira') ||
        lowerName.contains('samantha') ||
        lowerName.contains('victoria') ||
        lowerName.contains('karen') ||
        lowerName.contains('moira') ||
        lowerName.contains('susan') ||
        lowerName.contains('hazel') ||
        lowerName.contains('catherine') ||
        raw['gender']?.toString().toLowerCase() == 'female') {
      gender = 'Female';
    } else if (lowerName.contains('male') ||
        lowerName.contains('#m') ||
        lowerName.contains('david') ||
        lowerName.contains('mark') ||
        lowerName.contains('george') ||
        lowerName.contains('alex') ||
        lowerName.contains('daniel') ||
        lowerName.contains('fred') ||
        lowerName.contains('james') ||
        lowerName.contains('oliver') ||
        lowerName.contains('arthur') ||
        raw['gender']?.toString().toLowerCase() == 'male') {
      gender = 'Male';
    }

    // 2. Country Flag & Language Name
    String flag = '🌐';
    String langName = 'English';
    if (lowerLocale.contains('en-us') || lowerLocale == 'en') {
      flag = '🇺🇸';
      langName = 'English (US)';
    } else if (lowerLocale.contains('en-gb') || lowerLocale.contains('en-uk')) {
      flag = '🇬🇧';
      langName = 'English (UK)';
    } else if (lowerLocale.contains('en-au')) {
      flag = '🇦🇺';
      langName = 'English (Australia)';
    } else if (lowerLocale.contains('en-ng')) {
      flag = '🇳🇬';
      langName = 'English (Nigeria)';
    } else if (lowerLocale.contains('en-in')) {
      flag = '🇮🇳';
      langName = 'English (India)';
    } else if (lowerLocale.contains('en-ca')) {
      flag = '🇨🇦';
      langName = 'English (Canada)';
    } else if (lowerLocale.contains('en-za')) {
      flag = '🇿🇦';
      langName = 'English (South Africa)';
    } else if (lowerLocale.contains('en-ie')) {
      flag = '🇮🇪';
      langName = 'English (Ireland)';
    } else if (lowerLocale.startsWith('es')) {
      flag = '🇪🇸';
      langName = 'Spanish';
    } else if (lowerLocale.startsWith('fr')) {
      flag = '🇫🇷';
      langName = 'French';
    } else if (lowerLocale.startsWith('de')) {
      flag = '🇩🇪';
      langName = 'German';
    } else if (lowerLocale.startsWith('pt')) {
      flag = '🇧🇷';
      langName = 'Portuguese';
    } else if (lowerLocale.startsWith('it')) {
      flag = '🇮🇹';
      langName = 'Italian';
    } else if (lowerLocale.startsWith('zh') || lowerLocale.startsWith('cmn')) {
      flag = '🇨🇳';
      langName = 'Chinese';
    } else if (lowerLocale.startsWith('ja')) {
      flag = '🇯🇵';
      langName = 'Japanese';
    } else if (lowerLocale.startsWith('ko')) {
      flag = '🇰🇷';
      langName = 'Korean';
    } else if (lowerLocale.startsWith('ar')) {
      flag = '🇸🇦';
      langName = 'Arabic';
    } else if (lowerLocale.startsWith('he')) {
      flag = '🇮🇱';
      langName = 'Hebrew';
    } else if (lowerLocale.startsWith('el')) {
      flag = '🇬🇷';
      langName = 'Greek';
    }

    // 3. Human-readable Display Name
    final displayName = _formatDisplayName(name, lowerLocale, gender, langName);

    // 4. Quality
    String quality = 'Standard';
    if (lowerName.contains('network') || lowerName.contains('high') || lowerName.contains('studio')) {
      quality = 'HD Studio';
    } else if (lowerName.contains('local')) {
      quality = 'Offline HD';
    }

    return TtsVoice(
      name: name,
      locale: locale,
      displayName: displayName,
      languageName: langName,
      countryFlag: flag,
      gender: gender,
      quality: quality,
    );
  }

  static String _formatDisplayName(String rawName, String lowerLocale, String gender, String langName) {
    // Windows desktop voice: e.g. "Microsoft David Desktop - English (United States)"
    if (rawName.startsWith('Microsoft ')) {
      final clean = rawName.replaceFirst('Microsoft ', '').replaceAll(' Desktop', '');
      final parts = clean.split(' - ');
      final voicePerson = parts.first.trim();
      return '$voicePerson ($langName $gender)';
    }

    // Apple / iOS voice: e.g. "Samantha", "Daniel", "Alex"
    if (!rawName.contains('-x-') && !rawName.contains('#') && !rawName.contains('.')) {
      return '$rawName ($langName $gender)';
    }

    // Android Google TTS with persona index: e.g. "en-us-x-sfg#female_1-local"
    final match = RegExp(r'#([a-zA-Z]+)_(\d+)').firstMatch(rawName);
    if (match != null) {
      final num = match.group(2);
      final idx = (int.tryParse(num ?? '1') ?? 1) - 1;
      final femalePersonas = ['Aria', 'Grace', 'Sophia', 'Clara', 'Emma', 'Faith', 'Hannah', 'Ruth'];
      final malePersonas = ['David', 'Gabriel', 'Samuel', 'Nathan', 'Arthur', 'Paul', 'John', 'Caleb'];
      final personaList = gender == 'Female' ? femalePersonas : malePersonas;
      final persona = (idx >= 0 && idx < personaList.length) ? personaList[idx] : 'Narrator $num';
      return '$persona ($langName $gender)';
    }

    // Android Google TTS short identifier: e.g. "en-us-x-sfg-local"
    final shortMatch = RegExp(r'-x-([a-zA-Z0-9]+)').firstMatch(rawName);
    if (shortMatch != null) {
      final code = shortMatch.group(1)!.toUpperCase();
      return '$gender Narrator $code ($langName)';
    }

    final lastPart = rawName.split('.').last.split('/').last;
    return '$lastPart ($langName)';
  }
}

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _bgAudioPlayer = AudioPlayer();
  final AudioPlayer _counselorAudioPlayer = AudioPlayer();

  final String _backendUrl = 'https://imago-1-wkzl.onrender.com';

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isPaused = false;
  String? _currentText;
  Completer<void>? _activeCompleter;
  int _currentUtteranceId = 0;

  // Audio Settings & Controls
  double _speedMultiplier = 1.0; // 0.5x to 2.0x
  double _pitch = 0.95; // 0.6 (Deep) to 1.4 (Bright)
  final double _volume = 1.0;
  String _ambientTrack = 'pad'; // 'pad', 'rain', 'drone', 'custom', 'none'
  double _ambientVolume = 0.08; // 0.0 to 1.0 (subtle background whisper by default)
  bool _isAmbientPlaying = false;

  Map<String, String>? _selectedVoice;
  List<Map<String, String>> _availableVoices = [];
  List<TtsVoice> _detailedVoices = [];

  // Custom User Device Audio Ambient
  String? _customAmbientPath;
  String? _customAmbientName;

  // Continuous Reading Mode (Audio Bible & Chunked Reading Plans/Devotionals)
  bool _isContinuousReading = false;
  bool _isChunkSequenceActive = false;
  int _speakSessionId = 0;
  List<String> _activeChunks = [];
  List<int> _activeSegmentIndices = [];
  int _activeChunkIndex = 0;
  bool _activeWithAmbient = true;
  String? _activeFullSourceText;
  void Function(int index)? _onChunkProgress;

  // Counselor Natural Voice Persona & Active State
  String _counselorVoice = 'en-US-ChristopherNeural';
  String? _counselorCurrentText;

  // Reactive ValueNotifiers
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentChunkIndexNotifier = ValueNotifier<int>(-1);
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<double> pitchNotifier = ValueNotifier<double>(0.95);
  final ValueNotifier<String> ambientTrackNotifier = ValueNotifier<String>('pad');
  final ValueNotifier<double> ambientVolumeNotifier = ValueNotifier<double>(0.08);
  final ValueNotifier<String?> selectedVoiceNameNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String?> customAmbientNameNotifier = ValueNotifier<String?>(null);

  final ValueNotifier<bool> isCounselorPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isCounselorPausedNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String?> counselorActiveTextNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String> counselorVoiceNotifier = ValueNotifier<String>('en-US-ChristopherNeural');

  bool get isPlaying => _isPlaying;
  bool get isPaused => _isPaused;
  bool get isAmbientPlaying => _isAmbientPlaying;
  bool get isContinuousReading => _isContinuousReading;
  bool get isCounselorPlaying => isCounselorPlayingNotifier.value;
  bool get isCounselorPaused => isCounselorPausedNotifier.value;
  String? get counselorActiveText => _counselorCurrentText;
  String get counselorVoice => _counselorVoice;
  double get speedMultiplier => _speedMultiplier;
  double get pitch => _pitch;
  double get volume => _volume;
  String get ambientTrack => _ambientTrack;
  double get ambientVolume => _ambientVolume;
  String? get customAmbientPath => _customAmbientPath;
  String? get customAmbientName => _customAmbientName;
  Map<String, String>? get selectedVoice => _selectedVoice;
  List<Map<String, String>> get availableVoices => _availableVoices;
  List<TtsVoice> get detailedVoices => _detailedVoices;

  static const Map<String, Map<String, String>> kCounselorPersonas = {
    'en-US-ChristopherNeural': {
      'name': 'Pastor Christopher',
      'title': 'Warm Pastoral (Male)',
      'country': '🇺🇸 US',
      'desc': 'Deep, compassionate, reverent pastoral voice',
    },
    'en-US-AvaNeural': {
      'name': 'Sister Ava',
      'title': 'Gentle Counselor (Female)',
      'country': '🇺🇸 US',
      'desc': 'Warm, empathetic, soothing companion voice',
    },
    'en-US-AndrewNeural': {
      'name': 'Pastor Andrew',
      'title': 'Reflective Counselor (Male)',
      'country': '🇺🇸 US',
      'desc': 'Grounded, thoughtful, caring pastoral guidance',
    },
    'en-US-JennyNeural': {
      'name': 'Sister Jenny',
      'title': 'Peaceful Counselor (Female)',
      'country': '🇺🇸 US',
      'desc': 'Calm, gentle, uplifting ministry tone',
    },
    'en-GB-RyanNeural': {
      'name': 'Pastor Ryan',
      'title': 'Reverent Counselor (Male)',
      'country': '🇬🇧 UK',
      'desc': 'Refined, biblical, British pastoral cadence',
    },
    'en-NG-EzinneNeural': {
      'name': 'Sister Ezinne',
      'title': 'Warm African Sister (Female)',
      'country': '🇳🇬 NG',
      'desc': 'Vibrant, comforting Nigerian sister in faith',
    },
    'en-NG-AbeoNeural': {
      'name': 'Pastor Abeo',
      'title': 'Uplifting African Pastor (Male)',
      'country': '🇳🇬 NG',
      'desc': 'Energetic, faith-filled Nigerian pastoral father',
    },
  };

  TtsVoice? get selectedDetailedVoice {
    if (_selectedVoice == null) return null;
    final name = _selectedVoice!['name'];
    return _detailedVoices.where((v) => v.name == name).firstOrNull;
  }

  static const Map<String, String> kAmbientTracks = {
    'pad': 'audio/sanctuary_pad.wav',
    'rain': 'audio/gentle_rain.wav',
    'drone': 'audio/deep_drone.wav',
  };

  static const Map<String, String> kAmbientTrackNames = {
    'pad': 'Sacred Atmosphere Pad',
    'rain': 'Gentle Living Waters',
    'drone': 'Deep 432Hz Prayer Drone',
    'custom': 'Custom Device Music',
    'none': 'None (Voice Only)',
  };

  /// Clean verse text thoroughly so TTS articulates smoothly without stumbling
  static String cleanForSpeech(String text) {
    if (text.isEmpty) return '';
    return text
        // Remove Strong's Concordance tags e.g. [G1234], [H5678], <G1234>, [1234]
        .replaceAll(RegExp(r'\[[GH]?\d+\]'), '')
        .replaceAll(RegExp(r'<[GH]?\d+>'), '')
        // Remove HTML/XML tags
        .replaceAll(RegExp(r'<[^>]+>'), '')
        // Clean common HTML entities
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', ' and ')
        .replaceAll('&lt;', '')
        .replaceAll('&gt;', '')
        .replaceAll('&nbsp;', ' ')
        // Remove footnotes, brackets, editorial symbols
        .replaceAll('*', '')
        .replaceAll('{', '')
        .replaceAll('}', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll('¶', '')
        .replaceAll('§', '')
        // Clean double quotation marks like `“"` or `”"` into single quotes
        .replaceAll(RegExp(r'["“”]+'), '"')
        // Convert em dashes to a natural pause
        .replaceAll('—', ', ')
        .replaceAll('--', ', ')
        // Normalize whitespace
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Splits long text into safe, sentence-boundary chunks well within
  /// Android/iOS TextToSpeech input limits (~4000 chars) so TTS never rejects or skips text.
  static List<String> splitIntoSpeechChunks(String rawText, {int maxChars = 450}) {
    final clean = cleanForSpeech(rawText);
    if (clean.isEmpty) return [];
    if (clean.length <= maxChars) return [clean];

    final sentences = clean.split(RegExp(r'(?<=[.!?])\s+'));
    final chunks = <String>[];
    final buffer = StringBuffer();

    for (final sentence in sentences) {
      final s = sentence.trim();
      if (s.isEmpty) continue;

      if (s.length > maxChars) {
        if (buffer.isNotEmpty) {
          chunks.add(buffer.toString().trim());
          buffer.clear();
        }
        // Further split oversized sentence along commas/spaces
        final words = s.split(' ');
        final wordBuf = StringBuffer();
        for (final w in words) {
          if (wordBuf.length + w.length + 1 > maxChars && wordBuf.isNotEmpty) {
            chunks.add(wordBuf.toString().trim());
            wordBuf.clear();
          }
          if (wordBuf.isNotEmpty) wordBuf.write(' ');
          wordBuf.write(w);
        }
        if (wordBuf.isNotEmpty) {
          chunks.add(wordBuf.toString().trim());
        }
        continue;
      }

      if (buffer.length + s.length + 1 > maxChars && buffer.isNotEmpty) {
        chunks.add(buffer.toString().trim());
        buffer.clear();
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(s);
    }

    if (buffer.isNotEmpty) {
      chunks.add(buffer.toString().trim());
    }
    return chunks;
  }

  Future<void> init() async {
    if (_isInitialized) return;
    await _loadPreferences();

    // Configure background ambient player to mix underneath TTS voice without stealing AudioFocus
    try {
      await _bgAudioPlayer.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: true,
            contentType: AndroidContentType.music,
            usageType: AndroidUsageType.media,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {AVAudioSessionOptions.mixWithOthers},
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error configuring ambient AudioContext: $e');
    }

    // Enable native speech completion where supported (Android, iOS, macOS)
    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
        await _flutterTts.awaitSpeakCompletion(true);
      }
    } catch (e) {
      debugPrint('awaitSpeakCompletion not supported on this platform: $e');
    }

    await _flutterTts.setLanguage("en-US");
    final ttsRate = (_speedMultiplier * 0.46).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(ttsRate);
    await _flutterTts.setVolume(_volume);
    await _flutterTts.setPitch(_pitch);

    if (_selectedVoice != null) {
      try {
        await _flutterTts.setVoice(_selectedVoice!);
      } catch (e) {
        debugPrint('Error applying selected voice during init: $e');
      }
    }

    // Set stable listeners once
    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      _isPaused = false;
      isPlayingNotifier.value = true;
      isPausedNotifier.value = false;
    });

    _flutterTts.setCompletionHandler(() {
      final wasStandalone = _activeCompleter == null;
      _isPlaying = false;
      if (!_isChunkSequenceActive) {
        _isPaused = false;
        isPlayingNotifier.value = false;
        isPausedNotifier.value = false;
      }
      _currentText = null;
      _completeActiveUtterance();
      if (wasStandalone && !_isContinuousReading && !_isChunkSequenceActive) {
        stopAmbient();
      }
    });

    _flutterTts.setCancelHandler(() {
      final wasStandalone = _activeCompleter == null;
      _isPlaying = false;
      if (!_isChunkSequenceActive) {
        _isPaused = false;
        isPlayingNotifier.value = false;
        isPausedNotifier.value = false;
      }
      _currentText = null;
      _completeActiveUtterance();
      if (wasStandalone && !_isContinuousReading && !_isChunkSequenceActive) {
        stopAmbient();
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('FlutterTts Error: $msg');
      final wasStandalone = _activeCompleter == null;
      _isPlaying = false;
      if (!_isChunkSequenceActive) {
        _isPaused = false;
        isPlayingNotifier.value = false;
        isPausedNotifier.value = false;
      }
      _currentText = null;
      _completeActiveUtterance();
      if (wasStandalone && !_isContinuousReading && !_isChunkSequenceActive) {
        stopAmbient();
      }
    });

    _counselorAudioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.playing) {
        isCounselorPlayingNotifier.value = true;
        isCounselorPausedNotifier.value = false;
      } else if (state == PlayerState.paused) {
        isCounselorPlayingNotifier.value = false;
        isCounselorPausedNotifier.value = true;
      } else if (state == PlayerState.completed || state == PlayerState.stopped) {
        isCounselorPlayingNotifier.value = false;
        isCounselorPausedNotifier.value = false;
        if (state == PlayerState.completed) {
          _counselorCurrentText = null;
          counselorActiveTextNotifier.value = null;
        }
      }
    });

    _counselorAudioPlayer.onPlayerComplete.listen((_) {
      isCounselorPlayingNotifier.value = false;
      isCounselorPausedNotifier.value = false;
      _counselorCurrentText = null;
      counselorActiveTextNotifier.value = null;
    });

    await _loadVoices();
    _isInitialized = true;
  }

  void _completeActiveUtterance() {
    if (_activeCompleter != null && !_activeCompleter!.isCompleted) {
      _activeCompleter!.complete();
    }
    _activeCompleter = null;
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speedMultiplier = prefs.getDouble('audio_speech_rate') ?? 1.0;
      _pitch = prefs.getDouble('audio_pitch') ?? 0.95;
      _ambientTrack = prefs.getString('audio_ambient_track') ?? 'pad';

      final savedVol = prefs.getDouble('audio_ambient_volume');
      // If not set or if set to the old loud default (0.25), use the well-reduced default (0.08)
      if (savedVol == null || savedVol == 0.25) {
        _ambientVolume = 0.08;
      } else {
        _ambientVolume = savedVol;
      }

      final voiceName = prefs.getString('audio_voice_name');
      final voiceLocale = prefs.getString('audio_voice_locale');
      if (voiceName != null && voiceLocale != null && voiceName.isNotEmpty) {
        _selectedVoice = {'name': voiceName, 'locale': voiceLocale};
      }

      _customAmbientPath = prefs.getString('audio_custom_ambient_path');
      _customAmbientName = prefs.getString('audio_custom_ambient_name');
      customAmbientNameNotifier.value = _customAmbientName;

      _counselorVoice = prefs.getString('counselor_voice_persona') ?? 'en-US-ChristopherNeural';
      counselorVoiceNotifier.value = _counselorVoice;

      speedNotifier.value = _speedMultiplier;
      pitchNotifier.value = _pitch;
      ambientTrackNotifier.value = _ambientTrack;
      ambientVolumeNotifier.value = _ambientVolume;
      selectedVoiceNameNotifier.value = _selectedVoice?['name'];
    } catch (e) {
      debugPrint('Error loading audio prefs: $e');
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('audio_speech_rate', _speedMultiplier);
      await prefs.setDouble('audio_pitch', _pitch);
      await prefs.setString('audio_ambient_track', _ambientTrack);
      await prefs.setDouble('audio_ambient_volume', _ambientVolume);
      if (_selectedVoice != null) {
        await prefs.setString('audio_voice_name', _selectedVoice!['name'] ?? '');
        await prefs.setString('audio_voice_locale', _selectedVoice!['locale'] ?? '');
      }
      if (_customAmbientPath != null) {
        await prefs.setString('audio_custom_ambient_path', _customAmbientPath!);
      }
      if (_customAmbientName != null) {
        await prefs.setString('audio_custom_ambient_name', _customAmbientName!);
      }
    } catch (e) {
      debugPrint('Error saving audio prefs: $e');
    }
  }

  Future<List<Map<String, String>>> _loadVoices() async {
    if (_availableVoices.isNotEmpty) return _availableVoices;
    try {
      final dynamic raw = await _flutterTts.getVoices;
      if (raw is List) {
        final voices = <Map<String, String>>[];
        final detailed = <TtsVoice>[];

        for (var v in raw) {
          if (v is Map) {
            final name = v['name']?.toString() ?? '';
            final locale = v['locale']?.toString() ?? '';
            if (name.isNotEmpty) {
              final map = {'name': name, 'locale': locale};
              voices.add(map);
              detailed.add(TtsVoice.fromMap(Map<String, dynamic>.from(v)));
            }
          }
        }

        // Sort: English voices first, then group by country / locale
        detailed.sort((a, b) {
          final aIsEn = a.locale.toLowerCase().startsWith('en');
          final bIsEn = b.locale.toLowerCase().startsWith('en');
          if (aIsEn && !bIsEn) return -1;
          if (!aIsEn && bIsEn) return 1;

          // Prefer US, UK, Australia next
          final aIsUS = a.locale.toLowerCase().contains('us');
          final bIsUS = b.locale.toLowerCase().contains('us');
          if (aIsUS && !bIsUS) return -1;
          if (!aIsUS && bIsUS) return 1;

          return a.displayName.compareTo(b.displayName);
        });

        _availableVoices = voices;
        _detailedVoices = detailed;

        // If no voice selected yet, pick a top English voice (preferring HD Studio / Neural)
        if (_selectedVoice == null && detailed.isNotEmpty) {
          final defaultVoice = detailed.firstWhere(
            (v) => (v.quality == 'HD Studio' || v.quality == 'Offline HD') && v.locale.toLowerCase().startsWith('en'),
            orElse: () => detailed.firstWhere(
              (v) => v.locale.toLowerCase().startsWith('en'),
              orElse: () => detailed.first,
            ),
          );
          _selectedVoice = defaultVoice.toMap();
          selectedVoiceNameNotifier.value = defaultVoice.name;
        }
      }
    } catch (e) {
      debugPrint('Error loading TTS voices: $e');
    }
    return _availableVoices;
  }

  Future<List<Map<String, String>>> getVoices() async {
    await init();
    return _availableVoices.isNotEmpty ? _availableVoices : await _loadVoices();
  }

  Future<List<TtsVoice>> getDetailedVoices() async {
    await init();
    if (_detailedVoices.isEmpty) {
      await _loadVoices();
    }
    return _detailedVoices;
  }

  Future<void> setSpeechRate(double speed) async {
    await init();
    _speedMultiplier = speed.clamp(0.5, 2.0);
    speedNotifier.value = _speedMultiplier;
    final ttsRate = (_speedMultiplier * 0.46).clamp(0.1, 1.0);
    await _flutterTts.setSpeechRate(ttsRate);
    _savePreferences();
  }

  Future<void> setPitch(double pitchVal) async {
    await init();
    _pitch = pitchVal.clamp(0.5, 1.6);
    pitchNotifier.value = _pitch;
    await _flutterTts.setPitch(_pitch);
    _savePreferences();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    await init();
    _selectedVoice = voice;
    selectedVoiceNameNotifier.value = voice['name'];
    try {
      await _flutterTts.setVoice(voice);
    } catch (e) {
      debugPrint('Error setting voice: $e');
    }
    _savePreferences();
  }

  Future<void> setDetailedVoice(TtsVoice voice) async {
    await setVoice(voice.toMap());
  }

  Future<void> setAmbientTrack(String track) async {
    _ambientTrack = track;
    ambientTrackNotifier.value = track;
    _savePreferences();
    if (track == 'none' || _ambientVolume <= 0.001) {
      await stopAmbient();
    } else if (_isPlaying && !_isPaused) {
      await startAmbient();
    }
  }

  Future<void> setCustomAmbientTrack(String filePath, String fileName) async {
    _customAmbientPath = filePath;
    _customAmbientName = fileName;
    _ambientTrack = 'custom';
    ambientTrackNotifier.value = 'custom';
    customAmbientNameNotifier.value = fileName;
    _savePreferences();
    if (_ambientVolume <= 0.001) {
      await stopAmbient();
    } else if (_isPlaying && !_isPaused) {
      await startAmbient();
    }
  }

  Future<void> setAmbientVolume(double volume) async {
    _ambientVolume = volume.clamp(0.0, 1.0);
    ambientVolumeNotifier.value = _ambientVolume;
    if (_ambientVolume <= 0.001) {
      await stopAmbient();
    } else {
      await _bgAudioPlayer.setVolume(_ambientVolume);
      if (_isPlaying && !_isPaused && !_isAmbientPlaying && _ambientTrack != 'none') {
        await startAmbient();
      }
    }
    _savePreferences();
  }

  Future<void> startAmbient() async {
    if (_ambientTrack == 'none' || _ambientVolume <= 0.001) {
      await stopAmbient();
      return;
    }
    try {
      await _bgAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgAudioPlayer.setVolume(_ambientVolume);

      if (_ambientTrack == 'custom') {
        if (_customAmbientPath != null && File(_customAmbientPath!).existsSync()) {
          await _bgAudioPlayer.play(DeviceFileSource(_customAmbientPath!));
          _isAmbientPlaying = true;
        } else {
          debugPrint('Custom ambient file not found: $_customAmbientPath');
        }
        return;
      }

      final assetPath = kAmbientTracks[_ambientTrack];
      if (assetPath == null) return;
      await _bgAudioPlayer.play(AssetSource(assetPath));
      _isAmbientPlaying = true;
    } catch (e) {
      debugPrint('Error playing ambient audio: $e');
    }
  }

  Future<void> stopAmbient() async {
    try {
      await _bgAudioPlayer.stop();
      _isAmbientPlaying = false;
    } catch (e) {
      debugPrint('Error stopping ambient audio: $e');
    }
  }

  Future<void> pauseAmbient() async {
    try {
      await _bgAudioPlayer.pause();
      _isAmbientPlaying = false;
    } catch (_) {}
  }

  Future<void> resumeAmbient() async {
    if (_ambientTrack == 'none' || _ambientVolume <= 0.001) {
      await stopAmbient();
      return;
    }
    try {
      if (_isAmbientPlaying) return;
      await _bgAudioPlayer.resume();
      _isAmbientPlaying = true;
    } catch (_) {
      await startAmbient();
    }
  }

  Future<void> previewAmbient(String track, double volume) async {
    if (track == 'none' || volume <= 0.001) {
      await stopAmbient();
      return;
    }
    try {
      await _bgAudioPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgAudioPlayer.setVolume(volume);

      if (track == 'custom') {
        if (_customAmbientPath != null && File(_customAmbientPath!).existsSync()) {
          await _bgAudioPlayer.play(DeviceFileSource(_customAmbientPath!));
          _isAmbientPlaying = true;
        }
        return;
      }

      final assetPath = kAmbientTracks[track];
      if (assetPath == null) return;
      await _bgAudioPlayer.play(AssetSource(assetPath));
      _isAmbientPlaying = true;
    } catch (e) {
      debugPrint('Error previewing ambient track: $e');
    }
  }

  Future<void> speak(String text, {bool withAmbient = true}) async {
    final clean = cleanForSpeech(text);
    if (clean.isEmpty) return;

    final chunks = splitIntoSpeechChunks(clean, maxChars: 450);
    if (chunks.isEmpty) return;

    _activeFullSourceText = clean;
    await speakChunks(chunks, withAmbient: withAmbient);
  }

  /// Speaks an ordered list of text segments sequentially (e.g. Reading Plan verses
  /// & devotionals) using safe utterance chunk sizes so Android TTS never skips or truncates.
  Future<void> speakChunks(
    List<String> segments, {
    bool withAmbient = true,
    void Function(int segmentIndex)? onChunkStart,
  }) async {
    await init();
    await stop(stopAmbientSound: true);

    final flatChunks = <String>[];
    final flatIndices = <int>[];

    for (var i = 0; i < segments.length; i++) {
      final subChunks = splitIntoSpeechChunks(segments[i], maxChars: 450);
      for (final sc in subChunks) {
        flatChunks.add(sc);
        flatIndices.add(i);
      }
    }

    if (flatChunks.isEmpty) return;

    final sessionId = ++_speakSessionId;
    _activeChunks = flatChunks;
    _activeSegmentIndices = flatIndices;
    _activeChunkIndex = 0;
    _activeWithAmbient = withAmbient;
    _onChunkProgress = onChunkStart;

    unawaited(_runChunkLoop(sessionId));
  }

  Future<void> _runChunkLoop(int sessionId) async {
    _isChunkSequenceActive = true;
    _isContinuousReading = true;
    _isPlaying = true;
    _isPaused = false;
    isPlayingNotifier.value = true;
    isPausedNotifier.value = false;

    if (_activeWithAmbient && _ambientTrack != 'none' && _ambientVolume > 0.001 && !_isAmbientPlaying) {
      await startAmbient();
    }

    while (_activeChunkIndex < _activeChunks.length && sessionId == _speakSessionId && !_isPaused) {
      final chunkText = _activeChunks[_activeChunkIndex];
      final segIndex = _activeSegmentIndices[_activeChunkIndex];
      currentChunkIndexNotifier.value = segIndex;
      _onChunkProgress?.call(segIndex);

      await speakAndWait(chunkText, withAmbient: false);

      if (sessionId != _speakSessionId || _isPaused) break;
      _activeChunkIndex++;
      if (_activeChunkIndex < _activeChunks.length) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
    }

    // Completed the full reading naturally without pause or cancellation
    if (sessionId == _speakSessionId && !_isPaused) {
      _isChunkSequenceActive = false;
      _isContinuousReading = false;
      _isPlaying = false;
      _isPaused = false;
      isPlayingNotifier.value = false;
      isPausedNotifier.value = false;
      currentChunkIndexNotifier.value = -1;
      _activeChunks = [];
      _activeSegmentIndices = [];
      _activeChunkIndex = 0;
      _currentText = null;
      _activeFullSourceText = null;
      await stopAmbient();
    }
  }

  /// Speaks the given text and completes reliably when TTS finishes or is stopped.
  /// Prevents premature completion or utterance skipping via strict token tracking.
  Future<void> speakAndWait(String text, {bool withAmbient = true}) async {
    await init();
    _isContinuousReading = true;
    if (_isPlaying && !_isChunkSequenceActive) {
      _currentUtteranceId++;
      try {
        await _flutterTts.stop();
      } catch (e) {
        debugPrint('Error stopping flutterTts: $e');
      }
      _isPlaying = false;
      _isPaused = false;
      isPlayingNotifier.value = false;
      isPausedNotifier.value = false;
      _currentText = null;
      _completeActiveUtterance();
      // Brief platform hardware settle delay
      await Future.delayed(const Duration(milliseconds: 40));
    }

    final clean = cleanForSpeech(text);
    if (clean.isEmpty) return;

    if (withAmbient && _ambientTrack != 'none' && _ambientVolume > 0.001 && !_isAmbientPlaying) {
      await startAmbient();
    }

    _currentText = clean;
    final thisUtteranceId = ++_currentUtteranceId;
    final completer = Completer<void>();
    _activeCompleter = completer;

    _isPlaying = true;
    _isPaused = false;
    isPlayingNotifier.value = true;
    isPausedNotifier.value = false;

    try {
      final dispatchTime = DateTime.now();
      // If awaitSpeakCompletion is active, speak() natively waits for completion.
      final speakFuture = _flutterTts.speak(clean);

      // Race between native speakFuture completion and channel callback completion
      unawaited(speakFuture.then((val) async {
        final elapsedMs = DateTime.now().difference(dispatchTime).inMilliseconds;
        // Guard against Android rejecting TTS immediately (returning 0 in <50ms)
        if (val == 0 && elapsedMs < 50 && thisUtteranceId == _currentUtteranceId && !completer.isCompleted) {
          debugPrint('TTS returned 0 immediately (${elapsedMs}ms), retrying utterance once...');
          await Future.delayed(const Duration(milliseconds: 160));
          if (thisUtteranceId == _currentUtteranceId && !completer.isCompleted) {
            try {
              await _flutterTts.speak(clean);
            } catch (_) {}
          }
        }
        if (thisUtteranceId == _currentUtteranceId && !completer.isCompleted) {
          completer.complete();
        }
      }).catchError((err) {
        debugPrint('Error in speak(): $err');
        if (thisUtteranceId == _currentUtteranceId && !completer.isCompleted) {
          completer.complete();
        }
      }));
    } catch (e) {
      debugPrint('Failed to dispatch speech: $e');
      if (!completer.isCompleted) completer.complete();
    }

    // Await completion with a safe fallback timeout so playback never hangs indefinitely
    try {
      await completer.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          debugPrint('TTS utterance timed out, progressing cleanly.');
        },
      );
    } catch (_) {}

    if (thisUtteranceId == _currentUtteranceId) {
      _isPlaying = false;
      if (!_isChunkSequenceActive) {
        _isPaused = false;
        isPlayingNotifier.value = false;
        isPausedNotifier.value = false;
      }
      _currentText = null;
      _activeCompleter = null;
    }
  }

  Future<void> pause() async {
    if (!_isInitialized || (!_isPlaying && !_isChunkSequenceActive)) return;
    _currentUtteranceId++;
    _isPaused = true;
    _isPlaying = false;
    isPlayingNotifier.value = false;
    isPausedNotifier.value = true;
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _completeActiveUtterance();
    await pauseAmbient();
  }

  Future<void> resume() async {
    if (!_isPaused) return;
    if (_activeChunks.isNotEmpty && _activeChunkIndex < _activeChunks.length) {
      final sessionId = _speakSessionId;
      _isPaused = false;
      isPausedNotifier.value = false;
      if (_activeWithAmbient) {
        await resumeAmbient();
      }
      unawaited(_runChunkLoop(sessionId));
    }
  }

  Future<void> toggleSpeak(String text) async {
    final clean = cleanForSpeech(text);
    if ((_isPlaying || _isChunkSequenceActive) && (_activeFullSourceText == clean || _currentText == clean)) {
      await stop();
    } else if (_isPaused && _activeFullSourceText == clean) {
      await resume();
    } else {
      await speak(text);
    }
  }

  Future<void> stop({bool stopAmbientSound = true}) async {
    if (!_isInitialized) return;
    _speakSessionId++;
    _currentUtteranceId++;
    _isChunkSequenceActive = false;
    _activeChunks = [];
    _activeSegmentIndices = [];
    _activeChunkIndex = 0;
    _activeFullSourceText = null;
    currentChunkIndexNotifier.value = -1;
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('Error stopping flutterTts: $e');
    }
    if (stopAmbientSound) {
      _isContinuousReading = false;
      await stopAmbient();
    }
    _isPlaying = false;
    _isPaused = false;
    isPlayingNotifier.value = false;
    isPausedNotifier.value = false;
    _currentText = null;
    _completeActiveUtterance();
  }

  Future<void> setCounselorVoice(String voiceKey) async {
    _counselorVoice = voiceKey;
    counselorVoiceNotifier.value = voiceKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('counselor_voice_persona', voiceKey);
  }

  Future<void> stopCounselor() async {
    try {
      await _counselorAudioPlayer.stop();
    } catch (_) {}
    isCounselorPlayingNotifier.value = false;
    isCounselorPausedNotifier.value = false;
    _counselorCurrentText = null;
    counselorActiveTextNotifier.value = null;
    await stop(stopAmbientSound: false);
  }

  Future<void> pauseCounselor() async {
    try {
      await _counselorAudioPlayer.pause();
    } catch (_) {}
    if (_isPlaying) {
      try {
        await _flutterTts.pause();
      } catch (_) {}
    }
    isCounselorPlayingNotifier.value = false;
    isCounselorPausedNotifier.value = true;
  }

  Future<void> resumeCounselor() async {
    try {
      if (_counselorAudioPlayer.state == PlayerState.paused) {
        await _counselorAudioPlayer.resume();
        isCounselorPlayingNotifier.value = true;
        isCounselorPausedNotifier.value = false;
        return;
      }
    } catch (_) {}
    // If player state was lost or local TTS was used, re-speak current counselor text
    if (_counselorCurrentText != null && _counselorCurrentText!.isNotEmpty) {
      await speakCounselor(_counselorCurrentText!);
    }
  }

  Future<void> speakCounselor(String text, {String? voice}) async {
    await init();
    await stopCounselor();

    final clean = cleanForSpeech(text);
    if (clean.isEmpty) return;

    final targetVoice = voice ?? _counselorVoice;
    _counselorCurrentText = clean;
    counselorActiveTextNotifier.value = clean;
    isCounselorPlayingNotifier.value = true;
    isCounselorPausedNotifier.value = false;

    // 1. Try Natural Studio AI Neural Voice via backend
    try {
      final res = await http.post(
        Uri.parse('$_backendUrl/api/tts/natural'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'text': clean,
          'voice': targetVoice,
          'rate': '+0%',
          'pitch': '+0Hz',
        }),
      ).timeout(const Duration(seconds: 14));

      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        await _counselorAudioPlayer.play(BytesSource(res.bodyBytes));
        return;
      }
    } catch (e) {
      debugPrint('Natural counselor voice network failed, using local neural fallback: $e');
    }

    // 2. Offline / latency fallback to best local on-device voice
    try {
      await speak(clean, withAmbient: false);
    } catch (e) {
      debugPrint('Offline speech error: $e');
      isCounselorPlayingNotifier.value = false;
      isCounselorPausedNotifier.value = false;
      _counselorCurrentText = null;
      counselorActiveTextNotifier.value = null;
    }
  }

  Future<void> toggleSpeakCounselor(String text) async {
    final clean = cleanForSpeech(text);
    final isCurrent = _counselorCurrentText == clean;

    if (isCurrent) {
      if (isCounselorPlayingNotifier.value) {
        await pauseCounselor();
      } else if (isCounselorPausedNotifier.value) {
        await resumeCounselor();
      } else {
        await speakCounselor(text);
      }
    } else {
      await speakCounselor(text);
    }
  }
}
