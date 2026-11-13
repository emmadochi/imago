import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'saved_verses_screen.dart';
import 'main_shell.dart';
import 'partner_screen.dart';
import '../services/user_data_service.dart';
import '../services/tracking_service.dart';
import '../services/auth_service.dart';
import '../widgets/notification_settings_sheet.dart';
import '../widgets/feedback_dialog.dart';
import '../services/lcm_bridge.dart';
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
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _loadStats();
    try {
      _authSub = FirebaseAuth.instance.userChanges().listen((user) {
        if (mounted) {
          _loadStats();
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStats() async {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (_) {}
    if (user != null) {
      try {
        await user.reload();
      } catch (_) {}
    }

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
  }

  Future<void> _changeReaderTheme(ReaderThemeMode mode) async {
    readerThemeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('readerTheme', mode.index);
  }

  void _showResetPasswordConfirm(BuildContext context, String email) {
    final isDark = ImagoColors.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ImagoColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
        ),
        title: Text(
          'Reset Password',
          style: TextStyle(fontFamily: 'Cinzel', color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Send a password reset link to $email?',
          style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService.instance.sendPasswordResetEmail(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: Text('Password reset email sent to $email! Please check your inbox.'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: const Text('Failed to send password reset email. Please try again.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Send Link', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLegalNoticesDialog(BuildContext context) {
    final isDark = ImagoColors.isDark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? ImagoColors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
        ),
        title: Row(
          children: [
            Icon(Icons.gavel_rounded, color: isDark ? ImagoColors.gold : const Color(0xFFB45309), size: 22),
            const SizedBox(width: 10),
            Text(
              'Sacred Content & IP Notices',
              style: TextStyle(fontFamily: 'Cinzel', color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Berean Standard Bible (BSB)',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.gold : const Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'The Holy Bible, Berean Standard Bible, BSB is dedicated to the public domain through Creative Commons Zero (CC0) by Bible Hub and Berean.Bible.',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569), fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Public Domain Scriptures & Commentaries',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.gold : const Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'King James Version (KJV), American Standard Version (ASV), Young\'s Literal Translation (YLT), Bible in Basic English (BBE), Chinese Union Version (CUV 1919), Louis Segond (LSG 1910), Matthew Henry Commentary, Adam Clarke Commentary, Albert Barnes Notes, JFB Commentary, and Easton\'s Bible Dictionary are in the Public Domain worldwide.',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569), fontSize: 11.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Visual Art & Typography',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.gold : const Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'Illustrations by Gustave Doré (1866) — Public Domain. Fonts Cinzel & Poppins licensed under the SIL Open Font License 1.1.',
                  style: TextStyle(fontFamily: 'Poppins', color: isDark ? ImagoColors.secondaryText : const Color(0xFF475569), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showThemePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
          builder: (context, _) {
            final isDark = ImagoColors.isDark;
            final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
            final sheetBg = isDark
                ? const Color(0xFF0E0B24)
                : (isParchment ? const Color(0xFFFAF6EE) : Colors.white);
            final sheetBorder = isDark
                ? const Color(0xFF1E293B)
                : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0));
            final titleColor = isDark
                ? ImagoColors.gold
                : (isParchment ? const Color(0xFF9A6B2F) : const Color(0xFF4F46E5));
            final textSec = isDark
                ? const Color(0xFF94A3B8)
                : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

            return Container(
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: sheetBorder),
              ),
              child: StatefulBuilder(
                builder: (context, setSheetState) {
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 24,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Appearance & Theme',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  color: titleColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close_rounded, color: textSec),
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Personalize your yo-ETS experience with day/night lighting modes and celestial color palettes.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: textSec,
                              fontSize: 13.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'LIGHTING MODE',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: textSec,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildLightingModeCard(
                          mode: ReaderThemeMode.night,
                          title: 'Midnight',
                          subtitle: 'Celestial Dark',
                          icon: Icons.dark_mode_rounded,
                          bgColor: const Color(0xFF0B132B),
                          textColor: Colors.white,
                          onTap: () async {
                            await _changeReaderTheme(ReaderThemeMode.night);
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildLightingModeCard(
                          mode: ReaderThemeMode.parchment,
                          title: 'Parchment',
                          subtitle: 'Sacred Papyrus',
                          icon: Icons.auto_stories_rounded,
                          bgColor: const Color(0xFFF7F2E7),
                          textColor: const Color(0xFF2C241D),
                          onTap: () async {
                            await _changeReaderTheme(ReaderThemeMode.parchment);
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(width: 8),
                        _buildLightingModeCard(
                          mode: ReaderThemeMode.day,
                          title: 'Alabaster',
                          subtitle: 'Clean Linen',
                          icon: Icons.light_mode_rounded,
                          bgColor: const Color(0xFFF5F7FA),
                          textColor: const Color(0xFF19202C),
                          onTap: () async {
                            await _changeReaderTheme(ReaderThemeMode.day);
                            setSheetState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'ACCENT PALETTE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.secondaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      title: 'Deep Violet',
                      subtitle: 'The original vibrant cosmic aesthetic',
                      mode: AppThemeMode.violet,
                      primaryColor: const Color(0xFF3D5AFE),
                      secondaryColor: const Color(0xFF1B1147),
                      onTap: () async {
                        await _changeTheme(AppThemeMode.violet);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildThemeOption(
                      title: 'Illuminated Gold',
                      subtitle: 'Classic manuscript elegance',
                      mode: AppThemeMode.gold,
                      primaryColor: const Color(0xFFD4AF37),
                      secondaryColor: const Color(0xFF2A1F1D),
                      onTap: () async {
                        await _changeTheme(AppThemeMode.gold);
                        setSheetState(() {});
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildThemeOption(
                      title: 'Tranquil Azure',
                      subtitle: 'Calming deep sea serenity',
                      mode: AppThemeMode.azure,
                      primaryColor: const Color(0xFF00B4D8),
                      secondaryColor: const Color(0xFF0D1B2A),
                      onTap: () async {
                        await _changeTheme(AppThemeMode.azure);
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
},
);
  }

  Widget _buildLightingModeCard({
    required ReaderThemeMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    final isSelected = readerThemeNotifier.value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? ImagoColors.gold : ImagoColors.borderColor,
              width: isSelected ? 2.2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: ImagoColors.gold.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? ImagoColors.gold : textColor.withOpacity(0.8), size: 22),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: textColor.withOpacity(0.6),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required AppThemeMode mode,
    required Color primaryColor,
    required Color secondaryColor,
    required VoidCallback onTap,
  }) {
    final isSelected = appThemeNotifier.value == mode;
    final isDark = ImagoColors.isDark;
    final isParchment = readerThemeNotifier.value == ReaderThemeMode.parchment;
    final optCardBg = isSelected
        ? primaryColor.withOpacity(isDark ? 0.2 : 0.12)
        : (isDark
            ? const Color(0xFF131D33)
            : (isParchment ? const Color(0xFFFFFDF8) : const Color(0xFFF8FAFC)));
    final optBorder = isSelected
        ? primaryColor
        : (isDark
            ? const Color(0xFF1E293B)
            : (isParchment ? const Color(0xFFE5DAC6) : const Color(0xFFE2E8F0)));
    final optTextPrimary = isDark
        ? Colors.white
        : (isParchment ? const Color(0xFF2C241D) : const Color(0xFF0F172A));
    final optTextSecondary = isDark
        ? const Color(0xFF94A3B8)
        : (isParchment ? const Color(0xFF6B5E54) : const Color(0xFF64748B));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: optCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: optBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: optTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: optTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: primaryColor, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = ImagoColors.isDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? ImagoColors.cardBackground : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? ImagoColors.borderColor : const Color(0xFFE2E8F0)),
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? ImagoColors.violet.withOpacity(0.15) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDark ? ImagoColors.violet : const Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? ImagoColors.primaryText : const Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isDark ? ImagoColors.secondaryText : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? ImagoColors.secondaryText.withOpacity(0.6) : const Color(0xFF94A3B8)),
          ],
        ),
      ),
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

        return StreamBuilder<User?>(
          stream: () {
            try {
              return FirebaseAuth.instance.userChanges();
            } catch (_) {
              return Stream<User?>.value(null);
            }
          }(),
          builder: (context, snapshot) {
            final bool isGuest = !AuthService.instance.isLoggedIn;
            final String displayName = AuthService.instance.currentDisplayName;
            final String currentEmail = AuthService.instance.currentEmail;
            final email = isGuest ? 'Sign in to sync your cloud profile' : (currentEmail.isNotEmpty ? currentEmail : 'Verified Account');
            final badgeText = isGuest ? 'Guest Mode' : 'Verified Member';
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
              backgroundColor: bg,
              body: Stack(
                children: [
                  CosmicBackground(children: const []),

                  Positioned(
                    top: -40,
                    left: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 240,
                        height: 240,
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
                              Text(
                                'My Profile',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  color: isDark ? ImagoColors.gold : textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Profile card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: borderColor),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isDark ? Colors.black.withOpacity(0.2) : const Color(0xFF64748B).withOpacity(0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: ImagoColors.violetGradient,
                                      ),
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: isDark ? ImagoColors.surface : const Color(0xFFF1F5F9),
                                        child: Text(
                                          firstName.isNotEmpty ? firstName[0] : 'I',
                                          style: TextStyle(
                                            color: isDark ? ImagoColors.primaryText : const Color(0xFF4F46E5),
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: TextStyle(
                                              fontFamily: 'Cinzel',
                                              color: textPrimary,
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              color: textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ValueListenableBuilder<String>(
                                            valueListenable: AuthService.instance.partnerTierNotifier,
                                            builder: (context, currentTier, _) {
                                              final bool isPartner = currentTier != 'Free' && currentTier.trim().isNotEmpty;
                                              return Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: isGuest
                                                          ? (isDark ? ImagoColors.secondaryText.withOpacity(0.08) : const Color(0xFFF1F5F9))
                                                          : (isDark ? ImagoColors.violet.withOpacity(0.18) : const Color(0xFFEEF2FF)),
                                                      borderRadius: BorderRadius.circular(20),
                                                      border: Border.all(
                                                        color: isGuest
                                                            ? borderColor
                                                            : (isDark ? ImagoColors.violet.withOpacity(0.4) : const Color(0xFFC7D2FE)),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      badgeText,
                                                      style: TextStyle(
                                                        fontFamily: 'Poppins',
                                                        color: isGuest
                                                            ? textSecondary
                                                            : (isDark ? ImagoColors.violet : const Color(0xFF4F46E5)),
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                  if (isPartner)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: isDark
                                                              ? [const Color(0xFFFFC857).withOpacity(0.22), const Color(0xFFFF9900).withOpacity(0.15)]
                                                              : [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)],
                                                        ),
                                                        borderRadius: BorderRadius.circular(20),
                                                        border: Border.all(
                                                          color: isDark ? const Color(0xFFFFC857).withOpacity(0.5) : const Color(0xFFD97706),
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Text('👑', style: TextStyle(fontSize: 11)),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            currentTier,
                                                            style: TextStyle(
                                                              fontFamily: 'Poppins',
                                                              color: isDark ? const Color(0xFFFFC857) : const Color(0xFFB45309),
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // Spiritual Growth Stats
                              Text(
                                'Spiritual Journey Stats',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Row(
                                children: stats.entries.map((entry) {
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                                      decoration: BoxDecoration(
                                        color: cardBg,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: borderColor),
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
                                        children: [
                                          Text(
                                            entry.value.split(' ').first,
                                            style: TextStyle(
                                              fontFamily: 'Cinzel',
                                              color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              entry.key,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                color: textSecondary,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w500,
                                              ),
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
                              Text(
                                '7-Day Mood Journey',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),

                              const SizedBox(height: 12),

                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: borderColor),
                                  boxShadow: isDark
                                      ? null
                                      : [
                                          BoxShadow(
                                            color: const Color(0xFF64748B).withOpacity(0.06),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: moodHistory.map((entry) {
                                    final double val = (entry['value'] as double);
                                    final gradient = val > 0.6
                                        ? [const Color(0xFF6366F1), const Color(0xFF06B6D4)]
                                        : val > 0.35
                                            ? [const Color(0xFF3B82F6), const Color(0xFF6366F1)]
                                            : [
                                                isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                                                const Color(0xFF6366F1),
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
                                            color: textSecondary,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),

                              const SizedBox(height: 28),

                              // ─── Partner Banner ──────────────────────────
                              ValueListenableBuilder<String>(
                                valueListenable: AuthService.instance.partnerTierNotifier,
                                builder: (context, activeTier, _) {
                                  final bool isKingdomPartner = activeTier != 'Free' && activeTier.trim().isNotEmpty;
                                  return GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const PartnerScreen()),
                                    ),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isDark
                                              ? [
                                                  ImagoColors.gold.withOpacity(0.12),
                                                  ImagoColors.violet.withOpacity(0.08),
                                                ]
                                              : [
                                                  const Color(0xFFFEF3C7),
                                                  const Color(0xFFEEF2FF),
                                                ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isDark ? ImagoColors.gold.withOpacity(0.3) : const Color(0xFFFDE68A),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: isDark
                                                ? ImagoColors.gold.withOpacity(0.08)
                                                : const Color(0xFFB45309).withOpacity(0.06),
                                            blurRadius: 16,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isDark
                                                    ? [
                                                        ImagoColors.gold.withOpacity(0.25),
                                                        ImagoColors.violet.withOpacity(0.18),
                                                      ]
                                                    : [
                                                        const Color(0xFFFDE68A),
                                                        const Color(0xFFE0E7FF),
                                                      ],
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Text(isKingdomPartner ? '👑' : '✨', style: const TextStyle(fontSize: 22)),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isKingdomPartner ? 'Active Partner: $activeTier' : 'Partner With Us',
                                                  style: TextStyle(
                                                    fontFamily: 'Cinzel',
                                                    color: isDark ? ImagoColors.gold : const Color(0xFFB45309),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  isKingdomPartner
                                                      ? 'Thank you for standing with this ministry! Tap to manage.'
                                                      : 'Support the mission. Keep the Word free.',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: textSecondary,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            color: isDark ? ImagoColors.gold.withOpacity(0.8) : const Color(0xFFB45309),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 28),

                              // Settings
                              Text(
                                'Preferences',
                                style: TextStyle(
                                  fontFamily: 'Cinzel',
                                  color: textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
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
                                title: 'Notifications & Reminders',
                                subtitle: 'Daily verse, morning prayer & playlist alerts',
                                onTap: () {
                                  NotificationSettingsSheet.show(context);
                                },
                              ),

                              _buildSettingTile(
                                icon: Icons.color_lens_rounded,
                                title: 'Theme & Appearance',
                                subtitle: "Lighting modes (Day/Night) & color accents",
                                onTap: _showThemePicker,
                              ),

                              _buildSettingTile(
                                icon: Icons.rate_review_rounded,
                                title: 'Help Shape yo-ETS (Early Feedback)',
                                subtitle: 'Share your validation, feature ideas, or testimonies',
                                onTap: () {
                                  FeedbackDialog.show(context, screenContext: 'profile_settings');
                                },
                              ),

                              _buildSettingTile(
                                icon: Icons.bug_report_rounded,
                                title: 'Beta Feedback & Bug Report',
                                subtitle: 'Direct report to LDTL engineering team on LCMWorld',
                                onTap: () {
                                  LcmBridge.showFeedbackDialog(context);
                                },
                              ),

                              _buildSettingTile(
                                icon: Icons.system_update_rounded,
                                title: 'Check for Updates (OTA)',
                                subtitle: 'Verify if a newer build is available on LCMWorld',
                                onTap: () {
                                  LcmBridge.checkForUpdates(context, showToastIfLatest: true);
                                },
                              ),

                              _buildSettingTile(
                                icon: Icons.gavel_rounded,
                                title: 'Legal & Content Licensing Notices',
                                subtitle: 'Public domain scriptures, CC0 & third-party attributions',
                                onTap: () => _showLegalNoticesDialog(context),
                              ),

                              _buildSettingTile(
                                icon: Icons.download_rounded,
                                title: 'Export Data',
                                subtitle: 'Download your journal entries',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data export coming soon')));
                                },
                              ),

                              if (!isGuest && currentEmail.isNotEmpty)
                                _buildSettingTile(
                                  icon: Icons.lock_reset_rounded,
                                  title: 'Reset Password',
                                  subtitle: 'Send password reset link to $currentEmail',
                                  onTap: () => _showResetPasswordConfirm(context, currentEmail),
                                ),

                              const SizedBox(height: 28),

                              // Sign out / Sign in button
                              GestureDetector(
                                onTap: () {
                                  if (!isGuest) {
                                    _signOut(context);
                                  } else {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => LoginScreen(
                                          onContinue: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ),
                                    ).then((_) => _loadStats());
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: (!isGuest ? Colors.redAccent : const Color(0xFF4F46E5)).withOpacity(isDark ? 0.12 : 0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: (!isGuest ? Colors.redAccent : const Color(0xFF4F46E5)).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        !isGuest ? Icons.logout_rounded : Icons.login_rounded,
                                        color: !isGuest ? Colors.redAccent : const Color(0xFF4F46E5),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        !isGuest ? 'Sign Out' : 'Sign In / Create Account',
                                        style: TextStyle(
                                          color: !isGuest ? Colors.redAccent : const Color(0xFF4F46E5),
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
}
