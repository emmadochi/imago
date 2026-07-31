import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/imago_theme.dart';
import '../services/tracking_service.dart';
import '../services/tts_service.dart';

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _levitationController;
  late final Animation<double> _levitationAnimation;

  final TextEditingController _requestController = TextEditingController();
  String? _prayerResponse;
  bool _isLoading = false;
  bool _prayerStarted = false;

  // Community Wall & Options
  int _selectedTab = 0; // 0 = Personal, 1 = Community Wall
  bool _makePublic = false;
  bool _postAnonymously = true;

  List<Map<String, dynamic>> _communityPrayers = [];
  bool _loadingCommunity = false;

  final String _backendUrl = "https://imago-1-wkzl.onrender.com";

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _levitationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _levitationAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _levitationController, curve: Curves.easeInOut),
    );

    _fetchCommunityPrayers();
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    _pulseController.dispose();
    _levitationController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _fetchCommunityPrayers() async {
    setState(() => _loadingCommunity = true);
    try {
      final res = await http.get(Uri.parse('$_backendUrl/api/community-prayer')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = List<Map<String, dynamic>>.from(data['prayers'] ?? []);
        setState(() => _communityPrayers = list);
      }
    } catch (_) {
      // Keep empty or existing list
    } finally {
      if (mounted) setState(() => _loadingCommunity = false);
    }
  }

  Future<void> _prayForCommunityItem(String id, int index) async {
    setState(() {
      _communityPrayers[index]['prayed_count'] = (_communityPrayers[index]['prayed_count'] ?? 0) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🙏 Your prayer has been counted. Be blessed!'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      await http.post(Uri.parse('$_backendUrl/api/community-prayer/$id/pray'));
    } catch (_) {}
  }

  Future<void> _beginPrayer() async {
    final request = _requestController.text.trim();
    if (request.isEmpty) return;

    setState(() {
      _isLoading = true;
      _prayerStarted = true;
      _prayerResponse = null;
    });

    // If marked public, send to community prayer wall as well
    if (_makePublic) {
      try {
        await http.post(
          Uri.parse('$_backendUrl/api/community-prayer'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'request': request,
            'is_anonymous': _postAnonymously,
            'author_name': _postAnonymously ? 'Anonymous' : 'Believer',
          }),
        );
        _fetchCommunityPrayers(); // refresh community wall
      } catch (_) {}
    }

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/prayer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'request': request}),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _prayerResponse = data['prayer'] ?? _fallbackPrayer(request));
      } else {
        setState(() => _prayerResponse = _fallbackPrayer(request));
      }
      TrackingService.instance.logPrayerGenerated();
    } catch (_) {
      setState(() => _prayerResponse = _fallbackPrayer(request));
      TrackingService.instance.logPrayerGenerated();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fallbackPrayer(String request) {
    return 'Heavenly Father,\n\nWe come before you in the name of Jesus, lifting up this prayer concerning: "$request".\n\n'
        'Lord, we trust in your faithfulness, for your Word declares that you are near to all who call on you in truth (Psalm 145:18). '
        'Grant wisdom, peace, and strength according to your perfect will.\n\n'
        'May your presence be felt in this moment. Let your peace, which surpasses all understanding, '
        'guard this heart and mind in Christ Jesus. (Philippians 4:7)\n\n'
        'We believe and receive your answer, for you are able to do exceedingly abundantly above all that we ask or think. (Ephesians 3:20)\n\n'
        'In Jesus\' Name,\n\nAmen. 🙏';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const CosmicBackground(children: []),

          // Ambient center glow — pulses with animation
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5C6BC0).withOpacity(0.06),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: _prayerStarted
                ? _buildPrayerResponse()
                : Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildTopTabBar(),
                      Expanded(
                        child: _selectedTab == 0 ? _buildPrayerEntry() : _buildCommunityWall(),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF5C6BC0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'Personal Prayer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 0 ? Colors.white : Colors.white60,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() => _selectedTab = 1);
                _fetchCommunityPrayers();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF5C6BC0) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 16, color: Colors.white),
                      const SizedBox(width: 6),
                      Text(
                        'Community Wall',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 1 ? Colors.white : Colors.white60,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerEntry() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          // Levitating prayer orb
          AnimatedBuilder(
            animation: _levitationAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _levitationAnimation.value),
              child: child,
            ),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: 0.9 + (_pulseAnimation.value - 0.85) * 0.5,
                child: child,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF5C6BC0).withOpacity(0.6),
                      const Color(0xFF3D5AFE).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3D5AFE).withOpacity(0.5),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.volunteer_activism_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Prayer Mode',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'Share what is on your heart.\nyo-ETS will lead you in prayer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.45),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // Prayer request input (glassmorphic)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: TextField(
                  controller: _requestController,
                  maxLines: 4,
                  style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Lord, I come to you today about...\n\nShare your prayer request here.',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.3), fontSize: 14, height: 1.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Community Wall Options
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _makePublic,
                      activeColor: const Color(0xFF5C6BC0),
                      onChanged: (val) => setState(() => _makePublic = val ?? false),
                    ),
                    Expanded(
                      child: Text(
                        'Share request on Community Prayer Wall',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_makePublic)
                  Row(
                    children: [
                      const SizedBox(width: 32),
                      Checkbox(
                        value: _postAnonymously,
                        activeColor: const Color(0xFF5C6BC0),
                        onChanged: (val) => setState(() => _postAnonymously = val ?? true),
                      ),
                      Expanded(
                        child: Text(
                          'Post Anonymously',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Pray with me button
          GestureDetector(
            onTap: _beginPrayer,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3D5AFE).withOpacity(0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.volunteer_activism_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Pray With Me',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityWall() {
    if (_loadingCommunity) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5C6BC0)),
      );
    }

    if (_communityPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'No public prayers yet.\nBe the first to share your prayer request!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: Colors.white.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCommunityPrayers,
      color: const Color(0xFF5C6BC0),
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _communityPrayers.length,
        itemBuilder: (context, index) {
          final item = _communityPrayers[index];
          final String request = item['request'] ?? '';
          final String author = item['author_name'] ?? 'Anonymous';
          final int prayedCount = item['prayed_count'] ?? 0;
          final String id = item['id'] ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFF5C6BC0).withOpacity(0.2),
                      child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF5C6BC0)),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      author,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.access_time_rounded, size: 14, color: Colors.white.withOpacity(0.3)),
                    const SizedBox(width: 4),
                    Text(
                      'Community',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  request,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: () => _prayForCommunityItem(id, index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C6BC0).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🙏', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 6),
                          Text(
                            'I prayed for this ($prayedCount)',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              color: Color(0xFF5C6BC0),
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrayerResponse() {
    return Column(
      children: [
        // Top bar
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: Colors.white.withOpacity(0.6)),
                onPressed: () {
                  TtsService.instance.stop();
                  setState(() {
                    _prayerStarted = false;
                    _prayerResponse = null;
                    _requestController.clear();
                  });
                },
              ),
              Text(
                'Your Prayer',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF5C6BC0).withOpacity(0.15),
                            border: Border.all(
                                color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Color(0xFF5C6BC0),
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'yo-ETS is praying with you...',
                        style: TextStyle(
                            fontFamily: 'Poppins', color: Colors.white.withOpacity(0.45), fontSize: 14),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.2)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF5C6BC0).withOpacity(0.15),
                                ),
                                child: const Icon(
                                  Icons.volunteer_activism_rounded,
                                  color: Color(0xFF5C6BC0),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _prayerResponse ?? '',
                                textAlign: TextAlign.left,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 15.5,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: () {
                                  if (_prayerResponse != null) {
                                    TtsService.instance.toggleSpeak(_prayerResponse!);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF5C6BC0).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.volume_up_rounded, color: Color(0xFF5C6BC0), size: 18),
                                      SizedBox(width: 8),
                                      Text(
                                        'Listen',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Color(0xFF5C6BC0),
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
