// lib/screens/reading_plan_day_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/reading_plan_models.dart';
import '../services/reading_plan_service.dart';
import '../services/bible_service.dart';
import '../theme/imago_theme.dart';
import '../widgets/reading_progress_ring.dart';

class ReadingPlanDayScreen extends StatefulWidget {
  final ReadingPlan plan;
  final ReadingPlanDay day;
  final bool initialIsCompleted;
  final VoidCallback onProgressUpdated;

  const ReadingPlanDayScreen({
    super.key,
    required this.plan,
    required this.day,
    required this.initialIsCompleted,
    required this.onProgressUpdated,
  });

  @override
  State<ReadingPlanDayScreen> createState() => _ReadingPlanDayScreenState();
}

class _ReadingPlanDayScreenState extends State<ReadingPlanDayScreen> {
  late bool _isCompleted;
  bool _saving = false;
  final _reflectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.initialIsCompleted;
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    super.dispose();
  }

  Future<void> _toggleComplete() async {
    setState(() => _saving = true);
    final updated = await ReadingPlanService.instance.toggleDayCompleted(
      widget.plan.id,
      widget.day.dayNumber,
    );
    setState(() {
      _isCompleted = updated.completedDays.contains(widget.day.dayNumber);
      _saving = false;
    });
    widget.onProgressUpdated();

    if (_isCompleted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Text('Day ${widget.day.dayNumber} marked complete! Praise God!'),
            ],
          ),
          backgroundColor: const Color(0xFF3D5AFE),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _openScripturePreview(String reference) async {
    final verses = await BibleService.instance.getVerseByReference(reference);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E0B24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  reference,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white54),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (verses.isEmpty)
              Text(
                'Scripture passage: $reference',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: verses
                        .map((v) => Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                '${v.verse}. ${v.text}',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                  height: 1.6,
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
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
            right: -40,
            child: CosmicOrb(size: 260, color: const Color(0xFF3D5AFE), opacity: 0.07),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag & Day badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3D5AFE).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF3D5AFE).withOpacity(0.4)),
                              ),
                              child: Text(
                                'DAY ${widget.day.dayNumber} OF ${widget.plan.durationDays}',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          widget.day.title,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            color: ImagoColors.cream,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Scriptures
                        Text(
                          'TODAY’S READINGS',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: ImagoColors.gold.withOpacity(0.8),
                            fontSize: 11,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.day.scriptureReferences.map((ref) {
                            return GestureDetector(
                              onTap: () => _openScripturePreview(ref),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: ImagoColors.gold.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.menu_book_rounded, color: ImagoColors.gold, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      ref,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),

                        const SizedBox(height: 24),

                        // Devotional Content Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.format_quote_rounded, color: ImagoColors.gold, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Devotional Reflection',
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      color: ImagoColors.cream,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.day.devotionalText,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 14,
                                  height: 1.7,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Reflection Question
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: ImagoColors.gold.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: ImagoColors.gold.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.psychology_rounded, color: ImagoColors.gold, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Daily Reflection Prompt',
                                    style: TextStyle(
                                      fontFamily: 'Cinzel',
                                      color: ImagoColors.gold,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.day.reflectionQuestion,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 13.5,
                                  height: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Complete Action Button
                        GestureDetector(
                          onTap: _saving ? null : _toggleComplete,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              gradient: _isCompleted
                                  ? const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)])
                                  : ImagoColors.violetGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: (_isCompleted ? Colors.green : ImagoColors.violet).withOpacity(0.4),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Center(
                              child: _saving
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isCompleted
                                              ? Icons.check_circle_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isCompleted ? 'Marked Complete ✓' : 'Mark Day Complete',
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
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
                  widget.plan.title,
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    color: ImagoColors.cream,
                    fontSize: 17,
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
