import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../theme/imago_theme.dart';

class CounselorVoiceSheet extends StatefulWidget {
  final bool autoReadEnabled;
  final ValueChanged<bool> onAutoReadChanged;

  const CounselorVoiceSheet({
    super.key,
    required this.autoReadEnabled,
    required this.onAutoReadChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required bool autoReadEnabled,
    required ValueChanged<bool> onAutoReadChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: CounselorVoiceSheet(
          autoReadEnabled: autoReadEnabled,
          onAutoReadChanged: onAutoReadChanged,
        ),
      ),
    );
  }

  @override
  State<CounselorVoiceSheet> createState() => _CounselorVoiceSheetState();
}

class _CounselorVoiceSheetState extends State<CounselorVoiceSheet> {
  late String _selectedPersonaKey;
  late bool _autoRead;
  String? _previewingKey;

  @override
  void initState() {
    super.initState();
    _selectedPersonaKey = TtsService.instance.counselorVoice;
    _autoRead = widget.autoReadEnabled;
  }

  @override
  void dispose() {
    TtsService.instance.stopCounselor();
    super.dispose();
  }

  Future<void> _previewVoice(String key, String name) async {
    if (_previewingKey == key) {
      await TtsService.instance.stopCounselor();
      if (mounted) setState(() => _previewingKey = null);
      return;
    }

    setState(() => _previewingKey = key);
    final sample = 'Peace be with you. I am $name, your pastoral companion. The Lord is your shepherd and shield.';
    await TtsService.instance.speakCounselor(sample, voice: key);
    if (mounted) {
      setState(() => _previewingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ImagoColors.isDark;
    final bg = isDark ? const Color(0xFF130E2E) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1747) : const Color(0xFFF8FAFC);
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subTextCol = isDark ? Colors.white.withValues(alpha: 0.6) : const Color(0xFF64748B);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.record_voice_over_rounded,
                    color: Color(0xFF6366F1),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Counselor Voice Studio',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                      ),
                      Text(
                        'Studio-quality, human-like pastoral speech',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: subTextCol,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: subTextCol),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Auto-read switch tile
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Icon(
                  _autoRead ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: const Color(0xFF6366F1),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto Read-Aloud Responses',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textCol,
                        ),
                      ),
                      Text(
                        'Speaks new counseling replies automatically',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: subTextCol,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _autoRead,
                  activeColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setState(() => _autoRead = val);
                    widget.onAutoReadChanged(val);
                  },
                ),
              ],
            ),
          ),

          // Section Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHOOSE COUNSELOR PERSONA',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ),
          ),

          // Voice Personas List
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: TtsService.kCounselorPersonas.length,
              itemBuilder: (context, index) {
                final key = TtsService.kCounselorPersonas.keys.elementAt(index);
                final persona = TtsService.kCounselorPersonas[key]!;
                final isSelected = key == _selectedPersonaKey;
                final isPreviewing = key == _previewingKey;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF6366F1)
                          : cardBorder,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                              )
                            : LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF2D2261), const Color(0xFF1E1747)]
                                    : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                              ),
                      ),
                      child: Center(
                        child: Text(
                          persona['country']?.split(' ').first ?? '🎙️',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          persona['name'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? const Color(0xFF6366F1) : textCol,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'HD Studio',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          persona['title'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: subTextCol,
                          ),
                        ),
                        Text(
                          persona['desc'] ?? '',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: subTextCol.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Preview Button
                        IconButton(
                          icon: Icon(
                            isPreviewing ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                            color: isPreviewing ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                            size: 26,
                          ),
                          tooltip: isPreviewing ? 'Stop Preview' : 'Listen Sample',
                          onPressed: () => _previewVoice(key, persona['name'] ?? 'Counselor'),
                        ),
                        // Select indicator
                        if (isSelected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF6366F1),
                            size: 22,
                          ),
                      ],
                    ),
                    onTap: () {
                      setState(() => _selectedPersonaKey = key);
                      TtsService.instance.setCounselorVoice(key);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

