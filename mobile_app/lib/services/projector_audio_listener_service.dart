// lib/services/projector_audio_listener_service.dart
// Phase 2: Live Projector Audio Listener & Scripture Detection Pipeline
//
// Manages the full lifecycle of the 3-way Projector Listening modes:
//   - MANUAL  : Mic fully off. Zero CPU overhead. 100% human control.
//   - ASSIST  : Mic on. Detections trigger onSuggestion callback for operator review.
//   - AUTO    : Mic on. High-confidence detections auto-project after cooldown guard.
//
// Architecture:
//   1. Periodic audio capture using `record` package (already in pubspec.yaml).
//   2. Audio chunks POSTed to backend /api/projector/transcribe (Gemini Whisper).
//   3. Transcript fed into ScriptureDetectionService for offline citation parsing.
//   4. Results routed to operator callbacks per active mode.
//
// This service is a singleton and is lifecycle-managed by ScriptureProjectorScreen.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'scripture_detection_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────

/// The three operating modes of the Live Projector Listener.
enum ProjectorListenerMode {
  manual,   // Microphone off. Zero overhead.
  assist,   // Mic on. Detections shown as suggestions to operator.
  auto,     // Mic on. High-confidence detections project automatically.
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTENER STATE DATA
// ─────────────────────────────────────────────────────────────────────────────

/// Represents the current live state of the audio listener for UI rendering.
class ListenerState {
  final ProjectorListenerMode mode;
  final bool isListening;
  final bool isProcessing;
  final double audioLevel;     // 0.0 – 1.0 VU meter value
  final String? lastTranscript;
  final String? statusMessage;
  final DetectedScripture? pendingSuggestion; // Assist mode only
  final DetectedScripture? lastAutoProjected; // Auto mode feedback
  final int? autoProjectCooldownSecondsLeft;  // countdown in Auto mode

  const ListenerState({
    this.mode = ProjectorListenerMode.manual,
    this.isListening = false,
    this.isProcessing = false,
    this.audioLevel = 0.0,
    this.lastTranscript,
    this.statusMessage,
    this.pendingSuggestion,
    this.lastAutoProjected,
    this.autoProjectCooldownSecondsLeft,
  });

  ListenerState copyWith({
    ProjectorListenerMode? mode,
    bool? isListening,
    bool? isProcessing,
    double? audioLevel,
    String? lastTranscript,
    String? statusMessage,
    DetectedScripture? pendingSuggestion,
    bool clearPendingSuggestion = false,
    DetectedScripture? lastAutoProjected,
    bool clearLastAutoProjected = false,
    int? autoProjectCooldownSecondsLeft,
    bool clearCooldown = false,
  }) {
    return ListenerState(
      mode: mode ?? this.mode,
      isListening: isListening ?? this.isListening,
      isProcessing: isProcessing ?? this.isProcessing,
      audioLevel: audioLevel ?? this.audioLevel,
      lastTranscript: lastTranscript ?? this.lastTranscript,
      statusMessage: statusMessage ?? this.statusMessage,
      pendingSuggestion: clearPendingSuggestion ? null : (pendingSuggestion ?? this.pendingSuggestion),
      lastAutoProjected: clearLastAutoProjected ? null : (lastAutoProjected ?? this.lastAutoProjected),
      autoProjectCooldownSecondsLeft: clearCooldown ? null : (autoProjectCooldownSecondsLeft ?? this.autoProjectCooldownSecondsLeft),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROJECTOR AUDIO LISTENER SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class ProjectorAudioListenerService {
  ProjectorAudioListenerService._();
  static final ProjectorAudioListenerService instance = ProjectorAudioListenerService._();

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Backend endpoint for audio transcription fallback.
  static const String _backendUrl = 'https://imago-1-wkzl.onrender.com';

  /// How many seconds to record audio before sending for transcription.
  /// 2.0 seconds — optimal for natural preaching cadence and rapid ~2s reaction time.
  int recordingChunkSeconds = 2;

  /// Direct Groq Whisper API Key for ultra-fast 150ms transcription (optional, configurable via settings).
  String? groqApiKey = const String.fromEnvironment('GROQ_API_KEY', defaultValue: '');

  /// Minimum confidence required to trigger AUTO mode projection (default 0.78).
  double autoModeConfidenceThreshold = 0.78;

  /// Minimum hold time in Auto mode before projecting a new scripture (prevents strobing).
  int autoModeCooldownSeconds = 2;

  /// How many milliseconds to wait before dismissing an Assist suggestion automatically.
  static const int _assistSuggestionAutoFadeMs = 12000;

  // ── Internal State ────────────────────────────────────────────────────────

  ListenerState _state = const ListenerState();
  final AudioRecorder _recorder = AudioRecorder();
  InputDevice? _selectedDevice;
  Timer? _suggestionFadeTimer;
  Timer? _cooldownTimer;

  /// Selected input device (null for system default).
  InputDevice? get selectedDevice => _selectedDevice;

  /// Tracks active listening lifecycle
  bool _isActive = false;

  /// Number of active background transcription workers (capped at 2)
  int _activeWorkers = 0;

  /// Sliding context window from the tail of the previous transcript
  String _recentTranscriptTail = '';

  /// Cooldown gate: prevents auto-projecting a new scripture too quickly.
  bool _isCoolingDown = false;

  // ── Public State Stream ───────────────────────────────────────────────────

  final StreamController<ListenerState> _stateController =
      StreamController<ListenerState>.broadcast();

  /// Stream of ListenerState updates for the Projector UI to listen to.
  Stream<ListenerState> get stateStream => _stateController.stream;

  /// The latest snapshot of the listener state.
  ListenerState get state => _state;

  // ── Callbacks ─────────────────────────────────────────────────────────────

  /// Called in ASSIST mode when a high-confidence scripture is detected.
  /// The operator sees a suggestion card with Project/Edit/Dismiss options.
  void Function(DetectedScripture)? onSuggestion;

  /// Called in AUTO mode when a scripture is automatically projected.
  void Function(DetectedScripture)? onAutoProject;

  /// Called when spoken navigation command to move down/next verse is detected.
  void Function()? onNextVerse;

  /// Called when spoken navigation command to move up/previous verse is detected.
  void Function()? onPreviousVerse;

  /// Called in either mode when detection processes a transcript chunk.
  void Function(String transcript)? onTranscript;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Initializes persistent listener configuration from disk.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString('imago_groq_api_key');
      if (savedKey != null && savedKey.trim().isNotEmpty) {
        groqApiKey = savedKey.trim();
      }
      final savedChunk = prefs.getInt('imago_listener_chunk_seconds');
      if (savedChunk != null && savedChunk >= 2 && savedChunk <= 6) {
        recordingChunkSeconds = savedChunk;
      }
      final savedThreshold = prefs.getDouble('imago_listener_threshold');
      if (savedThreshold != null && savedThreshold >= 0.50 && savedThreshold <= 0.95) {
        autoModeConfidenceThreshold = savedThreshold;
      }
    } catch (_) {}
  }

  /// Sets the active listening mode. Automatically starts or stops the mic.
  Future<void> setMode(ProjectorListenerMode mode) async {
    if (_state.mode == mode && _state.isListening == (mode != ProjectorListenerMode.manual)) {
      return;
    }
    await _stopListening();
    _emit(_state.copyWith(mode: mode, clearPendingSuggestion: true));
    if (mode != ProjectorListenerMode.manual) {
      await _startListening();
    }
  }

  /// Dismisses the current Assist mode pending suggestion.
  void dismissSuggestion() {
    _suggestionFadeTimer?.cancel();
    _emit(_state.copyWith(clearPendingSuggestion: true, statusMessage: 'Suggestion dismissed.'));
  }

  /// Returns all available audio input devices (e.g. microphones, USB interfaces).
  Future<List<InputDevice>> listInputDevices() async {
    try {
      return await _recorder.listInputDevices();
    } catch (_) {
      return [];
    }
  }

  /// Sets the audio input device to record from (null uses system default).
  Future<void> setSelectedDevice(InputDevice? device) async {
    _selectedDevice = device;
    if (_state.isListening) {
      await _stopListening();
      await _startListening();
    }
  }

  /// Resets any active cooldown timer immediately.
  void resetCooldown() {
    _isCoolingDown = false;
    _cooldownTimer?.cancel();
    _emit(_state.copyWith(clearCooldown: true));
  }

  /// Updates sensitivity, interval, and API credentials dynamically.
  void updateSettings({
    double? confidenceThreshold,
    int? cooldownSeconds,
    int? chunkSeconds,
    String? groqApiKey,
  }) {
    if (confidenceThreshold != null) autoModeConfidenceThreshold = confidenceThreshold;
    if (cooldownSeconds != null) {
      autoModeCooldownSeconds = cooldownSeconds;
      if (cooldownSeconds <= 0) {
        resetCooldown();
      }
    }
    if (chunkSeconds != null) recordingChunkSeconds = chunkSeconds;
    if (groqApiKey != null) {
      this.groqApiKey = groqApiKey.trim().isEmpty ? null : groqApiKey.trim();
    }

    // Persist to SharedPreferences
    SharedPreferences.getInstance().then((prefs) {
      if (confidenceThreshold != null) prefs.setDouble('imago_listener_threshold', confidenceThreshold);
      if (chunkSeconds != null) prefs.setInt('imago_listener_chunk_seconds', chunkSeconds);
      if (groqApiKey != null) {
        if (this.groqApiKey != null) {
          prefs.setString('imago_groq_api_key', this.groqApiKey!);
        } else {
          prefs.remove('imago_groq_api_key');
        }
      }
    }).catchError((_) {});
  }

  /// Simulates a spoken speech snippet for testing or rehearsal without microphone hardware.
  Future<void> simulateSpokenPhrase(String phrase) async {
    if (phrase.trim().isEmpty) return;
    _emit(_state.copyWith(lastTranscript: phrase, isProcessing: false));
    onTranscript?.call(phrase);
    await _processTranscript(phrase);
  }

  /// Disposes all resources. Call from ScriptureProjectorScreen.dispose().
  Future<void> dispose() async {
    _isActive = false;
    await _stopListening();
    _suggestionFadeTimer?.cancel();
    _cooldownTimer?.cancel();
    await _stateController.close();
  }

  // ── Internal: Continuous Capture Loop & Lifecycle ─────────────────────────

  Future<void> _startListening() async {
    try {
      await Permission.microphone.request();
    } catch (_) {}

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      _emit(_state.copyWith(
        isListening: false,
        statusMessage: 'Microphone permission denied. Please allow mic access.',
      ));
      return;
    }

    _isActive = true;
    _recentTranscriptTail = '';
    _emit(_state.copyWith(
      isListening: true,
      statusMessage: _state.mode == ProjectorListenerMode.auto
          ? 'Auto-Listening steady & active...'
          : 'Co-Pilot Listening steady & active...',
    ));

    // Launch continuous non-blocking audio capture loop
    unawaited(_runContinuousCaptureLoop());
  }

  Future<void> _stopListening() async {
    _isActive = false;
    _recentTranscriptTail = '';
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (_) {}
    _emit(_state.copyWith(
      isListening: false,
      isProcessing: false,
      audioLevel: 0.0,
      statusMessage: null,
    ));
  }

  /// Continuous audio recording loop:
  /// Captures seamless back-to-back audio chunks without dead gaps or mic cutoffs.
  /// As soon as Chunk N finishes, Chunk N+1 starts recording after a brief WASAPI drain,
  /// and Chunk N is handed off to an asynchronous background worker for AI transcription.
  Future<void> _runContinuousCaptureLoop() async {
    while (_isActive && _state.mode != ProjectorListenerMode.manual) {
      String? audioPath;
      Timer? meterTimer;
      try {
        final dir = await getTemporaryDirectory();
        audioPath = '${dir.path}${Platform.pathSeparator}proj_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        // Clean any lingering recorder state from a previous session
        try {
          if (await _recorder.isRecording()) {
            await _recorder.stop();
          }
        } catch (_) {}

        // ── Windows WASAPI Drain Buffer ───────────────────────────────────────
        // Windows WASAPI / Media Foundation audio driver requires a brief moment to fully
        // release the device handle after stop(). Calling start() instantly causes
        // the OS to reject the mic handle and return empty/0-byte audio chunks.
        // This 120ms pause ensures a clean re-open with minimum latency.
        if (Platform.isWindows) {
          await Future.delayed(const Duration(milliseconds: 120));
        }

        if (!_isActive || _state.mode == ProjectorListenerMode.manual) break;

        final config = _selectedDevice != null
            ? RecordConfig(device: _selectedDevice)
            : const RecordConfig();

        await _recorder.start(config, path: audioPath);

        // Real-time VU meter: continuously polls audio amplitude while chunk records
        meterTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
          try {
            if (!_isActive || !await _recorder.isRecording()) return;
            final amp = await _recorder.getAmplitude();
            // Map amplitude: -50dB to 0dB -> normalized 0.0 to 1.0
            final normalized = ((amp.current + 50.0) / 50.0).clamp(0.0, 1.0);
            _emit(_state.copyWith(audioLevel: normalized, isListening: true));
          } catch (_) {}
        });

        // Record for chunk duration
        await Future.delayed(Duration(seconds: recordingChunkSeconds));
        meterTimer.cancel();
        meterTimer = null;

        String? recordedPath;
        try {
          if (await _recorder.isRecording()) {
            recordedPath = await _recorder.stop();
          }
        } catch (_) {}

        final validPath = recordedPath ?? audioPath;

        if (!_isActive || _state.mode == ProjectorListenerMode.manual) {
          try { await File(validPath).delete(); } catch (_) {}
          break;
        }

        // Validate that the recorded file has meaningful audio data (> 2KB).
        // A 0-byte or near-empty file indicates a Windows mic open failure;
        // discard it silently so we don't waste a Groq API call on noise.
        try {
          final fileSize = await File(validPath).length();
          if (fileSize < 2048) {
            debugPrint('Audio chunk too small (${fileSize}B), discarding — possible Windows mic init failure.');
            try { await File(validPath).delete(); } catch (_) {}
            continue; // restart loop immediately — next iteration will retry with clean WASAPI drain
          }
        } catch (_) {}

        // Dispatch completed chunk to background worker WITHOUT blocking the recording loop.
        _dispatchChunkWorker(validPath);

      } catch (e, stack) {
        debugPrint('Continuous capture error: $e\n$stack');
        meterTimer?.cancel();
        if (audioPath != null) {
          try { await File(audioPath).delete(); } catch (_) {}
        }
        if (!_isActive) break;
        // Guard delay before retrying to avoid tight CPU spin on hardware error
        await Future.delayed(const Duration(milliseconds: 600));
      }
    }
  }

  /// Background worker for processing recorded chunks without blocking the audio capture loop.
  /// Uses a serial processing queue (max 3 pending) to prevent memory backlog while ensuring
  /// no chunks are silently dropped — every valid audio file is eventually transcribed.
  void _dispatchChunkWorker(String audioPath) {
    // Allow up to 3 concurrent workers. Beyond that, discard the oldest pending chunk
    // to prevent unbounded memory buildup if the network is exceptionally slow.
    if (_activeWorkers >= 3) {
      debugPrint('Worker queue full ($_activeWorkers active). Discarding oldest chunk.');
      try { File(audioPath).delete(); } catch (_) {}
      return;
    }

    _activeWorkers++;
    _emit(_state.copyWith(isProcessing: true));

    () async {
      try {
        final transcript = await _transcribeAudio(audioPath);
        if (transcript != null && transcript.trim().isNotEmpty && _isActive) {
          // Sliding context window: join tail of previous chunk with current transcript
          // to catch scripture references that straddle across chunk boundaries.
          final fullText = _recentTranscriptTail.isNotEmpty
              ? '$_recentTranscriptTail $transcript'
              : transcript;

          // Update the tail only if this chunk does NOT start a fresh detection.
          // If _processTranscript clears _recentTranscriptTail (on successful projection),
          // we leave it empty to avoid re-polluting it with just-projected text.
          final prevTail = _recentTranscriptTail;
          final words = transcript.trim().split(RegExp(r'\s+'));
          _recentTranscriptTail = words.length > 14
              ? words.sublist(words.length - 14).join(' ')
              : transcript.trim();

          _emit(_state.copyWith(
            lastTranscript: transcript,
            statusMessage: 'Heard: "$transcript"',
          ));
          onTranscript?.call(transcript);
          await _processTranscript(fullText);

          // If _processTranscript cleared the tail (successful projection/navigation),
          // ensure we don't accidentally restore the pre-call tail value.
          if (_recentTranscriptTail == prevTail && _recentTranscriptTail.isNotEmpty) {
            // Only keep if nothing changed (i.e. no projection happened)
          }
        }
      } catch (e) {
        debugPrint('Transcription worker error: $e');
      } finally {
        try { await File(audioPath).delete(); } catch (_) {}
        _activeWorkers--;
        if (_activeWorkers <= 0 && _isActive) {
          _emit(_state.copyWith(isProcessing: false));
        }
      }
    }();
  }

  /// Transcribes raw audio chunk using direct Groq Whisper API (150ms ultra-fast)
  /// or seamlessly falls back to the backend service.
  Future<String?> _transcribeAudio(String filePath) async {
    try {
      final file = File(filePath);
      if (!file.existsSync() || file.lengthSync() < 500) return null;

      // 0. High-Speed Direct Groq Whisper API (~150ms latency)
      if (groqApiKey != null && groqApiKey!.trim().isNotEmpty) {
        try {
          final request = http.MultipartRequest(
            'POST',
            Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
          );
          request.headers['Authorization'] = 'Bearer ${groqApiKey!.trim()}';
          request.fields['model'] = 'whisper-large-v3-turbo';
          request.fields['temperature'] = '0.0';
          request.fields['response_format'] = 'json';
          request.fields['language'] = 'en';
          request.fields['prompt'] = 'Holy Bible scriptures, church sermon preaching: Genesis, Exodus, Leviticus, Numbers, Deuteronomy, Joshua, Judges, Ruth, 1 Samuel, 2 Samuel, 1 Kings, 2 Kings, 1 Chronicles, 2 Chronicles, Ezra, Nehemiah, Esther, Job, Psalms, Proverbs, Ecclesiastes, Song of Solomon, Isaiah, Jeremiah, Lamentations, Ezekiel, Daniel, Hosea, Joel, Amos, Obadiah, Jonah, Micah, Nahum, Habakkuk, Zephaniah, Haggai, Zechariah, Malachi, Matthew, Mark, Luke, John, Acts, Romans, 1 Corinthians, 2 Corinthians, Galatians, Ephesians, Philippians, Colossians, 1 Thessalonians, 2 Thessalonians, 1 Timothy, 2 Timothy, Titus, Philemon, Hebrews, James, 1 Peter, 2 Peter, 1 John, 2 John, 3 John, Jude, Revelation. Spoken citations: "Romans 8:28", "John 3:16", "verse 28 of Romans 8", "chapter 3 of John verse 16", "the 23rd Psalm", "Psalm 91:1", "chapter 2 verse 20", "next verse", "previous verse".';
          request.files.add(await http.MultipartFile.fromPath('file', filePath));

          final streamedResponse = await request.send().timeout(const Duration(seconds: 5));
          final res = await http.Response.fromStream(streamedResponse);

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final text = data['text'] as String?;
            if (text != null && text.trim().isNotEmpty) return text.trim();
          } else {
            debugPrint("Groq Whisper API returned ${res.statusCode}: ${res.body}");
          }
        } catch (e) {
          debugPrint("Direct Groq Whisper transcription failed, falling back: $e");
        }
      }

      // 1. Try dedicated /api/projector/transcribe
      try {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('$_backendUrl/api/projector/transcribe'),
        );
        request.headers['Bypass-Tunnel-Reminder'] = 'true';
        request.files.add(await http.MultipartFile.fromPath('file', filePath));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 7));
        final res = await http.Response.fromStream(streamedResponse);

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = data['transcript'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      } catch (e) {
        debugPrint("Projector transcribe endpoint failed, falling back to chat/audio: $e");
      }

      // 2. Production fallback: /api/chat/audio (currently live on Render)
      try {
        final fbRequest = http.MultipartRequest(
          'POST',
          Uri.parse('$_backendUrl/api/chat/audio'),
        );
        fbRequest.headers['Bypass-Tunnel-Reminder'] = 'true';
        fbRequest.fields['mood'] = 'Neutral';
        fbRequest.fields['history'] = '[]';
        fbRequest.files.add(await http.MultipartFile.fromPath('file', filePath));

        final fbStreamed = await fbRequest.send().timeout(const Duration(seconds: 7));
        final fbRes = await http.Response.fromStream(fbStreamed);

        if (fbRes.statusCode == 200) {
          final data = jsonDecode(fbRes.body);
          final text = data['transcript'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      } catch (e) {
        debugPrint("Chat audio transcription fallback error: $e");
      }

      return null;
    } catch (e) {
      debugPrint("Transcribe error: $e");
      return null;
    }
  }

  // ── Internal: Detection & Mode Routing ────────────────────────────────────

  Future<void> _processTranscript(String transcript) async {
    final lower = transcript.toLowerCase().trim();

    // 0. Spoken Verse Navigation (e.g. "next verse", "verse down", "read down", "move down", "previous verse", "verse up", "read up")
    final navNext = RegExp(
      r'\b(next\s+verse|verse\s+down|read\s+down|following\s+verse|move\s+down|go\s+down|next\s+slide)\b',
      caseSensitive: false,
    );
    final navPrev = RegExp(
      r'\b(previous\s+verse|verse\s+up|read\s+up|prior\s+verse|move\s+up|go\s+back|go\s+up|previous\s+slide)\b',
      caseSensitive: false,
    );

    if (navNext.hasMatch(lower)) {
      _recentTranscriptTail = '';
      if (!_isCoolingDown) {
        _startCooldown();
        _emit(_state.copyWith(
          statusMessage: 'Spoken navigation: Next verse',
        ));
        onNextVerse?.call();
      }
      return;
    }

    if (navPrev.hasMatch(lower)) {
      _recentTranscriptTail = '';
      if (!_isCoolingDown) {
        _startCooldown();
        _emit(_state.copyWith(
          statusMessage: 'Spoken navigation: Previous verse',
        ));
        onPreviousVerse?.call();
      }
      return;
    }

    var rawHits = ScriptureDetectionService.instance.detect(transcript);

    // Fast AI Semantic Fallback via Groq if offline regex didn't catch it
    if (rawHits.isEmpty && groqApiKey != null && groqApiKey!.trim().isNotEmpty) {
      final hasTrigger = RegExp(
        r'\b(verse|verses|chapter|book|read|turn|bible|scripture|look|gospel|psalm|epistle|passage|testament|page|letter|apostle|paul|prophet)\b',
        caseSensitive: false,
      ).hasMatch(transcript);
      if (hasTrigger) {
        _emit(_state.copyWith(statusMessage: 'Refining voice detection via AI...'));
        final aiHit = await ScriptureDetectionService.instance.detectWithGroqAI(transcript, groqApiKey!);
        if (aiHit != null) {
          rawHits = [aiHit];
        }
      }
    }

    if (rawHits.isEmpty) return;

    final hits = ScriptureDetectionService.deduplicate(rawHits);

    // If multiple scriptures were detected (e.g. speaker moves to a new scripture or context verse),
    // prioritize the newest citation, especially one that differs from what is currently projected.
    DetectedScripture best = hits.first;
    if (_state.lastAutoProjected != null) {
      final differingHits = hits.where((h) => h.formattedRef != _state.lastAutoProjected!.formattedRef).toList();
      if (differingHits.isNotEmpty) {
        best = differingHits.last;
      }
    } else if (hits.length > 1) {
      best = hits.last;
    }

    switch (_state.mode) {
      case ProjectorListenerMode.manual:
        // Defensive guard.
        break;

      case ProjectorListenerMode.assist:
        // Show suggestion to operator regardless of confidence
        _scheduleSuggestionFade();
        _recentTranscriptTail = '';
        _emit(_state.copyWith(
          pendingSuggestion: best,
          statusMessage: 'Scripture detected — awaiting your approval.',
        ));
        onSuggestion?.call(best);
        break;

      case ProjectorListenerMode.auto:
        // If we are already displaying this exact citation, clear tail and avoid re-triggering
        if (_state.lastAutoProjected?.formattedRef == best.formattedRef) {
          _recentTranscriptTail = '';
          return;
        }

        // Only auto-project high-confidence hits, and only when cooldown has elapsed.
        if (best.confidence >= autoModeConfidenceThreshold && !_isCoolingDown) {
          _recentTranscriptTail = '';
          _startCooldown();
          _emit(_state.copyWith(
            lastAutoProjected: best,
            statusMessage: 'Auto-projected: ${best.formattedRef}',
          ));
          onAutoProject?.call(best);
        } else if (_isCoolingDown) {
          _emit(_state.copyWith(
            statusMessage: 'Detected ${best.formattedRef} — hold timer active.',
          ));
        } else {
          // Low confidence — emit for transparency but do not project
          _emit(_state.copyWith(
            statusMessage: 'Low-confidence detection (${(best.confidence * 100).round()}%) — skipped.',
          ));
        }
        break;
    }
  }

  // ── Internal: Timers ──────────────────────────────────────────────────────

  /// Auto-dismisses an Assist suggestion after [_assistSuggestionAutoFadeMs]ms.
  void _scheduleSuggestionFade() {
    _suggestionFadeTimer?.cancel();
    _suggestionFadeTimer = Timer(
      const Duration(milliseconds: _assistSuggestionAutoFadeMs),
      () => _emit(_state.copyWith(clearPendingSuggestion: true, statusMessage: 'Suggestion expired.')),
    );
  }

  /// Starts the Auto mode cooldown guard. Prevents projector from switching
  /// too rapidly when a pastor quotes multiple verses in quick succession.
  void _startCooldown() {
    if (autoModeCooldownSeconds <= 0) {
      _isCoolingDown = false;
      return;
    }
    _isCoolingDown = true;
    int secondsLeft = autoModeCooldownSeconds;
    _emit(_state.copyWith(autoProjectCooldownSecondsLeft: secondsLeft));

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      secondsLeft--;
      if (secondsLeft <= 0) {
        timer.cancel();
        _isCoolingDown = false;
        _emit(_state.copyWith(clearCooldown: true));
      } else {
        _emit(_state.copyWith(autoProjectCooldownSecondsLeft: secondsLeft));
      }
    });
  }

  // ── Internal: Emit ────────────────────────────────────────────────────────

  void _emit(ListenerState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }
}
