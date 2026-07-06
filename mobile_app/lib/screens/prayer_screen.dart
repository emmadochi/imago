import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/imago_theme.dart';
import '../services/tracking_service.dart';

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

  final String _backendUrl = "http://10.0.2.2:8000";

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _levitationController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _beginPrayer() async {
    final request = _requestController.text.trim();
    if (request.isEmpty) return;

    setState(() {
      _isLoading = true;
      _prayerStarted = true;
      _prayerResponse = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/api/prayer'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'request': request}),
      ).timeout(const Duration(seconds: 15));

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
            child: _prayerStarted ? _buildPrayerResponse() : _buildPrayerEntry(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerEntry() {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
                width: 110,
                height: 110,
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
                  size: 44,
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          const Text(
            'Prayer Mode',
            style: TextStyle(
              fontFamily: 'Cinzel',
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Share what is on your heart.\nImago will lead you in prayer.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.white.withOpacity(0.45),
              fontSize: 14.5,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 36),

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
                    hintText:
                        'Lord, I come to you today about...\n\nShare your prayer request here.',
                    hintStyle: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.3), fontSize: 14.5, height: 1.5),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(18),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Pray with me button
          GestureDetector(
            onTap: _beginPrayer,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
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
                      fontSize: 16.5,
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
                onPressed: () => setState(() {
                  _prayerStarted = false;
                  _prayerResponse = null;
                  _requestController.clear();
                }),
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
                        'Imago is praying with you...',
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
