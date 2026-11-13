    // lib/screens/reading_plan_day_screen.dart
// Reading plan daily view with direct inline scripture reading,
// pastoral reflection, prayer action step, and full light/dark theme adaptability.

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/reading_plan_models.dart';
import '../models/bible_models.dart';
import '../services/reading_plan_service.dart';
import '../services/bible_service.dart';
import '../services/tts_service.dart';
import '../theme/imago_theme.dart';
import 'bible_screen.dart';

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
  bool _loadingScriptures = true;
  final Map<String, List<BibleVerse>> _scriptureVerses = {};
  final _reflectionController = TextEditingController();
  String? _activeSegmentKey;
  List<String> _segmentKeys = [];

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.initialIsCompleted;
    _loadScriptures();
  }

  Future<void> _loadScriptures() async {
    setState(() => _loadingScriptures = true);
    for (final ref in widget.day.scriptureReferences) {
      try {
        final verses = await BibleService.instance.getVerseByReference(ref);
        _scriptureVerses[ref] = verses;
      } catch (e) {
        _scriptureVerses[ref] = [];
      }
    }
    if (mounted) {
      setState(() => _loadingScriptures = false);
    }
  }

  @override
  void dispose() {
    _reflectionController.dispose();
    TtsService.instance.stop();
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

  Future<void> _listenToDay() async {
    if (_loadingScriptures) {
      await _loadScriptures();
    }
    if (!mounted) return;

    final segments = <String>[];
    final keys = <String>[];

    segments.add('${widget.day.title}.');
    keys.add('title');

    for (final ref in widget.day.scriptureReferences) {
      final verses = _scriptureVerses[ref] ?? [];
      segments.add('$ref.');
      keys.add('ref:$ref');

      for (final v in verses) {
        segments.add('Verse ${v.verse}. ${v.text}');
        keys.add('verse:$ref:${v.verse}');
      }
    }

    segments.add('Devotional Reflection. ${widget.day.devotionalText}');
    keys.add('devotional');

    if (widget.day.reflectionQuestion.trim().isNotEmpty) {
      segments.add('Reflection Question. ${widget.day.reflectionQuestion}');
      keys.add('question');
    }

    setState(() {
      _segmentKeys = keys;
      _activeSegmentKey = keys.isNotEmpty ? keys.first : null;
    });

    await TtsService.instance.speakChunks(
      segments,
      withAmbient: true,
      onChunkStart: (idx) {
        if (!mounted) return;
        setState(() {
          if (idx >= 0 && idx < _segmentKeys.length) {
            _activeSegmentKey = _segmentKeys[idx];
          } else {
            _activeSegmentKey = null;
          }
        });
      },
    );
  }

  Future<void> _stopListening() async {
    await TtsService.instance.stop();
    if (mounted) {
      setState(() => _activeSegmentKey = null);
    }
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
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 80),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Day badge & completion status
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF4F46E5).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    'DAY ${widget.day.dayNumber} OF ${widget.plan.durationDays}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFF4F46E5),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                if (_isCompleted)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                                        SizedBox(width: 4),
                                        Text(
                                          'Completed',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Day Title
                            Text(
                              widget.day.title,
                              style: TextStyle(
                                fontFamily: 'Cinzel',
                                color: isDark ? const Color(0xFFFFC857) : const Color(0xFF1E293B),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Audio Listen / Pause / Continue / Stop Controls
                            ValueListenableBuilder<bool>(
                              valueListenable: TtsService.instance.isPlayingNotifier,
                              builder: (context, isPlaying, _) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: TtsService.instance.isPausedNotifier,
                                  builder: (context, isPaused, _) {
                                    final isActive = isPlaying || isPaused;

                                    if (isActive) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: const Color(0xFF4F46E5).withOpacity(0.35),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              isPlaying ? Icons.graphic_eq_rounded : Icons.pause_circle_outline_rounded,
                                              color: const Color(0xFF4F46E5),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                isPlaying
                                                    ? 'Reading Scripture & Devotional...'
                                                    : 'Paused — tap Continue to resume',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {
                                                if (isPlaying) {
                                                  TtsService.instance.pause();
                                                } else {
                                                  TtsService.instance.resume();
                                                }
                                              },
                                              icon: Icon(
                                                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                                size: 18,
                                              ),
                                              label: Text(
                                                isPlaying ? 'Pause' : 'Continue',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              style: TextButton.styleFrom(
                                                foregroundColor: const Color(0xFF4F46E5),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              onPressed: _stopListening,
                                              icon: const Icon(Icons.stop_circle_outlined, size: 22),
                                              color: const Color(0xFFE11D48),
                                              tooltip: 'Stop',
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                            ),
                                          ],
                                        ),
                                      );
                                    }

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _listenToDay,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4F46E5).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: const Color(0xFF4F46E5).withOpacity(0.25),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.volume_up_rounded, color: Color(0xFF4F46E5), size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Listen to Today\'s Reading & Devotional',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  color: const Color(0xFF4F46E5),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // ── Direct Inline Scripture Cards ─────────────────
                            Text(
                              'SCRIPTURE PASSAGES',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: const Color(0xFF4F46E5),
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_loadingScriptures)
                              Container(
                                padding: const EdgeInsets.all(32),
                                alignment: Alignment.center,
                                child: const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                              )
                            else
                              ...widget.day.scriptureReferences.map((ref) {
                                final verses = _scriptureVerses[ref] ?? [];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(20),
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.menu_book_rounded, color: Color(0xFF4F46E5), size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            ref,
                                            style: TextStyle(
                                              fontFamily: 'Cinzel',
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? const Color(0xFFFFC857) : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          const Spacer(),
                                          if (verses.isNotEmpty)
                                            TextButton.icon(
                                              onPressed: () {
                                                final first = verses.first;
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => BibleScreen(
                                                      initialBook: first.book,
                                                      initialChapter: first.chapter,
                                                    ),
                                                  ),
                                                );
                                              },
                                              icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                              label: const Text('Open Reader', style: TextStyle(fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                      const Divider(height: 20),
                                      if (verses.isEmpty)
                                        Text(
                                          'Scripture passage for $ref',
                                          style: TextStyle(fontFamily: 'Poppins', color: textSecondary),
                                        )
                                      else
                                        ...verses.map((v) {
                                          final isCurrentVerse = _activeSegmentKey == 'verse:$ref:${v.verse}';
                                          return AnimatedContainer(
                                            duration: const Duration(milliseconds: 220),
                                            margin: const EdgeInsets.symmetric(vertical: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isCurrentVerse
                                                  ? const Color(0xFF4F46E5).withOpacity(isDark ? 0.22 : 0.10)
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                SizedBox(
                                                  width: 32,
                                                  child: Text(
                                                    '${v.verse}',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: isCurrentVerse
                                                          ? (isDark ? const Color(0xFFFFC857) : const Color(0xFF4338CA))
                                                          : const Color(0xFF4F46E5),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    v.text,
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 14.5,
                                                      height: 1.65,
                                                      fontWeight: isCurrentVerse ? FontWeight.w600 : FontWeight.normal,
                                                      color: textPrimary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                );
                              }),

                            const SizedBox(height: 16),

                            // ── Devotional Reflection Card ────────────────────
                            Text(
                              'DAILY DEVOTIONAL REFLECTION',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: const Color(0xFF4F46E5),
                                fontSize: 12,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(20),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.day.devotionalText,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: textPrimary,
                                      fontSize: 14.5,
                                      height: 1.65,
                                    ),
                                  ),
                                  if (widget.day.reflectionQuestion != null) ...[
                                    const SizedBox(height: 20),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFF4F46E5).withOpacity(0.2),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('💡', style: TextStyle(fontSize: 18)),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Reflection Question',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF4F46E5),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  widget.day.reflectionQuestion!,
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    color: textPrimary,
                                                    fontSize: 13.5,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),

                            // ── Mark as Completed Button ──────────────────────
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _toggleComplete,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isCompleted
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF4F46E5),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Icon(
                                        _isCompleted
                                            ? Icons.check_circle_rounded
                                            : Icons.check_circle_outline_rounded,
                                      ),
                                label: Text(
                                  _isCompleted
                                      ? 'Completed (Click to Unmark)'
                                      : 'Mark Day ${widget.day.dayNumber} as Completed',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.plan.title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                Text(
                  'Day ${widget.day.dayNumber}: ${widget.day.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
