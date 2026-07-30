// lib/services/reading_plan_service.dart

import 'package:sqflite/sqflite.dart';
import '../models/reading_plan_models.dart';
import '../data/reading_plans_data.dart';
import 'user_data_service.dart';

class ReadingPlanService {
  ReadingPlanService._();
  static final ReadingPlanService instance = ReadingPlanService._();

  Future<ReadingPlanProgress?> getProgress(String planId) async {
    final db = await _getDb();
    final maps = await db.query(
      'reading_plan_progress',
      where: 'plan_id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return ReadingPlanProgress.fromMap(maps.first);
    }
    return null;
  }

  Future<Map<String, ReadingPlanProgress>> getAllProgress() async {
    final db = await _getDb();
    final maps = await db.query('reading_plan_progress');
    final Map<String, ReadingPlanProgress> result = {};
    for (var m in maps) {
      final prog = ReadingPlanProgress.fromMap(m);
      result[prog.planId] = prog;
    }
    return result;
  }

  Future<ReadingPlanProgress> toggleDayCompleted(String planId, int dayNumber) async {
    final db = await _getDb();
    var current = await getProgress(planId);

    final now = DateTime.now().millisecondsSinceEpoch;
    Set<int> days = current != null ? Set<int>.from(current.completedDays) : {};

    if (days.contains(dayNumber)) {
      days.remove(dayNumber);
    } else {
      days.add(dayNumber);
    }

    final newProgress = ReadingPlanProgress(
      planId: planId,
      startedAt: current?.startedAt ?? now,
      completedDays: days,
      lastReadAt: now,
    );

    await db.insert(
      'reading_plan_progress',
      newProgress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return newProgress;
  }

  Future<void> resetPlan(String planId) async {
    final db = await _getDb();
    await db.delete(
      'reading_plan_progress',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
  }

  ReadingPlan? getPlanById(String id) {
    try {
      return kReadingPlans.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Database> _getDb() async {
    await UserDataService.instance.init();
    // Return database instance from UserDataService
    return UserDataService.instance.database;
  }
}
