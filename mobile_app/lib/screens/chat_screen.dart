import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/imago_theme.dart';
import '../services/tracking_service.dart';
import '../services/tts_service.dart';
import '../services/bible_service.dart';
import '../models/bible_models.dart';
import '../models/user_data_models.dart';
import '../services/playlist_player_service.dart';
import '../widgets/scripture_playlist_player_sheet.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/counselor_voice_sheet.dart';

class ChatScreen extends StatefulWidget {
  final String? initialPrompt;
  const ChatScreen({super.key, this.initialPrompt});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  late final Animation<double> _glow;

  List<Map<String, dynamic>> _messages = [];
  SharedPreferences? _prefs;

  // Quick-reply suggestion chips (like INSPIRE.png)
  final List<String> _quickReplies = [
    'I need prayer',
    'I\'m anxious',
    'I feel discouraged',
    'I need strength',
    'I feel lonely',
  ];

  final List<Map<String, dynamic>> _moods = [
    {'name': 'Neutral',     'icon': Icons.sentiment_neutral_rounded,          'color': Colors.white70},
    {'name': 'Joyful',      'icon': Icons.sentiment_very_satisfied_rounded,   'color': Color(0xFFFFC857)},
    {'name': 'Anxious',     'icon': Icons.psychology_rounded,                 'color': Color(0xFF9575CD)},
    {'name': 'Discouraged', 'icon': Icons.sentiment_dissatisfied_rounded,     'color': Color(0xFF4DB6AC)},
    {'name': 'Lonely',      'icon': Icons.person_outline_rounded,             'color': Color(0xFF64B5F6)},
    {'name': 'Tired',       'icon': Icons.bedtime_rounded,                    'color': Color(0xFF7986CB)},
    {'name': 'Prayerful',   'icon': Icons.volunteer_activism_rounded,         'color': Color(0xFFF48FB1)},
  ];

  String _selectedMood = 'Neutral';
  final _msgCtrl  = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isLoading = false;
  bool _showQuickReplies = true;
  
  bool _isHandoff = false;
  WebSocketChannel? _channel;
  late final String _clientId;
  
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;
  String? _currentRecordingPath;
  bool _isTyping = false;
  late final AudioRecorder _audioRecorder;

  // Using Render for production!
  final String _backendUrl = 'https://imago-1-wkzl.onrender.com';
  bool _autoReadEnabled = false;
  String _selectedLanguage = 'English';
  
  @override
  void initState() {
    super.initState();
    _loadChats();
    _clientId = DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString();
    _audioRecorder = AudioRecorder();
    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _glow = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));
    
    _msgCtrl.addListener(() {
      final isTyping = _msgCtrl.text.trim().isNotEmpty;
      if (isTyping != _isTyping) {
        setState(() => _isTyping = isTyping);
      }
    });

    // Pre-warm backend asynchronously to eliminate cold-start latency
    http.get(Uri.parse('$_backendUrl/docs')).catchError((_) => http.Response('', 500));

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialPrompt);
      });
    }
  }

  Future<void> _loadChats() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoReadEnabled = _prefs?.getBool('auto_read_enabled') ?? false;
      _selectedLanguage = _prefs?.getString('selected_language') ?? 'English';
    });
    final String? chatsJson = _prefs!.getString('chat_history');
    if (chatsJson != null) {
      final List<dynamic> decoded = jsonDecode(chatsJson);
      setState(() {
        _messages = decoded.map((e) {
          final map = e as Map<String, dynamic>;
          return {
            'isUser': map['isUser'],
            'text': map['text'],
            'time': DateTime.parse(map['time']),
            'sermon': map['sermon']
          };
        }).toList();
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } else {
      _resetChat();
    }
  }

  Future<void> _saveChats() async {
    if (_prefs == null) return;
    final List<Map<String, dynamic>> toSave = _messages.map((m) => {
      'isUser': m['isUser'],
      'text': m['text'],
      'time': (m['time'] as DateTime).toIso8601String(),
      'sermon': m['sermon'],
    }).toList();
    await _prefs!.setString('chat_history', jsonEncode(toSave));
  }

  void _resetChat() {
    setState(() {
      _messages = [
        {
          'isUser': false,
          'text': 'Hello, beloved.\n\nI\'m here to walk with you, listen with compassion, and guide you with God\'s truth.\n\nHow can I pray or support you today?',
          'time': DateTime.now(),
          'sermon': null,
        }
      ];
    });
    _saveChats();
  }

  List<Map<String, dynamic>> _buildHistoryPayload() {
    final List<Map<String, dynamic>> history = [];
    for (int i = 0; i < _messages.length - 1; i++) {
      final msg = _messages[i];
      history.add({
        'role': msg['isUser'] ? 'user' : 'model',
        'parts': [msg['text']]
      });
    }
    return history;
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    TtsService.instance.stopCounselor();
    _channel?.sink.close();
    _glowCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _connectToWebSocket() {
    final wsUrl = Uri.parse(_backendUrl.replaceFirst('http', 'ws') + '/api/chat/ws/$_clientId');
    _channel = WebSocketChannel.connect(wsUrl);
    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (data['type'] == 'message') {
        setState(() {
          _messages.add({
            'isUser': false,
            'text': data['text'],
            'time': DateTime.now(),
            'sermon': null,
          });
          _isLoading = false;
          _saveChats();
        });
        _scrollToBottom();
        if (_autoReadEnabled) {
          TtsService.instance.speakCounselor(data['text']);
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? override]) async {
    final query = override ?? _msgCtrl.text.trim();
    if (query.isEmpty) return;
    _msgCtrl.clear();
    setState(() {
      _showQuickReplies = false;
      _messages.add({'isUser': true, 'text': query, 'time': DateTime.now(), 'sermon': null});
      _isLoading = true;
      _saveChats();
    });
    _scrollToBottom();
    TrackingService.instance.incrementConversations();

    if (_isHandoff && _channel != null) {
      _channel!.sink.add(query);
      return;
    }

    String responseText = '';
    Map<String, dynamic>? sermon;
    try {
      final res = await http.post(
        Uri.parse('$_backendUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'message': query, 
          'mood': _selectedMood,
          'language': _selectedLanguage,
          'history': _buildHistoryPayload()
        }),
      ).timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        responseText = data['response'] ?? 'I could not find an answer.';
        if (data['sermon_recommendation'] != null) {
          sermon = Map<String, dynamic>.from(data['sermon_recommendation']);
        }
        if (data['handoff_required'] == true) {
          _isHandoff = true;
          _connectToWebSocket();
        }
      } else {
        responseText =
            'Connection error with the ministry servers (${res.statusCode}).';
      }
    } catch (_) {
      final q = query.toLowerCase();
      if (q.contains('suicide') || q.contains('kill myself') || q.contains('hurt')) {
        responseText =
            'You are deeply loved and not alone. Please contact a crisis counsellor immediately by dialling 988, or reach our care team at care@imagoapp.org.';
      } else {
        responseText =
            'Peace be with you. You are currently in offline mode, but God is always near.\n\n"Fear not, for I am with you; be not dismayed, for I am your God." — Isaiah 41:10\n\nI am still here to share scriptures, prayers, and words of encouragement with you.';
        if (q.contains('anxious') || q.contains('fear')) {
          sermon = {
            'title': 'Faith Over Fear',
            'pastor': 'Pastor Henry',
            'length': '42 mins',
            'audio_url': 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3',
          };
        }
      }
    }

    setState(() {
      _messages.add({
        'isUser': false,
        'text': responseText,
        'time': DateTime.now(),
        'sermon': sermon,
      });
      _isLoading = false;
      _saveChats();
    });
    _scrollToBottom();
    if (_autoReadEnabled) {
      TtsService.instance.speakCounselor(responseText);
    }
  }

  Future<void> _startListening() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/imago_dictation_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentRecordingPath = filePath;
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      _recordingSeconds = 0;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _isRecording) {
          setState(() {
            _recordingSeconds++;
          });
        }
      });
      setState(() {
        _isRecording = true;
      });
    }
  }

  Future<void> _cancelListening() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
      _currentRecordingPath = null;
    });
  }

  Future<void> _stopListeningAndProcess({required bool andSend}) async {
    _recordingTimer?.cancel();
    final path = await _audioRecorder.stop() ?? _currentRecordingPath;
    setState(() {
      _isRecording = false;
      _isTranscribing = true;
    });

    if (path == null) {
      if (mounted) setState(() => _isTranscribing = false);
      return;
    }

    final transcribedText = await _transcribeAudioFile(path);
    if (!mounted) return;

    setState(() {
      _isTranscribing = false;
      _recordingSeconds = 0;
      _currentRecordingPath = null;
    });

    if (transcribedText.trim().isNotEmpty) {
      if (andSend) {
        _sendMessage(transcribedText.trim());
      } else {
        // Populate text controller for user to review, edit, or append
        final currentText = _msgCtrl.text.trim();
        _msgCtrl.text = currentText.isEmpty 
            ? transcribedText.trim() 
            : '$currentText ${transcribedText.trim()}';
        _msgCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _msgCtrl.text.length),
        );
        setState(() => _isTyping = true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not detect clear speech. Please try speaking again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<String> _transcribeAudioFile(String path) async {
    // 1. Try ultra-fast direct Groq Whisper Turbo API (~200ms) if configured via environment
    try {
      const String envGroqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
      if (envGroqKey.isNotEmpty) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.groq.com/openai/v1/audio/transcriptions'),
        );
        request.headers['Authorization'] = 'Bearer $envGroqKey';
        request.fields['model'] = 'whisper-large-v3-turbo';
        request.fields['temperature'] = '0.0';
        request.files.add(await http.MultipartFile.fromPath('file', path));

        final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
        final res = await http.Response.fromStream(streamedResponse);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final text = (data['text'] ?? '').toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (e) {
      debugPrint('Direct Groq transcription failed, falling back to backend: $e');
    }

    // 2. Fallback to backend /api/projector/transcribe
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_backendUrl/api/projector/transcribe'),
      );
      request.headers['Bypass-Tunnel-Reminder'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('file', path));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(streamedResponse);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return (data['transcript'] ?? '').toString().trim();
      }
    } catch (e) {
      debugPrint('Backend transcription fallback failed: $e');
    }

    return '';
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
        final bg = isDark
            ? const Color(0xFF0B132B)
            : (isParchment ? const Color(0xFFF7F2E7) : const Color(0xFFF8FAFC));
        return Scaffold(
          backgroundColor: bg,
          body: CosmicBackground(children: [
            // Ambient soft orbs with reduced opacity in light mode
            Positioned(
              top: 80,
              left: -60,
              child: CosmicOrb(
                size: 260,
                color: const Color(0xFF4F46E5),
                opacity: isDark ? 0.09 : 0.04,
              ),
            ),
            Positioned(
              bottom: 160,
              right: -70,
              child: CosmicOrb(
                size: 280,
                color: const Color(0xFF7C4DFF),
                opacity: isDark ? 0.08 : 0.03,
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildAppBar(isDark),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _messages.length + (_isLoading ? 1 : 0) + (_messages.length <= 1 ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (_messages.length <= 1 && i == 0) {
                          return _buildWelcomeCard(isDark);
                        }
                        final msgIndex = _messages.length <= 1 ? i - 1 : i;
                        if (msgIndex == _messages.length) return _buildTypingIndicator(isDark);
                        return _buildMessageItem(_messages[msgIndex], isDark);
                      },
                    ),
                  ),
                  if (_showQuickReplies) _buildQuickReplies(isDark),
                  _buildCounselorAudioBar(isDark),
                  _buildInputBar(isDark),
                ],
              ),
            ),
          ]),
        );
      },
    );
  }

  // ── App Bar ─────────────────────────────────────────────
  Widget _buildAppBar(bool isDark) {
    final canPop = Navigator.of(context).canPop();
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.85)
            : (isParchment ? const Color(0xFFFFFDF8).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155).withValues(alpha: 0.5)
              : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 6),
          ],
          // Animated Yoets avatar
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.35 + (_glow.value * 0.15)),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 17),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title & Subtitle (Spacious, Zero truncation!)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Yoets',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? ImagoColors.cream : const Color(0xFF0F172A),
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  _isHandoff ? 'Live Pastoral Counselor' : 'Pastoral Counselor',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: _isHandoff
                        ? const Color(0xFF10B981)
                        : (isDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF64748B)),
                    fontWeight: _isHandoff ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Voice read-aloud toggle
          IconButton(
            icon: Icon(
              _autoReadEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _autoReadEnabled
                  ? const Color(0xFF4F46E5)
                  : (isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF94A3B8)),
              size: 20,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
            tooltip: _autoReadEnabled ? 'Voice Mode: On' : 'Voice Mode: Off',
            onPressed: () {
              setState(() => _autoReadEnabled = !_autoReadEnabled);
              if (_prefs != null) {
                _prefs!.setBool('auto_read_enabled', _autoReadEnabled);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_autoReadEnabled ? 'Voice Mode Enabled (Responses read aloud)' : 'Voice Mode Disabled'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          // Counselor Voice Studio
          IconButton(
            icon: Icon(
              Icons.record_voice_over_rounded,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
              size: 19,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 34),
            tooltip: 'Counselor Voice Studio',
            onPressed: () {
              CounselorVoiceSheet.show(
                context,
                autoReadEnabled: _autoReadEnabled,
                onAutoReadChanged: (val) {
                  setState(() => _autoReadEnabled = val);
                  if (_prefs != null) {
                    _prefs!.setBool('auto_read_enabled', val);
                  }
                },
              );
            },
          ),
          // Options Menu
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B),
              size: 20,
            ),
            color: isDark ? const Color(0xFF1B1147) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2E8F0),
              ),
            ),
            onSelected: (val) {
              if (val == 'voice_studio') {
                CounselorVoiceSheet.show(
                  context,
                  autoReadEnabled: _autoReadEnabled,
                  onAutoReadChanged: (val) {
                    setState(() => _autoReadEnabled = val);
                    if (_prefs != null) {
                      _prefs!.setBool('auto_read_enabled', val);
                    }
                  },
                );
              }
              if (val == 'language') _showLanguageDialog(isDark);
              if (val == 'clear') _resetChat();
              if (val == 'info') _showInfoDialog(isDark);
              if (val == 'feedback') FeedbackDialog.show(context, screenContext: 'chat_counseling');
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'voice_studio',
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, color: Color(0xFF6366F1), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Counselor Voice Studio',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'language',
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded, color: Color(0xFF818CF8), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Language: $_selectedLanguage',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'feedback',
                child: Row(
                  children: [
                    const Icon(Icons.rate_review_rounded, color: Color(0xFFFFC857), size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Send Feedback & Ideas',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      'Clear Conversation',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'About Yoets',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog(bool isDark) {
    final Map<String, String> langFlags = {
      'English': '🇬🇧 English',
      'Pidgin': '🇳🇬 Nigerian Pidgin',
      'Igbo': '🟢 Igbo (Ndesịrị Igbo)',
      'Hausa': '🔴 Hausa',
      'Yoruba': '🟡 Yoruba (Èdè Yorùbá)',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Counseling Language',
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            ...langFlags.entries.map((e) {
              final isSel = _selectedLanguage == e.key;
              return ListTile(
                title: Text(
                  e.value,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                    color: isSel ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ),
                trailing: isSel ? const Icon(Icons.check_circle_rounded, color: Color(0xFF4F46E5)) : null,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () {
                  setState(() => _selectedLanguage = e.key);
                  _prefs?.setString('selected_language', e.key);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Welcome & Mood Check-In Card ─────────────────────────
  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.45) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFEEF2FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Color(0xFFF43F5E),
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'How is your heart feeling today?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMoodBar(isDark),
        ],
      ),
    );
  }

  // ── Mood Bar (Clean Horizontal Row inside Welcome Card) ───
  Widget _buildMoodBar(bool isDark) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final mood = _moods[i];
          final selected = _selectedMood == mood['name'];
          final color = mood['color'] as Color;

          final effectiveColor = (!isDark && color == const Color(0xFFFFC857))
              ? const Color(0xFFD97706)
              : ((!isDark && color == Colors.white70) ? const Color(0xFF4F46E5) : color);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedMood = mood['name']);
              TrackingService.instance.logMood(mood['name'], 0.8);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: selected
                    ? (isDark
                        ? effectiveColor.withValues(alpha: 0.22)
                        : effectiveColor.withValues(alpha: 0.14))
                    : (isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.5)
                        : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? effectiveColor
                      : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
                  width: selected ? 1.3 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    mood['icon'] as IconData,
                    size: 12,
                    color: selected
                        ? effectiveColor
                        : (isDark ? Colors.white54 : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    mood['name'],
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      color: selected
                          ? (isDark ? Colors.white : effectiveColor)
                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Quick Replies (Sleek Horizontal Carousel) ────────────
  Widget _buildQuickReplies(bool isDark) {
    if (_isTyping) return const SizedBox.shrink();

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final r = _quickReplies[i];
          return ActionChip(
            onPressed: () => _sendMessage(r),
            backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            side: BorderSide(
              color: isDark ? const Color(0xFF334155).withValues(alpha: 0.7) : const Color(0xFFCBD5E1),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            label: Text(
              r,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? ImagoColors.cream : const Color(0xFF334155),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Message Item (Clean & Intimate) ──────────────────────
  Widget _buildMessageItem(Map<String, dynamic> msg, bool isDark) {
    final isUser = msg['isUser'] as bool;
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: () => _showMessageActionSheet(msg, isDark),
          child: _buildBubble(msg['text'] as String, isUser, msg['time'] as DateTime, isDark),
        ),
        if (msg['sermon'] != null) ...[
          const SizedBox(height: 4),
          _buildSermonCard(msg['sermon'] as Map<String, dynamic>, isDark),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  // ── Long-Press Message Actions (Clean Modal) ─────────────
  void _showMessageActionSheet(Map<String, dynamic> msg, bool isDark) {
    final text = msg['text'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Color(0xFF4F46E5)),
              title: const Text('Copy Message', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: text));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Message copied to clipboard'), duration: Duration(seconds: 2)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_up_rounded, color: Color(0xFF10B981)),
              title: const Text('Listen Aloud', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5)),
              onTap: () {
                Navigator.pop(ctx);
                TtsService.instance.speak(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rate_review_rounded, color: Color(0xFFFFC857)),
              title: const Text('Send Feedback on this Response', style: TextStyle(fontFamily: 'Poppins', fontSize: 13.5)),
              onTap: () {
                Navigator.pop(ctx);
                FeedbackDialog.show(
                  context,
                  screenContext: 'chat_answer',
                  metadata: {'message_preview': text.substring(0, text.length.clamp(0, 100))},
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Chat Bubble ─────────────────────────────────────────
  Widget _buildBubble(String text, bool isUser, DateTime time, bool isDark) {
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
    final bubbleColor = isUser
        ? (isDark ? const Color(0xFF3D5AFE).withValues(alpha: 0.25) : (isParchment ? const Color(0xFF9A6B2F) : const Color(0xFF4F46E5)))
        : (isDark
            ? const Color(0xFF131D33)
            : (isParchment ? const Color(0xFFFFFDF8) : Colors.white));
    final borderColor = isUser
        ? (isDark ? const Color(0xFF5C6BC0).withValues(alpha: 0.5) : (isParchment ? const Color(0xFF8B5E28) : const Color(0xFF4338CA)))
        : (isDark
            ? const Color(0xFF1E293B)
            : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0)));

    final textColor = isUser
        ? Colors.white
        : (isDark
            ? Colors.white.withValues(alpha: 0.95)
            : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A)));

    String youtubeId = '';
    String audioUrl = '';
    String displayText = text;
    if (!isUser) {
      final ytRegex = RegExp(r'\[YOUTUBE:(.+?)\]');
      final ytMatch = ytRegex.firstMatch(displayText);
      if (ytMatch != null) {
        youtubeId = ytMatch.group(1) ?? '';
        displayText = displayText.replaceAll(ytMatch.group(0)!, '').trim();
      }

      final audioRegex = RegExp(r'\[AUDIO:(.+?)\]');
      final audioMatch = audioRegex.firstMatch(displayText);
      if (audioMatch != null) {
        audioUrl = audioMatch.group(1) ?? '';
        displayText = displayText.replaceAll(audioMatch.group(0)!, '').trim();
      }
    }

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isUser
                  ? const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.2 : 0.25)
                  : (isDark
                      ? Colors.black.withValues(alpha: 0.16)
                      : const Color(0xFF0F172A).withValues(alpha: 0.05)),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isUser) ...[
                  Align(
                    alignment: Alignment.topRight,
                    child: ValueListenableBuilder<String?>(
                      valueListenable: TtsService.instance.counselorActiveTextNotifier,
                      builder: (context, activeText, _) {
                        return ValueListenableBuilder<bool>(
                          valueListenable: TtsService.instance.isCounselorPlayingNotifier,
                          builder: (context, isPlaying, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: TtsService.instance.isCounselorPausedNotifier,
                              builder: (context, isPaused, _) {
                                final cleanCurrent = TtsService.cleanForSpeech(displayText);
                                final isThisMessageActive = activeText != null && activeText == cleanCurrent;

                                if (isThisMessageActive && (isPlaying || isPaused)) {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Play / Pause / Continue button
                                      GestureDetector(
                                        onTap: () {
                                          if (isPlaying) {
                                            TtsService.instance.pauseCounselor();
                                          } else {
                                            TtsService.instance.resumeCounselor();
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                color: const Color(0xFF6366F1),
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isPlaying ? 'Pause' : 'Continue',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF6366F1),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      // Stop button
                                      GestureDetector(
                                        onTap: () => TtsService.instance.stopCounselor(),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEF2FF),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.stop_rounded,
                                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }

                                // Inactive: single listen button
                                return GestureDetector(
                                  onTap: () => TtsService.instance.speakCounselor(displayText),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFEEF2FF),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.volume_up_rounded,
                                      color: isDark ? Colors.white70 : const Color(0xFF4F46E5),
                                      size: 16,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                SelectableText.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: textColor,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                    children: _parseTextWithVerses(displayText, isDark),
                  ),
                ),
                if (!isUser) _buildPlaylistButton(displayText, isDark),
                if (youtubeId.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: YoutubePlayer(
                      controller: YoutubePlayerController(
                        initialVideoId: youtubeId,
                        flags: const YoutubePlayerFlags(
                          autoPlay: false,
                          mute: false,
                        ),
                      ),
                      showVideoProgressIndicator: true,
                      progressIndicatorColor: const Color(0xFF3D5AFE),
                    ),
                  ),
                ],
                if (audioUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AudioPlayerWidget(url: audioUrl),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    DateFormat('hh:mm a').format(time),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.75)
                          : (isDark ? Colors.white.withValues(alpha: 0.4) : const Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistButton(String text, bool isDark) {
    return FutureBuilder<List<BiblePlaylistItem>>(
      future: BibleService.instance.parseScriptureList(text),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final items = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: GestureDetector(
            onTap: () async {
              await PlaylistPlayerService.instance.loadPlaylist(
                'Yoetz Scripture Lineup',
                items,
                autoPlay: true,
              );
              if (context.mounted) {
                ScripturePlaylistPlayerSheet.show(context);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? ImagoColors.violet.withValues(alpha: 0.2) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? ImagoColors.gold.withValues(alpha: 0.4) : const Color(0xFFC7D2FE),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.queue_music_rounded,
                    color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Listen as Playlist (${items.length})',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? ImagoColors.cream : const Color(0xFF3730A3),
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Verse Chip Parser ───────────────────────────────────
  List<InlineSpan> _parseTextWithVerses(String text, bool isDark) {
    // Matches references like "John 3:16", "1 Corinthians 13:4-8"
    final regex = RegExp(r'\b((?:[1-3]\s+)?[A-Za-z]+)\s+(\d+):(\d+)(?:-(\d+))?\b');
    
    final matches = regex.allMatches(text);
    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <InlineSpan>[];
    int currentIndex = 0;

    for (final match in matches) {
      final matchStr = match.group(0)!;
      final bookStr = match.group(1)!;

      final isValidBook = kBibleBooks.any((b) => b.name.toLowerCase() == bookStr.toLowerCase());

      if (isValidBook) {
        if (match.start > currentIndex) {
          spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
        }

        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: GestureDetector(
              onTap: () => _showVerseContext(matchStr),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: isDark
                      ? ImagoColors.violetGradient
                      : const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
                        ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.35),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      matchStr,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
        spans.add(TextSpan(text: text.substring(currentIndex, match.end)));
      }
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return spans;
  }

  Future<void> _showVerseContext(String reference) async {
    final verses = await BibleService.instance.getVerseByReference(reference);
    if (!mounted) return;
    final isDark = ImagoColors.isDark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF0E0B24) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reference,
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (verses.isNotEmpty)
              ...verses.map((v) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      '${v.verse}. ${v.text}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF0F172A),
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ))
            else
              Text(
                "Could not load verse context for '$reference'.",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isDark ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF64748B),
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Sermon Card ─────────────────────────────────────────
  Widget _buildSermonCard(Map<String, dynamic> sermon, bool isDark) {
    final isPlaying = sermon['isPlaying'] ?? false;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.76,
        margin: const EdgeInsets.only(left: 4, bottom: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? ImagoColors.gold.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? ImagoColors.gold.withValues(alpha: 0.06)
                  : const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? ImagoColors.gold.withValues(alpha: 0.15)
                          : const Color(0xFFEEF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mic_rounded,
                      color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      sermon['title'] ?? 'Recommended Sermon',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${sermon['pastor'] ?? 'Pastor Henry'} • ${sermon['length'] ?? '40 mins'}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? Colors.white.withValues(alpha: 0.45) : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Text(
                    isPlaying ? '0:14' : '0:00',
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: isPlaying ? 0.35 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    sermon['length'] ?? '40:00',
                    style: TextStyle(
                      color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => sermon['isPlaying'] = !isPlaying),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? ImagoColors.gold.withValues(alpha: 0.15) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? ImagoColors.gold.withValues(alpha: 0.35) : const Color(0xFFC7D2FE),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isPlaying ? 'PAUSE' : 'PLAY',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Typing Indicator ────────────────────────────────────
  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 2),
          ...List.generate(3, (i) => Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4F46E5),
            ),
          )),
        ]),
      ),
    );
  }

  // ── Counselor Voice Active Bar ───────────────────────────
  Widget _buildCounselorAudioBar(bool isDark) {
    return ValueListenableBuilder<bool>(
      valueListenable: TtsService.instance.isCounselorPlayingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: TtsService.instance.isCounselorPausedNotifier,
          builder: (context, isPaused, _) {
            if (!isPlaying && !isPaused) return const SizedBox.shrink();

            final currentPersona = TtsService.kCounselorPersonas[TtsService.instance.counselorVoice];
            final personaName = currentPersona?['name'] ?? 'Pastoral Counselor';

            return Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1438) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF6366F1).withValues(alpha: 0.3) : const Color(0xFFCBD5E1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPlaying ? Icons.record_voice_over_rounded : Icons.pause_circle_filled_rounded,
                      color: const Color(0xFF6366F1),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          personaName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isPlaying ? 'Reading response aloud...' : 'Paused — tap to continue',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: isPlaying ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Play / Pause (Continue) Button
                  IconButton(
                    icon: Icon(
                      isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                      color: const Color(0xFF6366F1),
                      size: 26,
                    ),
                    tooltip: isPlaying ? 'Pause' : 'Continue',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      if (isPlaying) {
                        TtsService.instance.pauseCounselor();
                      } else {
                        TtsService.instance.resumeCounselor();
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  // Stop Button
                  IconButton(
                    icon: Icon(
                      Icons.stop_circle_outlined,
                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      size: 24,
                    ),
                    tooltip: 'Stop',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: () => TtsService.instance.stopCounselor(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Input Bar ───────────────────────────────────────────
  Widget _buildInputBar(bool isDark) {
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
    final inputBg = isDark
        ? const Color(0xFF13092C)
        : (isParchment ? const Color(0xFFFFFDF8) : Colors.white);
    final inputBorder = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));
    final inputText = isDark
        ? Colors.white
        : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: inputBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0xFF0F172A).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(children: [
              if (_isRecording) ...[
                // Pulsing red recording dot
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.fiber_manual_record_rounded,
                      color: Color(0xFFEF4444),
                      size: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Elapsed time & indicator
                Expanded(
                  child: Text(
                    'Listening... ${(_recordingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_recordingSeconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                      fontSize: 13,
                    ),
                  ),
                ),
                // Cancel / Discard
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Discard',
                  color: isDark ? Colors.white60 : Colors.black54,
                  onPressed: _cancelListening,
                ),
                // Pause / Stop to edit text
                IconButton(
                  icon: const Icon(Icons.pause_circle_outline_rounded, size: 22),
                  tooltip: 'Pause & Edit text',
                  color: const Color(0xFF6366F1),
                  onPressed: () => _stopListeningAndProcess(andSend: false),
                ),
                // Send directly
                Container(
                  margin: const EdgeInsets.only(right: 2),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                    tooltip: 'Send',
                    padding: EdgeInsets.zero,
                    onPressed: () => _stopListeningAndProcess(andSend: true),
                  ),
                ),
              ] else if (_isTranscribing) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Transcribing speech to text...',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xFF475569),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: inputText,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: _isHandoff ? 'Reply to counselor...' : 'Speak or type what\'s on your heart...',
                      hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        color: isDark ? Colors.white.withValues(alpha: 0.35) : const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                // Mic (single tap) or Send button
                Container(
                  margin: const EdgeInsets.only(right: 2),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: GestureDetector(
                    onTap: () {
                      if (_isTyping) {
                        _sendMessage();
                      } else {
                        _startListening();
                      }
                    },
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                      child: Icon(
                        _isTyping ? Icons.send_rounded : Icons.mic_none_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  // ── Info Dialog ─────────────────────────────────────────
  void _showInfoDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1B1147).withValues(alpha: 0.95) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isDark ? ImagoColors.gold.withValues(alpha: 0.2) : const Color(0xFFE2E8F0),
            ),
          ),
          title: Text(
            'About Yoets',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: isDark ? ImagoColors.cream : const Color(0xFF0F172A),
              letterSpacing: 1,
            ),
          ),
          content: Text(
            'Yoets is a spiritual counselor rooted in scripture and pastoral wisdom.\n\nShare what is on your heart, or select a check-in topic to receive biblical guidance, prayer, and encouragement.',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: isDark ? Colors.white.withValues(alpha: 0.65) : const Color(0xFF475569),
              height: 1.5,
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

