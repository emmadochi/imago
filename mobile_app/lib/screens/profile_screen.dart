import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';

import '../services/tracking_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _prayerStreak = 0;
  int _conversations = 0;
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

    if (mounted) {
      setState(() {
        _prayerStreak = streak;
        _conversations = chats;
        _moodHistory = moodHist;
        _isLoadingStats = false;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('has_onboarded');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
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
      'Saved Verses': '0 scriptures',
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
