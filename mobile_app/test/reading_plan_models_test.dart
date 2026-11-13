import 'package:flutter_test/flutter_test.dart';
import 'package:imago/models/reading_plan_models.dart';

void main() {
  group('ReadingPlanModels Automated Tests', () {
    test('ReadingPlanDay serialization', () {
      final day = ReadingPlanDay(
        dayNumber: 1,
        title: 'In The Beginning',
        scriptureReferences: ['Genesis 1:1-31', 'John 1:1-5'],
        devotionalText: 'God created the heavens and the earth.',
        reflectionQuestion: 'How does creation reflect God\'s glory?',
      );

      final map = day.toMap();
      expect(map['dayNumber'], equals(1));
      expect(map['title'], equals('In The Beginning'));
      expect(map['scriptureReferences'], equals(['Genesis 1:1-31', 'John 1:1-5']));

      final restored = ReadingPlanDay.fromMap(map);
      expect(restored.dayNumber, equals(1));
      expect(restored.title, equals('In The Beginning'));
      expect(restored.scriptureReferences.length, equals(2));
    });

    test('ReadingPlanProgress calculates percentage accurately', () {
      final progress = ReadingPlanProgress(
        planId: 'plan_30_days',
        startedAt: DateTime.now().millisecondsSinceEpoch,
        completedDays: {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
        lastReadAt: DateTime.now().millisecondsSinceEpoch,
      );

      expect(progress.completedDays.length, equals(15));
      expect(progress.getPercentageForDuration(30), closeTo(0.5, 0.001));
      expect(progress.getPercentageForDuration(60), closeTo(0.25, 0.001));
    });

    test('ReadingPlanProgress serialization handles comma-separated strings', () {
      final progress = ReadingPlanProgress(
        planId: 'psalms_wisdom',
        startedAt: 100000,
        completedDays: {1, 3, 5, 7},
        lastReadAt: 200000,
      );

      final map = progress.toMap();
      expect(map['plan_id'], equals('psalms_wisdom'));
      expect(map['completed_days'], equals('1,3,5,7'));

      final restored = ReadingPlanProgress.fromMap(map);
      expect(restored.planId, equals('psalms_wisdom'));
      expect(restored.completedDays, equals({1, 3, 5, 7}));
    });
  });
}
