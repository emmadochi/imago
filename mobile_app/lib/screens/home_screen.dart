import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../theme/imago_theme.dart';
import '../services/tts_service.dart';
import '../services/auth_service.dart';
import 'dictionary_screen.dart';
import 'journal_list_screen.dart';
import 'reading_plans_screen.dart';
import 'bible_lists_screen.dart';
import 'partner_screen.dart';
import 'scripture_projector_screen.dart';
import '../widgets/feedback_dialog.dart';

class HomeScreen extends StatefulWidget {
  final void Function(int index)? onNavigate;
  const HomeScreen({super.key, this.onNavigate});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _todayDevotional;
  bool _loadingDevotional = true;
  StreamSubscription<User?>? _authSub;

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
    try {
      _authSub = FirebaseAuth.instance.userChanges().listen((_) {
        if (mounted) setState(() {});
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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
    final isDark = ImagoColors.isDark;
    final String verse = data['verse'] ?? '';
    final String text = data['text'] ?? '';
    final String theme = data['theme'] ?? 'Devotional';
    final String reflection = data['reflection'] ?? '';
    final String actionStep = data['action_step'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? ImagoColors.surface : Colors.white,
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
                        color: isDark ? ImagoColors.secondaryText.withOpacity(0.3) : const Color(0xFFCBD5E1),
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
                          color: isDark ? ImagoColors.violet.withOpacity(0.18) : const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          theme,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: isDark ? ImagoColors.violet : const Color(0xFF4F46E5),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
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
                      color: isDark ? ImagoColors.gold : const Color(0xFFB45309),
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? ImagoColors.cardBackground : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: isDark ? ImagoColors.primaryText.withOpacity(0.9) : const Color(0xFF1E293B),
                        fontSize: 14.5,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pastoral Reflection',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reflection,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                  if (actionStep.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? ImagoColors.violet.withOpacity(0.12) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? ImagoColors.violet.withOpacity(0.25) : const Color(0xFFC7D2FE)),
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
                                color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
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
                  ValueListenableBuilder<bool>(
                    valueListenable: TtsService.instance.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            TtsService.instance.stop();
                          } else {
                            final speechText = "$verse. $text. Pastoral Reflection: $reflection. Action step: $actionStep";
                            TtsService.instance.speak(speechText);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isPlaying
                                ? const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFBE123C)])
                                : ImagoColors.violetGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isPlaying ? const Color(0xFFE11D48) : const Color(0xFF6366F1)).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isPlaying ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isPlaying ? 'Stop Reflection Audio' : 'Listen to Today\'s Reflection',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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
            : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

        String rawName = AuthService.instance.currentDisplayName;
        if (rawName.isEmpty) rawName = 'Beloved';
        final firstName = rawName.split(' ').first;
        final hour = DateTime.now().hour;
        final greeting = hour < 12
            ? 'Good morning'
            : hour < 17
                ? 'Good afternoon'
                : 'Good evening';

        return Scaffold(
          backgroundColor: bg,
          body: Stack(
            children: [
              CosmicBackground(children: const []),

              // Ambient glow (GPU-efficient radial gradient without raster blur)
              Positioned(
                top: 40,
                right: -40,
                child: IgnorePointer(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          ImagoColors.violet.withOpacity(isDark ? 0.12 : 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 840),
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
                                      color: textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    firstName,
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      color: isDark ? ImagoColors.gold : textPrimary,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Share Feedback & Validate',
                                    icon: Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: isDark ? ImagoColors.violet.withOpacity(0.12) : const Color(0xFFEEF2FF),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? ImagoColors.violet.withOpacity(0.3) : const Color(0xFFC7D2FE),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.rate_review_rounded,
                                        color: isDark ? ImagoColors.violet : const Color(0xFF4F46E5),
                                        size: 18,
                                      ),
                                    ),
                                    onPressed: () => FeedbackDialog.show(context, screenContext: 'home_header'),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: ImagoColors.violetGradient,
                                    ),
                                    child: CircleAvatar(
                                      radius: 22,
                                      backgroundColor: isDark ? ImagoColors.surface : const Color(0xFFF1F5F9),
                                      child: Text(
                                        firstName.isNotEmpty ? firstName[0] : 'I',
                                        style: TextStyle(
                                          fontFamily: 'Cinzel',
                                          color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Today's Date banner
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()).toUpperCase(),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: textSecondary.withOpacity(0.8),
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
                                  color: textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_loadingDevotional)
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: isDark ? ImagoColors.violet : const Color(0xFF4F46E5),
                                  ),
                                ),
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
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isDark ? ImagoColors.violet.withOpacity(0.35) : const Color(0xFFE2E8F0),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark
                                          ? ImagoColors.violet.withOpacity(0.12)
                                          : const Color(0xFF64748B).withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: isDark ? ImagoColors.violet.withOpacity(0.18) : const Color(0xFFEEF2FF),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _todayDevotional!['theme'] ?? 'Devotional',
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              color: isDark ? ImagoColors.violet : const Color(0xFF4F46E5),
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
                                                color: textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Icon(Icons.chevron_right_rounded, size: 16, color: textSecondary),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _todayDevotional!['verse'] ?? '',
                                      style: TextStyle(
                                        fontFamily: 'Cinzel',
                                        color: isDark ? ImagoColors.gold : const Color(0xFFB45309),
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
                                        color: isDark ? textPrimary.withOpacity(0.85) : const Color(0xFF334155),
                                        fontSize: 13.5,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 28),

                          // Quick access
                          Text(
                            'Your Journey',
                            style: TextStyle(
                              fontFamily: 'Cinzel',
                              color: textPrimary,
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
                                onTap: () => widget.onNavigate?.call(2),
                                child: _quickCard(
                                  icon: Icons.auto_awesome_rounded,
                                  label: 'Ask yo-ETS',
                                  sublabel: 'AI Counseling',
                                  gradient: const [Color(0xFF5C6BC0), Color(0xFF3D5AFE)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => widget.onNavigate?.call(3),
                                child: _quickCard(
                                  icon: Icons.volunteer_activism_rounded,
                                  label: 'Prayer Mode',
                                  sublabel: 'Talk with God',
                                  gradient: const [Color(0xFF4285F4), Color(0xFF1976D2)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
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
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => widget.onNavigate?.call(1),
                                child: _quickCard(
                                  icon: Icons.menu_book_rounded,
                                  label: 'Bible',
                                  sublabel: 'Read the Word',
                                  gradient: const [Color(0xFF4DB6AC), Color(0xFF009688)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ScriptureProjectorScreen()),
                                ),
                                child: _quickCard(
                                  icon: Icons.present_to_all_rounded,
                                  label: 'Scripture Projector',
                                  sublabel: 'Worship & Screen Display',
                                  gradient: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
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
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const BibleListsScreen()),
                                ),
                                child: _quickCard(
                                  icon: Icons.queue_music_rounded,
                                  label: 'Scripture Playlists',
                                  sublabel: 'Listen to Bible Lists',
                                  gradient: const [Color(0xFF7E57C2), Color(0xFF512DA8)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
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
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PartnerScreen()),
                                ),
                                child: _quickCard(
                                  icon: Icons.favorite_rounded,
                                  label: 'Partner With Us',
                                  sublabel: 'Support the Mission',
                                  gradient: const [Color(0xFFFFC857), Color(0xFFFF9900)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => FeedbackDialog.show(context, screenContext: 'home_journey_grid'),
                                child: _quickCard(
                                  icon: Icons.rate_review_rounded,
                                  label: 'Feedback',
                                  sublabel: 'Help Shape yo-ETS',
                                  gradient: const [Color(0xFF26A69A), Color(0xFF00897B)],
                                  isDark: isDark,
                                  cardBg: cardBg,
                                  borderColor: borderColor,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _quickCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required List<Color> gradient,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? gradient[0].withOpacity(0.35) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF64748B).withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
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
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                ),
              ),
              Text(
                sublabel,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
