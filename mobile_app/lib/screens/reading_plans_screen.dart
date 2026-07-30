// lib/screens/reading_plans_screen.dart

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
  String _selectedCategory = 'All'; // 'All', '30-Day', '90-Day', '1-Year'
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
    return Scaffold(
      backgroundColor: const Color(0xFF040510),
      body: Stack(
        children: [
          const CosmicBackground(children: []),
          Positioned(
            top: -40,
            left: -40,
            child: CosmicOrb(size: 260, color: const Color(0xFF3D5AFE), opacity: 0.07),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildCategoryFilter(),
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: ImagoColors.gold))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActivePlanHeader(),
                              const SizedBox(height: 24),
                              Text(
                                'EXPLORE BIBLE TRACKS',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: ImagoColors.gold.withOpacity(0.8),
                                  fontSize: 11,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
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
                                  return _buildPlanCard(plan, prog);
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reading Plans & Devotionals',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', '30-Day', '90-Day', '1-Year'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedCategory = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    gradient: isSelected ? ImagoColors.violetGradient : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cat,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
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

  Widget _buildActivePlanHeader() {
    // Find the most recently read plan
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
          gradient: LinearGradient(
            colors: [
              const Color(0xFF3D5AFE).withOpacity(0.2),
              const Color(0xFF1B1147).withOpacity(0.4),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ImagoColors.gold.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3D5AFE).withOpacity(0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Row(
          children: [
            ReadingProgressRing(
              progress: pct,
              size: 80,
              strokeWidth: 7,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ImagoColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ACTIVE TRACK',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: ImagoColors.gold,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      color: ImagoColors.cream,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${prog.completedDays.length} of ${plan.durationDays} days completed',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_fill_rounded, color: ImagoColors.gold, size: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanCard(ReadingPlan plan, ReadingPlanProgress? prog) {
    final completedCount = prog?.completedDays.length ?? 0;
    final pct = prog != null ? prog.getPercentageForDuration(plan.durationDays) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ReadingPlanDetailScreen(plan: plan)),
              ).then((_) => _loadAllProgress());
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  ReadingProgressRing(
                    progress: pct,
                    size: 64,
                    strokeWidth: 6,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3D5AFE).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${plan.durationDays} DAYS',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Color(0xFF8C9EFF),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          plan.title,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: ImagoColors.cream,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          plan.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withOpacity(0.3),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
