// lib/screens/reading_plans_screen.dart
// Reading plans catalog screen with responsive category tabs and light/dark theme support.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/reading_plan_models.dart';
import '../data/reading_plans_data.dart';
import '../services/reading_plan_service.dart';
import '../theme/imago_theme.dart';
import '../widgets/reading_progress_ring.dart';
import 'reading_plan_detail_screen.dart';

class ReadingPlansScreen extends StatefulWidget {
  const ReadingPlansScreen({super.key});

  @override
  State<ReadingPlansScreen> createState() => _ReadingPlansScreenState();
}

class _ReadingPlansScreenState extends State<ReadingPlansScreen> {
  String _selectedCategory = 'All'; // 'All', '9-Day', '30-Day', '90-Day', '1-Year'
  Map<String, ReadingPlanProgress> _progressMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllProgress();
  }

  Future<void> _loadAllProgress() async {
    setState(() => _loading = true);
    final map = await ReadingPlanService.instance.getAllProgress();
    setState(() {
      _progressMap = map;
      _loading = false;
    });
  }

  List<ReadingPlan> get _filteredPlans {
    if (_selectedCategory == 'All') return kReadingPlans;
    return kReadingPlans.where((p) => p.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
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
                _buildCategoryFilter(isDark, borderColor, textPrimary, textSecondary),
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
                                  _buildActivePlanHeader(isDark, cardBg, borderColor, textPrimary, textSecondary),
                                  const SizedBox(height: 24),
                                  Text(
                                    'EXPLORE BIBLE TRACKS',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: const Color(0xFF4F46E5),
                                      fontSize: 11.5,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _filteredPlans.length,
                                    itemBuilder: (context, index) {
                                      final plan = _filteredPlans[index];
                                      final prog = _progressMap[plan.id];
                                      return _buildPlanCard(plan, prog, isDark, cardBg, borderColor, textPrimary, textSecondary);
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
    final canPop = Navigator.canPop(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          if (canPop) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
              color: textSecondary,
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              'Reading Plans & Devotionals',
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

  Widget _buildCategoryFilter(bool isDark, Color borderColor, Color textPrimary, Color textSecondary) {
    final categories = ['All', '9-Day', '30-Day', '90-Day', '1-Year'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cat,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isSelected ? Colors.white : textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActivePlanHeader(bool isDark, Color cardBg, Color borderColor, Color textPrimary, Color textSecondary) {
    if (_progressMap.isEmpty) return const SizedBox.shrink();

    final activeEntries = _progressMap.entries.toList()
      ..sort((a, b) => b.value.lastReadAt.compareTo(a.value.lastReadAt));

    final activeEntry = activeEntries.first;
    final plan = kReadingPlans.firstWhere(
      (p) => p.id == activeEntry.key,
      orElse: () => kReadingPlans.first,
    );
    final prog = activeEntry.value;
    final pct = prog.getPercentageForDuration(plan.durationDays);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReadingPlanDetailScreen(plan: plan)),
        ).then((_) => _loadAllProgress());
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.35)),
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
              progress: pct,
              size: 72,
              strokeWidth: 6,
            ),
            const SizedBox(width: 16),
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
                    child: const Text(
                      'ACTIVE TRACK',
                      style: TextStyle(
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
                    plan.title,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prog.completedDays.length} of ${plan.durationDays} days completed',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF4F46E5)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(
    ReadingPlan plan,
    ReadingPlanProgress? prog,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textPrimary,
    Color textSecondary,
  ) {
    final completedCount = prog?.completedDays.length ?? 0;
    final totalDays = plan.durationDays;
    final pct = (completedCount / totalDays).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ReadingPlanDetailScreen(plan: plan)),
            ).then((_) => _loadAllProgress());
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_stories_rounded, color: Color(0xFF4F46E5), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              plan.category,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•  ${plan.durationDays} Days',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        plan.title,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.subtitle,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: textSecondary,
                        ),
                      ),
                      if (completedCount > 0) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: borderColor,
                            valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$completedCount / $totalDays days completed',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: const Color(0xFF4F46E5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
