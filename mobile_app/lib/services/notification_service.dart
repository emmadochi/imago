import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes local notifications engine
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _isInitialized = true;
      _scheduleDefaultRemindersIfEnabled();
    } catch (e) {
      debugPrint("NotificationService initialization note: $e");
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap payload if needed
  }

  /// Sends an instant local push notification for testing or immediate alerts
  Future<void> showInstantNotification({
    int id = 1,
    required String title,
    required String body,
    String? payload,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'yoetz_instant_channel',
      'Yoetz Notifications',
      channelDescription: 'Instant spiritual notifications and alerts',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(id, title, body, details, payload: payload);
  }

  /// Schedules daily recurring notification at a specific time
  Future<void> scheduleDailyNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'yoetz_daily_channel',
      'Yoetz Daily Devotional',
      channelDescription: 'Daily Scripture and Prayer Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Schedule periodic or instant notification
    await _notificationsPlugin.periodicallyShow(
      id,
      title,
      body,
      RepeatInterval.daily,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Cancels a specific notification by ID
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Cancels all scheduled local notifications
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> _scheduleDefaultRemindersIfEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final bool dailyVerseEnabled = prefs.getBool('daily_verse_notify') ?? true;
    final bool prayerEnabled = prefs.getBool('prayer_reminder_notify') ?? true;

    if (dailyVerseEnabled) {
      await scheduleDailyNotification(
        id: 101,
        title: "📖 Verse of the Day — Yoetz",
        body: "The Lord is my shepherd; I shall not want. Tap to read today's scripture meditation.",
        hour: 7,
        minute: 0,
      );
    }
    if (prayerEnabled) {
      await scheduleDailyNotification(
        id: 102,
        title: "🙏 Morning Declarations & Prayer",
        body: "Take 5 minutes for morning prayer declarations and communion with God.",
        hour: 8,
        minute: 30,
      );
    }
  }
}
