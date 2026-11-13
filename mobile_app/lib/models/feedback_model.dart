// lib/models/feedback_model.dart
import 'dart:convert';

enum FeedbackCategory {
  feature,
  bug,
  scripture,
  testimony,
  general,
}

extension FeedbackCategoryExtension on FeedbackCategory {
  String get label {
    switch (this) {
      case FeedbackCategory.feature:
        return 'Feature Idea';
      case FeedbackCategory.bug:
        return 'Bug or Issue';
      case FeedbackCategory.scripture:
        return 'Scripture / Study';
      case FeedbackCategory.testimony:
        return 'Spiritual Testimony';
      case FeedbackCategory.general:
      default:
        return 'General Feedback';
    }
  }

  String get iconEmoji {
    switch (this) {
      case FeedbackCategory.feature:
        return '💡';
      case FeedbackCategory.bug:
        return '🐛';
      case FeedbackCategory.scripture:
        return '📖';
      case FeedbackCategory.testimony:
        return '🕊️';
      case FeedbackCategory.general:
      default:
        return '💬';
    }
  }

  String get defaultPrompt {
    switch (this) {
      case FeedbackCategory.feature:
        return 'What feature or tool would bless your study or ministry?';
      case FeedbackCategory.bug:
        return 'Describe what happened, where you encountered it, and what was expected...';
      case FeedbackCategory.scripture:
        return 'Found a typo, rendering issue, or commentary error? Let us know the reference...';
      case FeedbackCategory.testimony:
        return 'How has yo-ETS / Imago encouraged your walk with God?';
      case FeedbackCategory.general:
      default:
        return 'Tell us how your experience has been so far...';
    }
  }
}

class UserFeedback {
  final String id;
  final FeedbackCategory category;
  final int rating; // 1 to 5 stars
  final String message;
  final String? email;
  final String? userName;
  final String screenContext;
  final String platform;
  final String appVersion;
  final DateTime timestamp;
  final bool isSynced;
  final Map<String, dynamic>? metadata;

  UserFeedback({
    required this.id,
    required this.category,
    required this.rating,
    required this.message,
    this.email,
    this.userName,
    this.screenContext = 'general',
    required this.platform,
    this.appVersion = '1.0.0',
    required this.timestamp,
    this.isSynced = false,
    this.metadata,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'category_label': category.label,
      'rating': rating,
      'message': message,
      'email': email,
      'user_name': userName,
      'screen_context': screenContext,
      'platform': platform,
      'app_version': appVersion,
      'timestamp': timestamp.toIso8601String(),
      'is_synced': isSynced,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory UserFeedback.fromMap(Map<String, dynamic> map) {
    FeedbackCategory cat = FeedbackCategory.general;
    try {
      cat = FeedbackCategory.values.byName(map['category'] as String? ?? 'general');
    } catch (_) {
      cat = FeedbackCategory.general;
    }

    return UserFeedback(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      category: cat,
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      message: map['message'] as String? ?? '',
      email: map['email'] as String?,
      userName: map['user_name'] as String?,
      screenContext: map['screen_context'] as String? ?? 'general',
      platform: map['platform'] as String? ?? 'unknown',
      appVersion: map['app_version'] as String? ?? '1.0.0',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isSynced: map['is_synced'] as bool? ?? false,
      metadata: map['metadata'] != null ? Map<String, dynamic>.from(map['metadata'] as Map) : null,
    );
  }

  UserFeedback copyWith({bool? isSynced}) {
    return UserFeedback(
      id: id,
      category: category,
      rating: rating,
      message: message,
      email: email,
      userName: userName,
      screenContext: screenContext,
      platform: platform,
      appVersion: appVersion,
      timestamp: timestamp,
      isSynced: isSynced ?? this.isSynced,
      metadata: metadata,
    );
  }
}

class MicroFeedback {
  final String id;
  final String contextId; // e.g. message_id or verse_ref
  final bool isPositive;
  final String screenContext;
  final String? note;
  final DateTime timestamp;

  MicroFeedback({
    required this.id,
    required this.contextId,
    required this.isPositive,
    required this.screenContext,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'context_id': contextId,
      'is_positive': isPositive,
      'screen_context': screenContext,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
