// lib/screens/reading_plan_detail_screen.dart

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
                Expanded(
                  child: _loading
                      ? Center(child: CircularProgressIndicator(color: ImagoColors.gold))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero progress overview card
                              _buildHeroCard(completedCount, totalDays, progressPct),

                              const SizedBox(height: 24),

                              // Description
                              Text(
                                'ABOUT THIS TRACK',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: ImagoColors.gold.withOpacity(0.8),
                                  fontSize: 11,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.plan.description,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 13.5,
                                  height: 1.6,
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
                                      color: ImagoColors.gold.withOpacity(0.8),
                                      fontSize: 11,
                                      letterSpacing: 2.0,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$completedCount / $totalDays Days',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white.withOpacity(0.5),
                                      fontSize: 12,
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
                                  return _buildDayTile(day, isCompleted);
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

  Widget _buildHeroCard(int completedCount, int totalDays, double progressPct) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D5AFE).withOpacity(0.12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          // Visual completion ring
          ReadingProgressRing(
            progress: progressPct,
            size: 90,
            strokeWidth: 8,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.subtitle,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: ImagoColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.plan.title,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.cream,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$completedCount of $totalDays days completed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white.withOpacity(0.7),
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

  Widget _buildDayTile(ReadingPlanDay day, bool isCompleted) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withOpacity(0.02) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.white.withOpacity(0.07),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: isCompleted ? Colors.green : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check_rounded, color: Colors.green, size: 20)
                : Text(
                    '${day.dayNumber}',
                    style: const TextStyle(
                      fontFamily: 'Cinzel',
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        title: Text(
          day.title,
          style: TextStyle(
            fontFamily: 'Poppins',
            color: isCompleted ? Colors.white70 : Colors.white,
            fontSize: 14,
            fontWeight: isCompleted ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        subtitle: Text(
          day.scriptureReferences.join(' • '),
          style: TextStyle(
            fontFamily: 'Poppins',
            color: ImagoColors.gold.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.4),
          size: 20,
        ),
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
                  widget.plan.title,
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
}
