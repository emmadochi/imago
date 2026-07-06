import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TrackingService {
  TrackingService._();
  static final TrackingService instance = TrackingService._();

  // Keys
  static const String _kConversations = 'spiritual_track_conversations';
  static const String _kPrayerLastDate = 'spiritual_track_prayer_last_date';
  static const String _kPrayerStreak = 'spiritual_track_prayer_streak';
  static const String _kMoodHistory = 'spiritual_track_mood_history';

  // --- Chats ---
  Future<int> getConversationsCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kConversations) ?? 0;
  }

  Future<void> incrementConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kConversations) ?? 0;
    await prefs.setInt(_kConversations, current + 1);
  }

  // --- Prayer Streak ---
  Future<int> getPrayerStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kPrayerStreak) ?? 0;
  }

  Future<void> logPrayerGenerated() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_kPrayerLastDate);
    final todayStr = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD

    if (lastDateStr == todayStr) {
      // Already prayed today, do nothing
      return;
    }

    int streak = prefs.getInt(_kPrayerStreak) ?? 0;

    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final today = DateTime.now();
      final difference = today.difference(lastDate).inDays;

      if (difference == 1) {
        // Continued streak
        streak += 1;
      } else {
        // Streak broken
        streak = 1;
      }
    } else {
      // First prayer
      streak = 1;
    }

    await prefs.setString(_kPrayerLastDate, todayStr);
    await prefs.setInt(_kPrayerStreak, streak);
  }

  // --- Mood History ---
  /// Returns a list of maps containing 'day' (String), 'mood' (String), and 'value' (double 0.0-1.0)
  Future<List<Map<String, dynamic>>> getMoodHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString(_kMoodHistory);
    
    if (jsonStr == null) {
      return [];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Logs the mood. Overwrites if already logged today.
  Future<void> logMood(String moodName, double intensity) async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    
    final daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayName = daysOfWeek[DateTime.now().weekday - 1];

    List<Map<String, dynamic>> history = await getMoodHistory();

    // Check if we already logged today
    final todayIndex = history.indexWhere((element) => element['date'] == todayStr);
    
    if (todayIndex >= 0) {
      history[todayIndex] = {
        'date': todayStr,
        'day': dayName,
        'mood': moodName,
        'value': intensity,
      };
    } else {
      history.add({
        'date': todayStr,
        'day': dayName,
        'mood': moodName,
        'value': intensity,
      });
    }

    // Keep only the last 7 days
    if (history.length > 7) {
      history = history.sublist(history.length - 7);
    }

    await prefs.setString(_kMoodHistory, jsonEncode(history));
  }
}
