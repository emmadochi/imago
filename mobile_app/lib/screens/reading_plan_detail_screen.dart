// lib/screens/reading_plan_detail_screen.dart
// Reading plan detail view with dynamic light/dark theming and daily schedule.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/reading_plan_models.dart';
import '../services/reading_plan_service.dart';
import '../theme/imago_theme.dart';
import '../widgets/reading_progress_ring.dart';
import 'reading_plan_day_screen.dart';

class ReadingPlanDetailScreen extends StatefulWidget {
  final ReadingPlan plan;

  const ReadingPlanDetailScreen({super.key, required this.plan});

  @override
  State<ReadingPlanDetailScreen> createState() => _ReadingPlanDetailScreenState();
}

class _ReadingPlanDetailScreenState extends State<ReadingPlanDetailScreen> {
  ReadingPlanProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final prog = await ReadingPlanService.instance.getProgress(widget.plan.id);
    setState(() {
      _progress = prog;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = _progress?.completedDays.length ?? 0;
    final totalDays = widget.plan.durationDays;
    final progressPct = (completedCount / totalDays).clamp(0.0, 1.0);

    return ListenableBuilder(
      listenable: Listenable.merge([appThemeNotifier, readerThemeNotifier]),
      builder: (context, _) {
        final isDark = ImagoColors.isDark;
        final bg = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8FAFC);
        final cardBg = isDark ? const Color(0xFF131D33) : Colors.white;
        final borderColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
        final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
        final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

        return Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark, borderColor, textPrimary, textSecondary),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Hero progress overview card
                                  _buildHeroCard(completedCount, totalDays, progressPct, isDark, cardBg, borderColor, textPrimary, textSecondary),

                                  const SizedBox(height: 24),

                                  // Description
                                  Text(
                                    'ABOUT THIS TRACK',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: const Color(0xFF4F46E5),
                                      fontSize: 11.5,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Text(
                                      widget.plan.description,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: textPrimary,
                                        fontSize: 13.5,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Days grid list
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'DAILY SCHEDULE',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: const Color(0xFF4F46E5),
                                          fontSize: 11.5,
                                          letterSpacing: 1.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        '$completedCount / $totalDays Days',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          color: textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: widget.plan.days.length,
                                    itemBuilder: (context, index) {
                                      final day = widget.plan.days[index];
                                      final isCompleted =
                                          _progress?.completedDays.contains(day.dayNumber) ?? false;
                                      return _buildDayTile(day, isCompleted, isDark, cardBg, borderColor, textPrimary, textSecondary);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark, Color borderColor, Color textPrimary, Color textSecondary) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
            color: textSecondary,
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.plan.title,
              style: TextStyle(
                fontFamily: 'Cinzel',
                color: isDark ? const Color(0xFFFFC857) : const Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(
    int completedCount,
    int totalDays,
    double progressPct,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ReadingProgressRing(
            progress: progressPct,
            size: 80,
            strokeWidth: 7,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${widget.plan.category.toUpperCase()} TRACK',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF4F46E5),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.plan.title,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.plan.subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayTile(
    ReadingPlanDay day,
    bool isCompleted,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted ? const Color(0xFF10B981).withOpacity(0.5) : borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReadingPlanDayScreen(
                  plan: widget.plan,
                  day: day,
                  initialIsCompleted: isCompleted,
                  onProgressUpdated: _loadProgress,
                ),
              ),
            ).then((_) => _loadProgress());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : const Color(0xFF4F46E5).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 20)
                      : Text(
                          '${day.dayNumber}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Color(0xFF4F46E5),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day.title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.scriptureReferences.join('  •  '),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: const Color(0xFF4F46E5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF4F46E5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
