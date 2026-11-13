// test/feedback_protocol_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/feedback_model.dart';

void main() {
  group('UserFeedback Model Tests', () {
    test('UserFeedback serializes and deserializes correctly', () {
      final now = DateTime.now();
      final feedback = UserFeedback(
        id: 'fb_123456789',
        category: FeedbackCategory.feature,
        rating: 5,
        message: 'Would love an audio loop feature for night prayer.',
        email: 'tester@imago.church',
        userName: 'Sister Grace',
        screenContext: 'desktop_workstation',
        platform: 'windows',
        appVersion: '1.0.0+1',
        timestamp: now,
        isSynced: false,
        metadata: {'selected_tab': 'prayer'},
      );

      final map = feedback.toMap();
      expect(map['id'], 'fb_123456789');
      expect(map['category'], 'feature');
      expect(map['category_label'], 'Feature Idea');
      expect(map['rating'], 5);
      expect(map['message'], 'Would love an audio loop feature for night prayer.');
      expect(map['email'], 'tester@imago.church');
      expect(map['user_name'], 'Sister Grace');
      expect(map['screen_context'], 'desktop_workstation');
      expect(map['platform'], 'windows');
      expect(map['is_synced'], false);
      expect(map['metadata']['selected_tab'], 'prayer');

      final fromMap = UserFeedback.fromMap(map);
      expect(fromMap.id, feedback.id);
      expect(fromMap.category, FeedbackCategory.feature);
      expect(fromMap.rating, 5);
      expect(fromMap.message, feedback.message);
      expect(fromMap.email, feedback.email);
      expect(fromMap.userName, feedback.userName);
      expect(fromMap.screenContext, feedback.screenContext);
      expect(fromMap.platform, feedback.platform);
    });

    test('FeedbackCategory labels and emoji helpers', () {
      expect(FeedbackCategory.feature.label, 'Feature Idea');
      expect(FeedbackCategory.feature.iconEmoji, '💡');

      expect(FeedbackCategory.bug.label, 'Bug or Issue');
      expect(FeedbackCategory.bug.iconEmoji, '🐛');

      expect(FeedbackCategory.scripture.label, 'Scripture / Study');
      expect(FeedbackCategory.scripture.iconEmoji, '📖');

      expect(FeedbackCategory.testimony.label, 'Spiritual Testimony');
      expect(FeedbackCategory.testimony.iconEmoji, '🕊️');

      expect(FeedbackCategory.general.label, 'General Feedback');
      expect(FeedbackCategory.general.iconEmoji, '💬');
    });

    test('MicroFeedback serializes correctly', () {
      final now = DateTime.now();
      final micro = MicroFeedback(
        id: 'mfb_999',
        contextId: 'msg_42',
        isPositive: true,
        screenContext: 'chat_counseling',
        note: 'Spiritually uplifting',
        timestamp: now,
      );

      final map = micro.toMap();
      expect(map['id'], 'mfb_999');
      expect(map['context_id'], 'msg_42');
      expect(map['is_positive'], true);
      expect(map['screen_context'], 'chat_counseling');
      expect(map['note'], 'Spiritually uplifting');
    });

    test('UserFeedback copyWith toggles isSynced', () {
      final feedback = UserFeedback(
        id: 'fb_1',
        category: FeedbackCategory.general,
        rating: 4,
        message: 'Great app',
        platform: 'android',
        timestamp: DateTime.now(),
        isSynced: false,
      );

      final synced = feedback.copyWith(isSynced: true);
      expect(synced.isSynced, true);
      expect(synced.id, feedback.id);
      expect(synced.rating, 4);
    });
  });
}
