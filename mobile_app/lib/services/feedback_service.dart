// lib/services/feedback_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_model.dart';
import 'auth_service.dart';

class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  static const String _kPendingFeedback = 'pending_user_feedback_queue';
  static const String _kFeedbackHistory = 'user_feedback_history';
  static const String _kMicroFeedbackHistory = 'user_micro_feedback_history';

  final List<String> _backendUrls = [
    'https://imago-1-wkzl.onrender.com',
    'https://imago-nthk.onrender.com',
  ];

  String get _platformName {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return 'unknown';
  }

  /// Submits full user feedback (rating, category, message, etc.)
  Future<bool> submitFeedback({
    required FeedbackCategory category,
    required int rating,
    required String message,
    String? email,
    String? userName,
    String screenContext = 'general',
    Map<String, dynamic>? metadata,
  }) async {
    final String currentEmail = email ?? AuthService.instance.currentEmail;
    final String currentName = userName ?? AuthService.instance.currentDisplayName;

    final feedback = UserFeedback(
      id: 'fb_${DateTime.now().millisecondsSinceEpoch}_${(1000 + (DateTime.now().microsecond % 9000))}',
      category: category,
      rating: rating.clamp(1, 5),
      message: message.trim(),
      email: currentEmail.isNotEmpty ? currentEmail : null,
      userName: currentName.isNotEmpty ? currentName : null,
      screenContext: screenContext,
      platform: _platformName,
      appVersion: '1.0.0+1',
      timestamp: DateTime.now(),
      isSynced: false,
      metadata: metadata,
    );

    // Save locally first for offline safety
    await _saveToHistory(feedback);
    await _queueForSync(feedback);

    // Attempt instant push to backend
    final bool pushed = await _pushFeedbackToBackend(feedback);
    if (pushed) {
      await _markFeedbackSynced(feedback.id);
    }

    return true;
  }

  /// Submits quick one-tap micro validation (thumbs up / down on AI or study items)
  Future<bool> submitMicroFeedback({
    required String contextId,
    required bool isPositive,
    String screenContext = 'chat',
    String? note,
  }) async {
    final micro = MicroFeedback(
      id: 'mfb_${DateTime.now().millisecondsSinceEpoch}',
      contextId: contextId,
      isPositive: isPositive,
      screenContext: screenContext,
      note: note,
      timestamp: DateTime.now(),
    );

    // Save micro feedback locally
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString(_kMicroFeedbackHistory) ?? '[]';
      final List<dynamic> list = jsonDecode(historyStr);
      list.add(micro.toMap());
      if (list.length > 100) list.removeAt(0); // keep max 100
      await prefs.setString(_kMicroFeedbackHistory, jsonEncode(list));
    } catch (_) {}

    // Send to backend
    for (final base in _backendUrls) {
      try {
        final url = Uri.parse('$base/api/feedback/micro');
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(micro.toMap()),
        ).timeout(const Duration(seconds: 6));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          return true;
        }
      } catch (_) {}
    }

    return false;
  }

  /// Attempts to transmit feedback to the cloud backend
  Future<bool> _pushFeedbackToBackend(UserFeedback feedback) async {
    // 1. Send to LCMWorld Central Cloud Engine
    try {
      final categoryStr = feedback.category.name.toLowerCase();
      String lcmType = 'feedback';
      if (categoryStr.contains('bug')) {
        lcmType = 'bug';
      } else if (categoryStr.contains('feature')) {
        lcmType = 'feature_request';
      } else if (categoryStr.contains('price') || categoryStr.contains('commercial')) {
        lcmType = 'commercial';
      }

      final lcmPayload = jsonEncode({
        'package_name': 'org.lifechangerstouch.imago',
        'app_name': 'yo-ETS',
        'app_version': feedback.appVersion.isNotEmpty ? feedback.appVersion : '1.0.0',
        'type': lcmType,
        'message': feedback.message,
        'rating': feedback.rating,
        'device_model': feedback.platform,
        'os_version': feedback.platform,
        'tester_email': feedback.email ?? '',
        'would_pay': 'yes',
      });

      await http.post(
        Uri.parse('https://lcmworld.lifechangerstouch.org/api/feedback'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: lcmPayload,
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('[FeedbackService] LCMWorld push note: $e');
    }

    final payload = jsonEncode(feedback.toMap());

    for (final base in _backendUrls) {
      try {
        final url = Uri.parse('$base/api/feedback');
        final res = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 8));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          return true;
        }
      } catch (e) {
        debugPrint('[FeedbackService] Error posting feedback to $base: $e');
      }
    }
    return false;
  }

  /// Saves feedback to user's local history
  Future<void> _saveToHistory(UserFeedback feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFeedbackHistory) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      list.add(feedback.toMap());
      await prefs.setString(_kFeedbackHistory, jsonEncode(list));
    } catch (_) {}
  }

  /// Queues feedback for future retry if offline
  Future<void> _queueForSync(UserFeedback feedback) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingFeedback) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      list.add(feedback.toMap());
      await prefs.setString(_kPendingFeedback, jsonEncode(list));
    } catch (_) {}
  }

  /// Marks an item as synced and removes from pending queue
  Future<void> _markFeedbackSynced(String feedbackId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingFeedback) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      list.removeWhere((item) => item['id'] == feedbackId);
      await prefs.setString(_kPendingFeedback, jsonEncode(list));

      // Update history flag
      final histRaw = prefs.getString(_kFeedbackHistory) ?? '[]';
      final List<dynamic> histList = jsonDecode(histRaw);
      for (final item in histList) {
        if (item['id'] == feedbackId) {
          item['is_synced'] = true;
        }
      }
      await prefs.setString(_kFeedbackHistory, jsonEncode(histList));
    } catch (_) {}
  }

  /// Flushes any pending offline feedback when app comes online
  Future<void> syncPendingFeedback() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPendingFeedback) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      if (list.isEmpty) return;

      final remaining = <Map<String, dynamic>>[];
      for (final item in list) {
        final fb = UserFeedback.fromMap(Map<String, dynamic>.from(item));
        final success = await _pushFeedbackToBackend(fb);
        if (!success) {
          remaining.add(item);
        }
      }
      await prefs.setString(_kPendingFeedback, jsonEncode(remaining));
    } catch (_) {}
  }

  /// Retrieves count of submitted feedback items
  Future<int> getFeedbackCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kFeedbackHistory) ?? '[]';
      final List<dynamic> list = jsonDecode(raw);
      return list.length;
    } catch (_) {
      return 0;
    }
  }
}
