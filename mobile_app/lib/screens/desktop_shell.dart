// lib/screens/desktop_shell.dart
// Native Windows / Desktop shell for yo-ETS with persistent left sidebar,
// top workspace header bar, responsive master-detail layouts, and clean light theme.

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/imago_theme.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'bible_screen.dart';
import 'chat_screen.dart';
import 'prayer_screen.dart';
import 'reading_plans_screen.dart';
import 'dictionary_screen.dart';
import 'journal_list_screen.dart';
import 'partner_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'scripture_projector_screen.dart';
import '../widgets/feedback_dialog.dart';

class DesktopShell extends StatefulWidget {
  final int initialIndex;
  const DesktopShell({super.key, this.initialIndex = 0});

  @override
  State<DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends State<DesktopShell> {
  late int _selectedIndex;
  final Set<int> _loadedTabs = {};

  final List<Map<String, dynamic>> _navItems = [
    {
      'title': 'Dashboard',
      'subtitle': 'Daily Walk & Devotional',
      'icon': Icons.dashboard_rounded,
    },
    {
      'title': 'Bible Reader',
      'subtitle': 'Scripture & Commentary',
      'icon': Icons.menu_book_rounded,
    },
    {
      'title': 'Scripture Projector',
      'subtitle': 'Worship & Screen Display',
      'icon': Icons.present_to_all_rounded,
    },
    {
      'title': 'Yoets AI Counselor',
      'subtitle': 'Scriptural AI Guidance',
      'icon': Icons.auto_awesome_rounded,
    },
    {
      'title': 'Prayer Room',
      'subtitle': 'Intercession & Petitions',
      'icon': Icons.volunteer_activism_rounded,
    },
    {
      'title': 'Reading Plans',
      'subtitle': '9-Day, 30-Day & Yearly Tracks',
      'icon': Icons.calendar_month_rounded,
    },
    {
      'title': 'Bible Dictionary',
      'subtitle': 'Concordance & Definitions',
      'icon': Icons.auto_stories_rounded,
    },
    {
      'title': 'Spiritual Journal',
      'subtitle': 'Reflections & Notes',
      'icon': Icons.edit_note_rounded,
    },
    {
      'title': 'Ministry Partners',
      'subtitle': 'Fellowship & Community',
      'icon': Icons.handshake_rounded,
    },
    {
      'title': 'Profile & Settings',
      'subtitle': 'Preferences & Account',
      'icon': Icons.settings_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadedTabs.add(_selectedIndex);
    NotificationService.instance.init();
  }

  void _onNavigate(int index) {
    if (index >= 0 && index < _navItems.length) {
      setState(() {
        _selectedIndex = index;
        _loadedTabs.add(index);
      });
    }
  }

  void _onNavigateFromHome(int index) {
    if (index == 1) {
      _onNavigate(1); // Bible Reader
    } else if (index == 2) {
      _onNavigate(3); // yo-ETS AI Counselor
    } else if (index == 3) {
      _onNavigate(4); // Prayer Room
    } else {
      _onNavigate(index);
    }
  }

  Widget _buildTab(int index, Widget child) {
    // If not yet visited, keep unmounted to save RAM and CPU
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    // Pause all Tickers (animations) whenever this tab is not actively selected
    return TickerMode(
      enabled: _selectedIndex == index,
      child: child,
    );
  }

  Future<void> _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (readerThemeNotifier.value == ReaderThemeMode.day) {
      readerThemeNotifier.value = ReaderThemeMode.night;
      await prefs.setInt('readerTheme', ReaderThemeMode.night.index);
    } else {
      readerThemeNotifier.value = ReaderThemeMode.day;
      await prefs.setInt('readerTheme', ReaderThemeMode.day.index);
    }
  }

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ImagoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ImagoColors.borderColor),
        ),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: ImagoColors.violet, size: 22),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ImagoColors.primaryText,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of your yo-ETS account?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13.5,
            color: ImagoColors.secondaryText,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                color: ImagoColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('guest_mode', false);
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            onContinue: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const DesktopShell()),
              );
            },
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final currentItem = _navItems[_selectedIndex];
        final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC),
          body: Row(
            children: [
              // ── Left Sidebar Navigation (250px) ──────────────────
              Container(
                width: 250,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // App Branding Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4F46E5).withOpacity(0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'yo-ETS',
                                      style: TextStyle(
                                        fontFamily: 'Cinzel',
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'WIN',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF4F46E5),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Digital Ministry Platform',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Navigation List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        itemCount: _navItems.length,
                        itemBuilder: (context, index) {
                          final item = _navItems[index];
                          final isSelected = _selectedIndex == index;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                onTap: () => _onNavigate(index),
                                borderRadius: BorderRadius.circular(10),
                                hoverColor: isDark
                                    ? const Color(0xFF1E293B).withOpacity(0.6)
                                    : const Color(0xFFF1F5F9),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? (isDark
                                            ? const Color(0xFF4F46E5).withOpacity(0.2)
                                            : const Color(0xFFEEF2FF))
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(
                                            color: isDark
                                                ? const Color(0xFF4F46E5).withOpacity(0.4)
                                                : const Color(0xFFC7D2FE),
                                            width: 1,
                                          )
                                        : null,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item['icon'] as IconData,
                                        size: 19,
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item['title'] as String,
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 13,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            color: isSelected
                                                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                                : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                                          ),
                                        ),
                                      ),
                                      if (isSelected)
                                        Container(
                                          width: 5,
                                          height: 5,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF4F46E5),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Sidebar Footer: Theme Toggle & User Account Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Early Validation / Feedback Button
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => FeedbackDialog.show(context, screenContext: 'desktop_workstation'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF4F46E5).withOpacity(0.12) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF4F46E5).withOpacity(0.3) : const Color(0xFFC7D2FE),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.rate_review_rounded,
                                      size: 16,
                                      color: Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Share Feedback',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF3730A3),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'BETA',
                                        style: TextStyle(fontSize: 9, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Theme Switch Button
                          Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: _toggleTheme,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFFFFC857) : const Color(0xFF4F46E5),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isDark ? 'Switch to Light' : 'Switch to Dark',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11.5,
                                          color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // User Account Preview Tile
                          StreamBuilder<User?>(
                            stream: () {
                              try {
                                return FirebaseAuth.instance.userChanges();
                              } catch (_) {
                                return Stream<User?>.value(null);
                              }
                            }(),
                            builder: (context, snapshot) {
                              final user = snapshot.data;
                              String name = user?.displayName ?? AuthService.instance.currentDisplayName;
                              if (name.isEmpty) name = 'Beloved Pilgrim';
                              final email = user?.email ?? 'Member';

                              return Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 15,
                                      backgroundColor: const Color(0xFF4F46E5),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'Y',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
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
                                            email,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.logout_rounded, size: 16),
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      tooltip: 'Sign Out',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: _confirmSignOut,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Right Main Workspace Area ─────────────────────────
              Expanded(
                child: Column(
                  children: [
                    // Top App Bar / Header Bar
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border(
                          bottom: BorderSide(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 18,
                              height: 18,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'yo-ETS',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              '›',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            currentItem['title'] as String,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const Spacer(),
                          // Date Display
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event_note_rounded,
                                  size: 14,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active View Content
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          _buildTab(0, HomeScreen(onNavigate: (i) => _onNavigateFromHome(i))),
                          _buildTab(1, const BibleScreen()),
                          _buildTab(2, const ScriptureProjectorScreen()),
                          _buildTab(3, const ChatScreen()),
                          _buildTab(4, const PrayerScreen()),
                          _buildTab(5, const ReadingPlansScreen()),
                          _buildTab(6, const DictionaryScreen()),
                          _buildTab(7, const JournalListScreen()),
                          _buildTab(8, const PartnerScreen()),
                          _buildTab(9, const ProfileScreen()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
