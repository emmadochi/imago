// lib/widgets/notification_settings_sheet.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../theme/imago_theme.dart';

class NotificationSettingsSheet extends StatefulWidget {
  const NotificationSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationSettingsSheet(),
    );
  }

  @override
  State<NotificationSettingsSheet> createState() => _NotificationSettingsSheetState();
}

class _NotificationSettingsSheetState extends State<NotificationSettingsSheet> {
  SharedPreferences? _prefs;
  bool _dailyVerse = true;
  bool _prayerReminder = true;
  bool _eveningPlaylist = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _dailyVerse = _prefs?.getBool('daily_verse_notify') ?? true;
      _prayerReminder = _prefs?.getBool('prayer_reminder_notify') ?? true;
      _eveningPlaylist = _prefs?.getBool('evening_playlist_notify') ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    await _prefs?.setBool(key, value);
    if (key == 'daily_verse_notify' && !value) {
      await NotificationService.instance.cancelNotification(101);
    } else if (key == 'prayer_reminder_notify' && !value) {
      await NotificationService.instance.cancelNotification(102);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = ImagoColors.isDark;
    final cardBg = isDark ? const Color(0xFF0F121C).withOpacity(0.96) : Colors.white;
    final borderColor = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? Colors.white.withOpacity(0.5) : const Color(0xFF64748B);
    final handleColor = isDark ? Colors.white.withOpacity(0.3) : const Color(0xFFCBD5E1);

    return Container(
      height: mediaQuery.size.height * 0.65,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title Header Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? ImagoColors.gold.withOpacity(0.15) : const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Push Notifications & Reminders",
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          Text(
                            "Daily Verse, Prayer & Playlist Reminders",
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: borderColor),

              // Settings Items
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5)))
                    : ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // Daily Verse Switch
                          _buildSwitchTile(
                            icon: Icons.menu_book_rounded,
                            title: "Daily Verse of the Day",
                            subtitle: "Receive inspirational morning scripture quotes at 7:00 AM",
                            value: _dailyVerse,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                            onChanged: (val) {
                              setState(() => _dailyVerse = val);
                              _saveSetting('daily_verse_notify', val);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Morning Declarations Switch
                          _buildSwitchTile(
                            icon: Icons.volunteer_activism_rounded,
                            title: "Morning Declarations & Prayer",
                            subtitle: "Daily quiet-time & prayer reminder at 8:30 AM",
                            value: _prayerReminder,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                            onChanged: (val) {
                              setState(() => _prayerReminder = val);
                              _saveSetting('prayer_reminder_notify', val);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Evening Playlist Switch
                          _buildSwitchTile(
                            icon: Icons.playlist_play_rounded,
                            title: "Evening Scripture Lineup",
                            subtitle: "Nightly reminder to listen to your Bible Playlists at 9:00 PM",
                            value: _eveningPlaylist,
                            isDark: isDark,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            borderColor: borderColor,
                            onChanged: (val) {
                              setState(() => _eveningPlaylist = val);
                              _saveSetting('evening_playlist_notify', val);
                            },
                          ),
                          const SizedBox(height: 28),

                          // Instant Test Push Notification Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                elevation: isDark ? 0 : 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.notifications_active_rounded, size: 20),
                              label: const Text(
                                "Send Test Push Notification",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Poppins',
                                ),
                              ),
                              onPressed: () async {
                                await NotificationService.instance.showInstantNotification(
                                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                                  title: "✨ Yoetz (Imago) Notification Test",
                                  body: "The Lord is my light and my salvation; whom shall I fear? (Psalm 27:1)",
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Test notification sent! Check your status bar.'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required bool isDark,
    required Color textPrimary,
    required Color textSecondary,
    required Color borderColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: isDark ? ImagoColors.gold : const Color(0xFF4F46E5), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 11,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: isDark ? ImagoColors.gold : const Color(0xFF4F46E5),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
