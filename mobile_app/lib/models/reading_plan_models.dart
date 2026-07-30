// lib/models/reading_plan_models.dart

class ReadingPlanDay {
  final int dayNumber;
  final String title;
  final List<String> scriptureReferences; // e.g., ['Jeremiah 29:11-14', 'Philippians 4:6-7']
  final String devotionalText;
  final String reflectionQuestion;

  ReadingPlanDay({
    required this.dayNumber,
    required this.title,
    required this.scriptureReferences,
    required this.devotionalText,
    required this.reflectionQuestion,
  });

  factory ReadingPlanDay.fromMap(Map<String, dynamic> map) {
    return ReadingPlanDay(
      dayNumber: map['dayNumber'] as int,
      title: map['title'] as String,
      scriptureReferences: List<String>.from(map['scriptureReferences'] as List),
      devotionalText: map['devotionalText'] as String,
      reflectionQuestion: map['reflectionQuestion'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dayNumber': dayNumber,
      'title': title,
      'scriptureReferences': scriptureReferences,
      'devotionalText': devotionalText,
      'reflectionQuestion': reflectionQuestion,
    };
  }
}

class ReadingPlan {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final int durationDays; // 30, 90, 365
  final String category; // 'Foundation', 'Wisdom', 'New Testament', 'Peace'
  final String iconName;
  final List<ReadingPlanDay> days;

  ReadingPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.durationDays,
    required this.category,
    required this.iconName,
    required this.days,
  });
}

class ReadingPlanProgress {
  final String planId;
  final int startedAt;
  final Set<int> completedDays; // Set of day numbers e.g. {1, 2, 3}
  final int lastReadAt;

  ReadingPlanProgress({
    required this.planId,
    required this.startedAt,
    required this.completedDays,
    required this.lastReadAt,
  });

  double get progressPercentage =>
      completedDays.isEmpty ? 0.0 : (completedDays.length / 365.0).clamp(0.0, 1.0);

  double getPercentageForDuration(int totalDays) {
    if (totalDays <= 0) return 0.0;
    return (completedDays.length / totalDays).clamp(0.0, 1.0);
  }

  factory ReadingPlanProgress.fromMap(Map<String, dynamic> map) {
    final completedString = map['completed_days'] as String? ?? '';
    final completedSet = completedString.isEmpty
        ? <int>{}
        : completedString.split(',').map((e) => int.parse(e.trim())).toSet();

    return ReadingPlanProgress(
      planId: map['plan_id'] as String,
      startedAt: map['started_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      completedDays: completedSet,
      lastReadAt: map['last_read_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'plan_id': planId,
      'started_at': startedAt,
      'completed_days': completedDays.join(','),
      'last_read_at': lastReadAt,
    };
  }
}
