import 'package:flutter/material.dart';
import '../services/audio_pronunciation_service.dart';
import '../theme/imago_theme.dart';

class AudioSpeakerButton extends StatefulWidget {
  final String term;
  final String? translit;
  final String? pron;
  final String type;
  final double size;

  const AudioSpeakerButton({
    super.key,
    required this.term,
    this.translit,
    this.pron,
    required this.type,
    this.size = 18,
  });

  @override
  State<AudioSpeakerButton> createState() => _AudioSpeakerButtonState();
}

class _AudioSpeakerButtonState extends State<AudioSpeakerButton> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handlePlay() async {
    setState(() {
      _playing = true;
    });
    _animController.repeat(reverse: true);

    await AudioPronunciationService.instance.speak(
      term: widget.term,
      translit: widget.translit,
      pron: widget.pron,
      type: widget.type,
    );

    if (mounted) {
      _animController.stop();
      _animController.reset();
      setState(() {
        _playing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handlePlay,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) {
          return Transform.scale(
            scale: _playing ? _scaleAnim.value : 1.0,
            child: Container(
              padding: EdgeInsets.all(widget.size * 0.4),
              decoration: BoxDecoration(
                gradient: _playing ? ImagoColors.violetGradient : null,
                color: _playing ? null : ImagoColors.gold.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _playing ? ImagoColors.gold : ImagoColors.gold.withOpacity(0.4),
                  width: 1,
                ),
                boxShadow: _playing
                    ? [
                        BoxShadow(
                          color: ImagoColors.violet.withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                _playing ? Icons.volume_up_rounded : Icons.volume_up_outlined,
                color: _playing ? Colors.white : ImagoColors.gold,
                size: widget.size,
              ),
            ),
          );
        },
      ),
    );
  }
}
