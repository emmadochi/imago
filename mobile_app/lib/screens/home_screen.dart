import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../theme/imago_theme.dart';
import '../services/tts_service.dart';
import 'dictionary_screen.dart';
import 'journal_list_screen.dart';
import 'reading_plans_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _todayDevotional;
  bool _loadingDevotional = true;

  final String _backendUrl = "https://imago-1-wkzl.onrender.com";

  static const _fallbackDevotionals = [
    {
      'day': 'Today',
      'verse': 'Jeremiah 29:11',
      'text':
          '"For I know the plans I have for you," declares the Lord, "plans to prosper you and not to harm you, plans to give you hope and a future."',
      'theme': 'Purpose & Hope',
      'reflection': 'Beloved, God\'s plans for your life are not hindered by present circumstances. Walk with confidence knowing that His presence goes before you.',
      'action_step': 'Take 60 seconds today to quiet your heart and thank God for His faithful plans.',
    },
    {
      'day': 'Yesterday',
      'verse': 'Philippians 4:6-7',
      'text':
          'Do not be anxious about anything, but in every situation, by prayer and petition, with thanksgiving, present your requests to God.',
      'theme': 'Unshakable Peace',
      'reflection': 'Anxiety flees when prayer begins. When worries press upon your heart, bring them straight to the Father in thanksgiving.',
      'action_step': 'Identify one worry today and turn it into a direct prayer of thanksgiving.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchTodayDevotional();
  }

  Future<void> _fetchTodayDevotional() async {
    try {
      final res = await http.get(Uri.parse('$_backendUrl/api/devotional/today')).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _todayDevotional = data;
            _loadingDevotional = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _todayDevotional = _fallbackDevotionals[0];
        _loadingDevotional = false;
      });
    }
  }

  void _showDevotionalDetail(Map<String, dynamic> data) {
    final String verse = data['verse'] ?? '';
    final String text = data['text'] ?? '';
    final String theme = data['theme'] ?? 'Devotional';
    final String reflection = data['reflection'] ?? '';
    final String actionStep = data['action_step'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5C6BC0).withOpacity(0.25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          theme,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFF5C6BC0),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: () {
                          TtsService.instance.stop();
                          Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    verse,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.gold,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14.5,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Pastoral Reflection',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reflection,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if (actionStep.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5C6BC0).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.25)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Daily Action Step:\n$actionStep',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      final speechText = "$verse. $text. Pastoral Reflection: $reflection. Action step: $actionStep";
                      TtsService.instance.toggleSpeak(speechText);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Listen to Today\'s Reflection',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    String rawName = user?.displayName ?? '';
    if (rawName.isEmpty && user?.email != null && user!.email!.contains('@')) {
      rawName = user.email!.split('@').first;
      rawName = rawName[0].toUpperCase() + rawName.substring(1);
    }
    if (rawName.isEmpty) rawName = 'Beloved';
    final firstName = rawName.split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          const CosmicBackground(children: []),

          // Ambient glow
          Positioned(
            top: 80,
            right: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5C6BC0).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: const SizedBox.shrink(),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greeting,',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            firstName,
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.cream,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFF1B1147),
                          child: Text(
                            firstName.isNotEmpty ? firstName[0] : 'I',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: ImagoColors.gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Today's Date banner
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 11,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Today's Word section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Verse of the Day",
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: ImagoColors.cream,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_loadingDevotional)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5C6BC0))),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Hero Devotional Card
                  if (_todayDevotional != null)
                    GestureDetector(
                      onTap: () => _showDevotionalDetail(_todayDevotional!),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.35)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF3D5AFE).withOpacity(0.12),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5C6BC0).withOpacity(0.25),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        _todayDevotional!['theme'] ?? 'Devotional',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          color: Color(0xFF5C6BC0),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Tap to read',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white.withOpacity(0.4),
                                            fontSize: 11,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.chevron_right_rounded, size: 16, color: Colors.white.withOpacity(0.4)),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _todayDevotional!['verse'] ?? '',
                                  style: TextStyle(
                                    fontFamily: 'Cinzel',
                                    color: ImagoColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _todayDevotional!['text'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 13.5,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Quick access
                  Text(
                    'Your Journey',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.cream,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 16),

                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.4,
                    children: [
                      GestureDetector(
                        onTap: () => widget.onNavigate?.call(0),
                        child: _quickCard(
                          icon: Icons.auto_awesome_rounded,
                          label: 'Ask yo-ETS',
                          sublabel: 'AI Counseling',
                          gradient: const [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigate?.call(2),
                        child: _quickCard(
                          icon: Icons.volunteer_activism_rounded,
                          label: 'Prayer Mode',
                          sublabel: 'Talk with God',
                          gradient: const [Color(0xFF4285F4), Color(0xFF1976D2)],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const JournalListScreen()),
                        ),
                        child: _quickCard(
                          icon: Icons.edit_note_rounded,
                          label: 'Journal & Notes',
                          sublabel: 'Your reflections',
                          gradient: const [Color(0xFF9575CD), Color(0xFF673AB7)],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => widget.onNavigate?.call(1),
                        child: _quickCard(
                          icon: Icons.menu_book_rounded,
                          label: 'Bible',
                          sublabel: 'Read the Word',
                          gradient: const [Color(0xFF4DB6AC), Color(0xFF009688)],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ReadingPlansScreen()),
                        ),
                        child: _quickCard(
                          icon: Icons.track_changes_rounded,
                          label: 'Reading Plans',
                          sublabel: '30, 90 & 365 Days',
                          gradient: const [Color(0xFFFF9800), Color(0xFFF57C00)],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DictionaryScreen()),
                        ),
                        child: _quickCard(
                          icon: Icons.find_in_page_rounded,
                          label: 'Dictionary',
                          sublabel: 'Theological terms',
                          gradient: const [Color(0xFFF06292), Color(0xFFE91E63)],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 100), // nav bar padding
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradient[0].withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
