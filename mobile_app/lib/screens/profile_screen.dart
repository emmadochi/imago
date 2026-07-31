import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'saved_verses_screen.dart';
import 'main_shell.dart';
import '../services/user_data_service.dart';
import '../services/tracking_service.dart';
import '../services/auth_service.dart';
import '../theme/imago_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _prayerStreak = 0;
  int _conversations = 0;
  int _savedVerses = 0;
  List<Map<String, dynamic>> _moodHistory = [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final streak = await TrackingService.instance.getPrayerStreak();
    final chats = await TrackingService.instance.getConversationsCount();
    final moodHist = await TrackingService.instance.getMoodHistory();
    final bookmarks = await UserDataService.instance.getBookmarks();

    if (mounted) {
      setState(() {
        _prayerStreak = streak;
        _conversations = chats;
        _savedVerses = bookmarks.length;
        _moodHistory = moodHist;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onContinue: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (route) => false,
            );
          },
        ),
      ),
      (route) => false,
    );
  }

  Future<void> _changeTheme(AppThemeMode mode) async {
    appThemeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('appTheme', mode.index);
    if (mounted) Navigator.pop(context);
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ImagoColors.deepSpace,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 40,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Theme Accent',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Personalize your yo-ETS experience by choosing a color palette that inspires you.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildThemeOption(
                title: 'Deep Violet',
                subtitle: 'The original vibrant cosmic aesthetic',
                mode: AppThemeMode.violet,
                primaryColor: const Color(0xFF3D5AFE),
                secondaryColor: const Color(0xFF1B1147),
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                title: 'Illuminated Gold',
                subtitle: 'Classic manuscript elegance',
                mode: AppThemeMode.gold,
                primaryColor: const Color(0xFFD4AF37),
                secondaryColor: const Color(0xFF2A1F1D),
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                title: 'Tranquil Azure',
                subtitle: 'Calming deep sea serenity',
                mode: AppThemeMode.azure,
                primaryColor: const Color(0xFF00B4D8),
                secondaryColor: const Color(0xFF0D1B2A),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    final isSelected = appThemeNotifier.value == mode;
    return GestureDetector(
      onTap: () => _changeTheme(mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.15) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white.withOpacity(0.08),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [primaryColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white24),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF6B4EFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF9B79FF), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? 'Beloved';
    final email = user?.email ?? '';
    final firstName = displayName.split(' ').first;

    final stats = {
      'Prayer Streak': '$_prayerStreak days 🔥',
      'Conversations': '$_conversations total',
      'Saved Verses': '$_savedVerses scriptures',
    };

    final moodHistory = _moodHistory.isNotEmpty ? _moodHistory : [
      {'day': 'No data', 'mood': 'Neutral', 'value': 0.1},
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF090A1A),
                  Color(0xFF0F112E),
                  Color(0xFF1E1736),
                  Color(0xFF090A1A),
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),

          Positioned(
            top: -40,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6B4EFF).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
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
                  const Text(
                    'My Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Profile card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF6B4EFF),
                                    Color(0xFF00C9FF)
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF1E1736),
                                child: Text(
                                  firstName.isNotEmpty ? firstName[0] : 'I',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.4),
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6B4EFF)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF6B4EFF)
                                            .withOpacity(0.3)),
                                  ),
                                  child: const Text(
                                    'Member',
                                    style: TextStyle(
                                        color: Color(0xFF9B79FF),
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Spiritual stats
                  const Text(
                    'Spiritual Stats',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: stats.entries.map((entry) {
                      return Expanded(
                        child: Container(
                          margin: EdgeInsets.only(
                            right: entry.key != 'Saved Verses' ? 10 : 0,
                          ),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.07)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                entry.key,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // Mood history
                  const Text(
                    '7-Day Mood Journey',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.white.withOpacity(0.07)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: moodHistory.map((entry) {
                        final double val = (entry['value'] as double);
                        final gradient = val > 0.6
                            ? [const Color(0xFF6B4EFF), const Color(0xFF00C9FF)]
                            : val > 0.35
                                ? [
                                    const Color(0xFF1A7FDB),
                                    const Color(0xFF6B4EFF)
                                  ]
                                : [
                                    const Color(0xFF444466),
                                    const Color(0xFF6B4EFF)
                                  ];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              width: 28,
                              height: (val * 80).clamp(8.0, 80.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradient,
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              entry['day'] as String,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Settings
                  const Text(
                    'Preferences',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 12),

                  _buildSettingTile(
                    icon: Icons.bookmark_rounded,
                    title: 'My Saved Verses',
                    subtitle: 'View your bookmarked scriptures',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedVersesScreen())).then((_) => _loadStats());
                    },
                  ),
                  
                  _buildSettingTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Daily Devotional',
                    subtitle: 'Set a reminder for your quiet time',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification settings coming soon')));
                    },
                  ),
                  
                  _buildSettingTile(
                    icon: Icons.color_lens_rounded,
                    title: 'Theme Accent',
                    subtitle: "Customize the app's colors",
                    onTap: _showThemePicker,
                  ),
                  
                  _buildSettingTile(
                    icon: Icons.download_rounded,
                    title: 'Export Data',
                    subtitle: 'Download your journal entries',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data export coming soon')));
                    },
                  ),

                  const SizedBox(height: 28),

                  // Sign out
                  GestureDetector(
                    onTap: () => _signOut(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Colors.redAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Sign Out',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
