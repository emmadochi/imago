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
    final text = _requestController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please share what is on your heart first.'),
          backgroundColor: const Color(0xFF4F46E5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() {
      _prayerStarted = true;
      _isLoading = true;
      _prayerResponse = null;
    });

    // Record prayer session streak
    TrackingService.instance.logPrayerGenerated();

    try {
      final res = await http.post(
        Uri.parse('$_backendUrl/api/pray'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'request': text,
          'make_public': _makePublic,
          'post_anonymously': _postAnonymously,
        }),
      ).timeout(const Duration(seconds: 25));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _prayerResponse = data['prayer'];
          _isLoading = false;
        });
        if (_prayerResponse != null && _prayerResponse!.isNotEmpty) {
          TtsService.instance.speak(_prayerResponse!);
        }
      } else {
        throw Exception('Server returned ${res.statusCode}');
      }
    } catch (e) {
      setState(() {
        _prayerResponse =
            "Heavenly Father, we bring this heartfelt petition before Your throne of grace. "
            "You know every burden, every silent whisper, and every need before a word is spoken. "
            "We ask for Your peace that surpasses all understanding to guard this heart and mind in Christ Jesus. "
            "Grant strength, renewed faith, and divine break forth today. In Jesus' mighty name, Amen.";
        _isLoading = false;
      });
      if (_prayerResponse != null && _prayerResponse!.isNotEmpty) {
        TtsService.instance.speak(_prayerResponse!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
        final bg = isDark
            ? const Color(0xFF0A0E1A)
            : (isParchment ? const Color(0xFFF7F2E7) : const Color(0xFFF8FAFC));
        final cardBg = isDark
            ? const Color(0xFF131D33)
            : (isParchment ? const Color(0xFFFFFDF8) : Colors.white);
        final borderColor = isDark
            ? const Color(0xFF1E293B)
            : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));
        final textPrimary = isDark
            ? Colors.white
            : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));
        final textSecondary = isDark
            ? const Color(0xFF94A3B8)
            : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF475569));

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: _prayerStarted
                ? _buildPrayerResponse(isDark, cardBg, borderColor, textPrimary, textSecondary)
                : Column(
                    children: [
                      const SizedBox(height: 12),
                      _buildTopTabBar(isDark, cardBg, borderColor, textPrimary, textSecondary),
                      Expanded(
                        child: _selectedTab == 0
                            ? _buildPrayerEntry(isDark, cardBg, borderColor, textPrimary, textSecondary)
                            : _buildCommunityWall(isDark, cardBg, borderColor, textPrimary, textSecondary),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildTopTabBar(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? const Color(0xFF4F46E5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'Personal Prayer',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      color: _selectedTab == 0 ? Colors.white : textSecondary,
                      fontSize: 13,
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? const Color(0xFF4F46E5) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 16,
                        color: _selectedTab == 1 ? Colors.white : textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Community Wall',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 1 ? Colors.white : textSecondary,
                          fontSize: 13,
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

  Widget _buildPrayerEntry(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
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
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFF6366F1),
                          Color(0xFF4F46E5),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4F46E5).withOpacity(0.35),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.volunteer_activism_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'Prayer Room',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: isDark ? const Color(0xFFFFC857) : const Color(0xFF0F172A),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Share what is on your heart. yo-ETS will lead you in prayer.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              // Prayer request input
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _requestController,
                  maxLines: 4,
                  style: TextStyle(fontFamily: 'Poppins', color: textPrimary, fontSize: 14.5),
                  decoration: InputDecoration(
                    hintText: 'Lord, I come to You today regarding...\n\nType your prayer request or burden here.',
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      color: textSecondary.withOpacity(0.7),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Community Wall Options
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _makePublic,
                          activeColor: const Color(0xFF4F46E5),
                          onChanged: (val) => setState(() => _makePublic = val ?? false),
                        ),
                        Expanded(
                          child: Text(
                            'Share request on Community Prayer Wall',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
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
                            activeColor: const Color(0xFF4F46E5),
                            onChanged: (val) => setState(() => _postAnonymously = val ?? true),
                          ),
                          Expanded(
                            child: Text(
                              'Post Anonymously',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Pray with me button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _beginPrayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.volunteer_activism_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Pray With Me',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommunityWall(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    if (_loadingCommunity) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
      );
    }

    if (_communityPrayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volunteer_activism_outlined, size: 48, color: textSecondary.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No public prayers yet.\nBe the first to share your prayer request!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                color: textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCommunityPrayers,
      color: const Color(0xFF4F46E5),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
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
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFF4F46E5).withOpacity(0.12),
                          child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          author,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                            fontSize: 13.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time_rounded, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Community',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: textSecondary,
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
                        color: textPrimary,
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _prayForCommunityItem(id, index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🙏', style: TextStyle(fontSize: 13)),
                              const SizedBox(width: 6),
                              Text(
                                'I prayed for this ($prayedCount)',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF4F46E5),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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
        ),
      ),
    );
  }

  Widget _buildPrayerResponse(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    return Column(
      children: [
        // Top bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: textSecondary),
                onPressed: () {
                  TtsService.instance.stop();
                  setState(() {
                    _prayerStarted = false;
                    _prayerResponse = null;
                    _requestController.clear();
                  });
                },
              ),
              const SizedBox(width: 8),
              Text(
                'Your Guided Prayer',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  color: textPrimary,
                  fontSize: 17,
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
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4F46E5).withOpacity(0.12),
                            border: Border.all(
                              color: const Color(0xFF4F46E5).withOpacity(0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.volunteer_activism_rounded,
                            color: Color(0xFF4F46E5),
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'yo-ETS is preparing your prayer...',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4F46E5).withOpacity(0.12),
                              ),
                              child: const Icon(
                                Icons.volunteer_activism_rounded,
                                color: Color(0xFF4F46E5),
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _prayerResponse ?? '',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: textPrimary,
                                fontSize: 15,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                if (_prayerResponse != null) {
                                  TtsService.instance.toggleSpeak(_prayerResponse!);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              icon: const Icon(Icons.volume_up_rounded, size: 18),
                              label: const Text(
                                'Listen Aloud',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.bold,
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
      ],
    );
  }
}
