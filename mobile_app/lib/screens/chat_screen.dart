import 'dart:convert';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
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
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

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
  bool _isTyping = false;
  late final AudioRecorder _audioRecorder;

  // Using Render for production!
  final String _backendUrl = 'https://imago-nthk.onrender.com';

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
  }

  Future<void> _loadChats() async {
    _prefs = await SharedPreferences.getInstance();
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
    _audioRecorder.dispose();
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
          'history': _buildHistoryPayload()
        }),
      ).timeout(const Duration(seconds: 15));

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
            'Peace be with you. (Offline Mode)\n\n"Fear not, for I am with you; be not dismayed, for I am your God." — Isaiah 41:10\n\nPlease ensure the backend server is running.';
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
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission denied.')));
      }
      return;
    }
    
    if (await _audioRecorder.hasPermission()) {
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/imago_voice_note_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      await _audioRecorder.start(const RecordConfig(), path: filePath);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    
    if (path != null) {
      await _sendAudioMessage(path);
    }
  }

  Future<void> _sendAudioMessage(String path) async {
    setState(() {
      _showQuickReplies = false;
      _messages.add({'isUser': true, 'text': '🎙️ Processing voice note...', 'time': DateTime.now(), 'sermon': null});
      _isLoading = true;
      _saveChats();
    });
    _scrollToBottom();

    String responseText = '';
    Map<String, dynamic>? sermon;
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_backendUrl/api/chat/audio'));
      request.headers['Bypass-Tunnel-Reminder'] = 'true';
      request.fields['mood'] = _selectedMood;
      request.fields['history'] = jsonEncode(_buildHistoryPayload());
      request.files.add(await http.MultipartFile.fromPath('file', path));
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        
        // Update user's message to show transcript instead of 'Processing voice note...'
        if (data['transcript'] != null) {
          setState(() {
            _messages[_messages.length - 1]['text'] = '🎙️ ' + data['transcript'];
          });
        }
        
        responseText = data['response'] ?? 'I could not find an answer.';
        if (data['sermon_recommendation'] != null) {
          sermon = Map<String, dynamic>.from(data['sermon_recommendation']);
        }
        if (data['handoff_required'] == true) {
          _isHandoff = true;
          _connectToWebSocket();
        }
      } else {
        responseText = 'Connection error with the ministry servers (${res.statusCode}).';
      }
    } catch (_) {
      responseText = 'Failed to process voice note. Please try again.';
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
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CosmicBackground(children: [
        // Ambient orbs
        Positioned(top: 80, left: -60,
          child: const CosmicOrb(size: 240, color: Color(0xFF3D5AFE), opacity: 0.09)),
        Positioned(bottom: 160, right: -70,
          child: const CosmicOrb(size: 280, color: Color(0xFF7C4DFF), opacity: 0.08)),

        SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              _buildMoodBar(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (ctx, i) {
                    if (i == _messages.length) return _buildTypingIndicator();
                    return _buildMessageItem(_messages[i]);
                  },
                ),
              ),
              if (_showQuickReplies) _buildQuickReplies(),
              _buildInputBar(),
            ],
          ),
        ),
      ]),
    );
  }

  // ── App Bar ─────────────────────────────────────────────
  Widget _buildAppBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // Animated logo
                AnimatedBuilder(
                  animation: _glow,
                  builder: (_, __) => SizedBox(
                    width: 32, height: 32,
                    child: CustomPaint(painter: ImagoLogoPainter(glowPulse: _glow.value)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Imago',
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: ImagoColors.cream,
                            letterSpacing: 1.5,
                          )),
                      Text(_isHandoff ? 'Live Pastoral Counselor' : 'AI Spiritual Counselor',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: _isHandoff ? Colors.greenAccent.withOpacity(0.8) : Colors.white.withOpacity(0.45),
                            fontWeight: _isHandoff ? FontWeight.w600 : FontWeight.w400,
                          )),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: Colors.white.withOpacity(0.5), size: 20),
                  onPressed: _resetChat,
                ),
                IconButton(
                  icon: Icon(Icons.info_outline_rounded, color: Colors.white.withOpacity(0.5), size: 20),
                  onPressed: _showInfoDialog,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mood Bar ────────────────────────────────────────────
  Widget _buildMoodBar() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _moods.length,
        itemBuilder: (_, i) {
          final mood = _moods[i];
          final selected = _selectedMood == mood['name'];
          final color = mood['color'] as Color;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedMood = mood['name']);
              TrackingService.instance.logMood(mood['name'], 0.8); // 0.8 as a default mock intensity
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? color.withOpacity(0.14) : Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? color.withOpacity(0.55) : Colors.white.withOpacity(0.08),
                  width: selected ? 1.4 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(mood['icon'] as IconData, size: 12,
                      color: selected ? color : Colors.white38),
                  const SizedBox(width: 4),
                  Text(mood['name'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        color: selected ? Colors.white : Colors.white38,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Quick Replies ───────────────────────────────────────
  Widget _buildQuickReplies() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickReplies.map((r) {
          return GestureDetector(
            onTap: () => _sendMessage(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF7986CB).withOpacity(0.35)),
              ),
              child: Text(r,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: ImagoColors.cream,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Message Item ────────────────────────────────────────
  Widget _buildMessageItem(Map<String, dynamic> msg) {
    final isUser = msg['isUser'] as bool;
    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        _buildBubble(msg['text'] as String, isUser, msg['time'] as DateTime),
        if (msg['sermon'] != null) ...[
          const SizedBox(height: 4),
          _buildSermonCard(msg['sermon'] as Map<String, dynamic>),
          const SizedBox(height: 6),
        ],
      ],
    );
  }

  // ── Chat Bubble ─────────────────────────────────────────
  Widget _buildBubble(String text, bool isUser, DateTime time) {
    final bubbleColor = isUser
        ? const Color(0xFF3D5AFE).withOpacity(0.22)
        : Colors.white.withOpacity(0.07);
    final borderColor = isUser
        ? const Color(0xFF5C6BC0).withOpacity(0.5)
        : Colors.white.withOpacity(0.12);

    String youtubeId = '';
    String displayText = text;
    if (!isUser) {
      final regex = RegExp(r'\[YOUTUBE:(.+?)\]');
      final match = regex.firstMatch(text);
      if (match != null) {
        youtubeId = match.group(1) ?? '';
        displayText = text.replaceAll(match.group(0)!, '').trim();
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
            topLeft:     const Radius.circular(20),
            topRight:    const Radius.circular(20),
            bottomLeft:  Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: (isUser ? const Color(0xFF3D5AFE) : Colors.black).withOpacity(0.12),
              blurRadius: 16, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser) ...[
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () => TtsService.instance.speak(displayText),
                        child: Icon(Icons.volume_up_rounded, color: Colors.white.withOpacity(0.6), size: 18),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  SelectableText(displayText, style: ImagoText.body),
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
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      DateFormat('hh:mm a').format(time),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Sermon Card ─────────────────────────────────────────
  Widget _buildSermonCard(Map<String, dynamic> sermon) {
    final isPlaying = sermon['isPlaying'] ?? false;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.76,
        margin: const EdgeInsets.only(left: 4, bottom: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ImagoColors.gold.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(color: ImagoColors.gold.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4)),
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
                      color: ImagoColors.gold.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_rounded, color: ImagoColors.gold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sermon['title'] ?? 'Recommended Sermon',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins', color: Colors.white,
                          fontWeight: FontWeight.w600, fontSize: 13,
                        )),
                    Text(
                      '${sermon['pastor'] ?? 'Pastor Henry'} • ${sermon['length'] ?? '40 mins'}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.45), fontSize: 11,
                      ),
                    ),
                  ])),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Text(isPlaying ? '0:14' : '0:00',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: isPlaying ? 0.08 : 0.0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: ImagoColors.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(sermon['length'] ?? '40:00',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 10)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => sermon['isPlaying'] = !isPlaying),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: ImagoColors.gold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: ImagoColors.gold.withOpacity(0.35)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: ImagoColors.gold, size: 14),
                        const SizedBox(width: 3),
                        Text(isPlaying ? 'PAUSE' : 'PLAY',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: ImagoColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            )),
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
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(width: 2),
          ...List.generate(3, (i) => Container(
            width: 6, height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ImagoColors.gold.withOpacity(0.6),
            ),
          )),
        ]),
      ),
    );
  }

  // ── Input Bar ───────────────────────────────────────────
  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(children: [
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: _isRecording ? 'Listening...' : (_isHandoff ? 'Reply to counselor...' : 'Type your message...'),
                    hintStyle: TextStyle(fontFamily: 'Poppins', color: _isRecording ? const Color(0xFF3D5AFE) : Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              // Mic button (matching INSPIRE.png)
              Container(
                margin: const EdgeInsets.only(right: 2),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3D5AFE).withOpacity(0.4),
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: GestureDetector(
                  onLongPressStart: (_) { if (!_isTyping) _startRecording(); },
                  onLongPressEnd: (_) { if (!_isTyping) _stopRecording(); },
                  onTap: _sendMessage,
                  child: Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.transparent),
                    child: Icon(
                      _isTyping ? Icons.send_rounded : (_isRecording ? Icons.mic_rounded : Icons.mic_none_rounded), 
                      color: Colors.white, size: 20
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Info Dialog ─────────────────────────────────────────
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF1B1147).withOpacity(0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: ImagoColors.gold.withOpacity(0.2)),
          ),
          title: const Text('About Imago',
              style: TextStyle(fontFamily: 'Cinzel', color: ImagoColors.cream, letterSpacing: 1)),
          content: Text(
            'Imago is an AI Spiritual Counselor trained strictly on your pastor\'s sermons, teachings, and books.\n\nSelect an emotional check-in chip to receive personalised, scripture-grounded guidance.',
            style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.65), height: 1.5, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close',
                  style: TextStyle(fontFamily: 'Poppins', color: ImagoColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}
