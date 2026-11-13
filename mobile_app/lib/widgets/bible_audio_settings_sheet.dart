import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import '../services/tts_service.dart';
import '../theme/imago_theme.dart';

class BibleAudioSettingsSheet extends StatefulWidget {
  final ReaderTheme readerTheme;

  const BibleAudioSettingsSheet({super.key, required this.readerTheme});

  static Future<void> show(BuildContext context, {required ReaderTheme readerTheme}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: BibleAudioSettingsSheet(readerTheme: readerTheme),
      ),
    );
  }

  @override
  State<BibleAudioSettingsSheet> createState() => _BibleAudioSettingsSheetState();
}

class _BibleAudioSettingsSheetState extends State<BibleAudioSettingsSheet> {
  late double _speed;
  late double _pitch;
  late String _ambientTrack;
  late double _ambientVolume;
  List<TtsVoice> _voices = [];
  TtsVoice? _selectedVoice;
  bool _isLoadingVoices = true;
  bool _isPreviewingVoice = false;
  bool _isPreviewingAmbient = false;
  bool _isPickingCustomAudio = false;
  String? _customAudioFileName;

  @override
  void initState() {
    super.initState();
    final tts = TtsService.instance;
    _speed = tts.speedMultiplier;
    _pitch = tts.pitch;
    _ambientTrack = tts.ambientTrack;
    _ambientVolume = tts.ambientVolume;
    _customAudioFileName = tts.customAmbientName;
    _loadVoices();
  }

  Future<void> _pickCustomAudioFile() async {
    try {
      setState(() => _isPickingCustomAudio = true);
      const typeGroup = XTypeGroup(
        label: 'Audio',
        extensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'],
        mimeTypes: ['audio/*'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file != null) {
        final docDir = await getApplicationDocumentsDirectory();
        final ext = file.name.split('.').last;
        final targetPath = '${docDir.path}/custom_ambient.$ext';

        // Copy picked file bytes to local persistent app storage
        final bytes = await file.readAsBytes();
        await File(targetPath).writeAsBytes(bytes, flush: true);

        final fileName = file.name;
        await TtsService.instance.setCustomAmbientTrack(targetPath, fileName);

        if (mounted) {
          setState(() {
            _ambientTrack = 'custom';
            _customAudioFileName = fileName;
            if (_ambientVolume <= 0.001) {
              _ambientVolume = 0.08;
              TtsService.instance.setAmbientVolume(0.08);
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Custom ambiance set: $fileName'),
              duration: const Duration(seconds: 2),
            ),
          );
        }

        if (_isPreviewingAmbient) {
          await TtsService.instance.previewAmbient('custom', _ambientVolume);
        }
      }
    } catch (e) {
      debugPrint('Error picking custom audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load audio file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingCustomAudio = false);
      }
    }
  }

  @override
  void dispose() {
    if (_isPreviewingAmbient) {
      TtsService.instance.stopAmbient();
    }
    if (_isPreviewingVoice) {
      TtsService.instance.stop();
    }
    super.dispose();
  }

  Future<void> _loadVoices() async {
    final detailed = await TtsService.instance.getDetailedVoices();
    if (!mounted) return;
    final currentSelectedName = TtsService.instance.selectedVoice?['name'];

    setState(() {
      _voices = detailed;
      _isLoadingVoices = false;
      if (currentSelectedName != null) {
        _selectedVoice = detailed.where((v) => v.name == currentSelectedName).firstOrNull;
      }
      if (_selectedVoice == null && detailed.isNotEmpty) {
        _selectedVoice = detailed.firstWhere(
          (v) => v.locale.toLowerCase().startsWith('en'),
          orElse: () => detailed.first,
        );
      }
    });
  }

  Future<void> _togglePreviewVoice() async {
    if (_isPreviewingVoice) {
      await TtsService.instance.stop();
      setState(() => _isPreviewingVoice = false);
    } else {
      setState(() => _isPreviewingVoice = true);
      const sampleText = "The LORD is my shepherd; I shall not want. He maketh me to lie down in green pastures.";
      await TtsService.instance.speakAndWait(sampleText, withAmbient: _isPreviewingAmbient);
      if (mounted) {
        setState(() => _isPreviewingVoice = false);
      }
    }
  }

  Future<void> _togglePreviewAmbient() async {
    if (_isPreviewingAmbient) {
      await TtsService.instance.stopAmbient();
      setState(() => _isPreviewingAmbient = false);
    } else {
      if (_ambientVolume <= 0.001) {
        setState(() => _ambientVolume = 0.25);
        await TtsService.instance.setAmbientVolume(0.25);
      }
      await TtsService.instance.previewAmbient(_ambientTrack, _ambientVolume);
      setState(() => _isPreviewingAmbient = true);
    }
  }

  void _openVoicePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: _BibleVoicePickerModal(
          voices: _voices,
          selectedVoiceName: _selectedVoice?.name,
          readerTheme: widget.readerTheme,
          onSelectVoice: (voice) {
            setState(() => _selectedVoice = voice);
            TtsService.instance.setDetailedVoice(voice);
          },
        ),
      ),
    );
  }

  String _getPitchLabel(double pitch) {
    if (pitch < 0.8) return 'Deep & Reverent';
    if (pitch < 0.98) return 'Warm Pastoral';
    if (pitch <= 1.05) return 'Natural Voice';
    if (pitch <= 1.25) return 'Clear & Bright';
    return 'High Tone';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme;
    final isDark = theme.isDark;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0E1E).withOpacity(0.97) : theme.surface.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.6 : 0.15),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.secondaryText.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: isDark ? ImagoColors.violetGradient : null,
                  color: isDark ? null : theme.accentColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Studio & Peaceful Ambiance',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: theme.primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'AI voice, reading speed, tone & ambient worship',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: theme.secondaryText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close_rounded, color: theme.secondaryText, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Content scroll area
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // ── 1. Reading Speed ───────────────────────────────
                _buildSectionHeader('AI READING SPEED', '${_speed.toStringAsFixed(2)}x', theme),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: theme.accentColor,
                    inactiveTrackColor: theme.borderColor,
                    thumbColor: isDark ? ImagoColors.gold : theme.accentColor,
                    overlayColor: theme.accentColor.withOpacity(0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _speed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: (val) {
                      setState(() => _speed = val);
                      TtsService.instance.setSpeechRate(val);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPresetChip('0.75x Calm', 0.75, _speed, (v) {
                      setState(() => _speed = v);
                      TtsService.instance.setSpeechRate(v);
                    }, theme),
                    _buildPresetChip('1.0x Normal', 1.0, _speed, (v) {
                      setState(() => _speed = v);
                      TtsService.instance.setSpeechRate(v);
                    }, theme),
                    _buildPresetChip('1.25x Dynamic', 1.25, _speed, (v) {
                      setState(() => _speed = v);
                      TtsService.instance.setSpeechRate(v);
                    }, theme),
                    _buildPresetChip('1.5x Fast', 1.5, _speed, (v) {
                      setState(() => _speed = v);
                      TtsService.instance.setSpeechRate(v);
                    }, theme),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 2. Voice Tone / Pitch ───────────────────────────
                _buildSectionHeader('VOICE TONE & PITCH', _getPitchLabel(_pitch), theme),
                const SizedBox(height: 6),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: theme.accentColor,
                    inactiveTrackColor: theme.borderColor,
                    thumbColor: isDark ? ImagoColors.gold : theme.accentColor,
                    overlayColor: theme.accentColor.withOpacity(0.15),
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: _pitch,
                    min: 0.6,
                    max: 1.4,
                    divisions: 16,
                    onChanged: (val) {
                      setState(() => _pitch = val);
                      TtsService.instance.setPitch(val);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildPresetChip('Reverent (0.75)', 0.75, _pitch, (v) {
                      setState(() => _pitch = v);
                      TtsService.instance.setPitch(v);
                    }, theme),
                    _buildPresetChip('Pastoral (0.95)', 0.95, _pitch, (v) {
                      setState(() => _pitch = v);
                      TtsService.instance.setPitch(v);
                    }, theme),
                    _buildPresetChip('Natural (1.0)', 1.0, _pitch, (v) {
                      setState(() => _pitch = v);
                      TtsService.instance.setPitch(v);
                    }, theme),
                    _buildPresetChip('Bright (1.2)', 1.2, _pitch, (v) {
                      setState(() => _pitch = v);
                      TtsService.instance.setPitch(v);
                    }, theme),
                  ],
                ),
                const SizedBox(height: 20),

                // ── 3. Specific Voice Selection & Sample ────────────
                _buildSectionHeader('SPECIFIC AI VOICE & PERSONA', _selectedVoice?.displayName ?? 'System Default', theme),
                const SizedBox(height: 8),
                if (_isLoadingVoices)
                  Center(child: CircularProgressIndicator(color: theme.accentColor, strokeWidth: 2))
                else
                  _buildSpecificVoiceCard(theme),
                const SizedBox(height: 10),

                // Preview voice sample button
                GestureDetector(
                  onTap: _togglePreviewVoice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: _isPreviewingVoice ? Colors.redAccent.withOpacity(0.2) : theme.accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPreviewingVoice ? Colors.redAccent : theme.accentColor.withOpacity(0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isPreviewingVoice ? Icons.stop_rounded : Icons.play_arrow_rounded,
                          color: _isPreviewingVoice ? Colors.redAccent : theme.accentColor,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPreviewingVoice ? 'Stop Sample Preview' : 'Test Current Voice (Psalm 23:1)',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isPreviewingVoice ? Colors.redAccent : theme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── 4. Peaceful Background Ambiance ────────────────
                _buildSectionHeader('BACKGROUND AMBIANCE SOUND', TtsService.kAmbientTrackNames[_ambientTrack] ?? '', theme),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildAmbientCard(
                      'pad',
                      'Sacred Atmosphere',
                      'Warm celestial pad',
                      Icons.nights_stay_rounded,
                      theme,
                    ),
                    _buildAmbientCard(
                      'rain',
                      'Living Waters',
                      'Gentle rain & stream',
                      Icons.water_drop_rounded,
                      theme,
                    ),
                    _buildAmbientCard(
                      'drone',
                      '432Hz Meditation',
                      'Deep prayer drone',
                      Icons.spa_rounded,
                      theme,
                    ),
                    _buildAmbientCard(
                      'custom',
                      _customAudioFileName != null ? 'My Device Music' : 'Custom Music',
                      _customAudioFileName ?? 'Tap to pick audio file',
                      Icons.audio_file_rounded,
                      theme,
                    ),
                    _buildAmbientCard(
                      'none',
                      'Pure Voice',
                      'No background sound',
                      Icons.volume_off_rounded,
                      theme,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Button to pick or change device music
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _isPickingCustomAudio ? null : _pickCustomAudioFile,
                    icon: _isPickingCustomAudio
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.accentColor),
                          )
                        : Icon(Icons.folder_open_rounded, size: 16, color: theme.accentColor),
                    label: Text(
                      _customAudioFileName != null
                          ? 'Change Device Music (${_customAudioFileName!})'
                          : 'Add Music from Device',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: theme.accentColor,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.accentColor.withOpacity(0.35)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Ambiance Volume Slider (only if not 'none')
                if (_ambientTrack != 'none') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _ambientVolume <= 0.001 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            size: 16,
                            color: _ambientVolume <= 0.001 ? Colors.redAccent : theme.accentColor,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ambiance Volume (Soft default: 8%)',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          final newVol = _ambientVolume > 0.001 ? 0.0 : 0.08;
                          setState(() => _ambientVolume = newVol);
                          TtsService.instance.setAmbientVolume(newVol);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _ambientVolume <= 0.001
                                ? Colors.redAccent.withOpacity(0.15)
                                : theme.accentColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _ambientVolume <= 0.001 ? 'Muted (0%)' : '${(_ambientVolume * 100).toInt()}%',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: _ambientVolume <= 0.001 ? Colors.redAccent : theme.accentColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: _ambientVolume <= 0.001 ? theme.borderColor : theme.accentColor,
                      inactiveTrackColor: theme.borderColor,
                      thumbColor: _ambientVolume <= 0.001 ? theme.secondaryText : (isDark ? ImagoColors.gold : theme.accentColor),
                      overlayColor: theme.accentColor.withOpacity(0.15),
                      trackHeight: 4,
                    ),
                    child: Slider(
                      value: _ambientVolume.clamp(0.0, 1.0),
                      min: 0.0,
                      max: 1.0,
                      divisions: 25,
                      onChanged: (val) {
                        setState(() => _ambientVolume = val);
                        TtsService.instance.setAmbientVolume(val);
                      },
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPresetChip('Mute (0%)', 0.0, _ambientVolume, (v) {
                        setState(() => _ambientVolume = v);
                        TtsService.instance.setAmbientVolume(v);
                      }, theme),
                      _buildPresetChip('Gentle (8%)', 0.08, _ambientVolume, (v) {
                        setState(() => _ambientVolume = v);
                        TtsService.instance.setAmbientVolume(v);
                      }, theme),
                      _buildPresetChip('Soft (15%)', 0.15, _ambientVolume, (v) {
                        setState(() => _ambientVolume = v);
                        TtsService.instance.setAmbientVolume(v);
                      }, theme),
                      _buildPresetChip('Standard (30%)', 0.30, _ambientVolume, (v) {
                        setState(() => _ambientVolume = v);
                        TtsService.instance.setAmbientVolume(v);
                      }, theme),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Preview Ambient Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _togglePreviewAmbient,
                      icon: Icon(
                        _isPreviewingAmbient ? Icons.stop_rounded : Icons.headphones_rounded,
                        size: 16,
                        color: theme.accentColor,
                      ),
                      label: Text(
                        _isPreviewingAmbient ? 'Stop Ambiance' : 'Preview Ambiance Music',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.accentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificVoiceCard(ReaderTheme theme) {
    final voice = _selectedVoice;
    final isDark = theme.isDark;

    return InkWell(
      onTap: () => _openVoicePicker(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Country flag / avatar
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                voice?.countryFlag ?? '🎙️',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(width: 12),
            // Voice Name & details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          voice?.displayName ?? 'Select a Specific Voice',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: theme.primaryText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (voice != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: voice.gender == 'Female'
                                ? Colors.pinkAccent.withOpacity(0.15)
                                : Colors.blueAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            voice.gender == 'Female' ? '♀ Female' : '♂ Male',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: voice.gender == 'Female' ? Colors.pinkAccent : Colors.blueAccent,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${voice?.languageName ?? 'English'} • ${voice?.quality ?? 'Studio'}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: theme.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Change',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.tune_rounded, size: 14, color: theme.accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String value, ReaderTheme theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: theme.secondaryText.withOpacity(0.8),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: theme.accentColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(
    String label,
    double value,
    double currentValue,
    ValueChanged<double> onSelect,
    ReaderTheme theme,
  ) {
    final isSelected = (currentValue - value).abs() < 0.04;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : theme.cardBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : theme.primaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildAmbientCard(
    String keyName,
    String title,
    String subtitle,
    IconData icon,
    ReaderTheme theme,
  ) {
    final isSelected = _ambientTrack == keyName;
    return GestureDetector(
      onTap: () {
        if (keyName == 'custom' && _customAudioFileName == null) {
          _pickCustomAudioFile();
          return;
        }
        setState(() => _ambientTrack = keyName);
        TtsService.instance.setAmbientTrack(keyName);
        if (_isPreviewingAmbient) {
          if (keyName == 'none') {
            setState(() => _isPreviewingAmbient = false);
          } else {
            TtsService.instance.previewAmbient(keyName, _ambientVolume);
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.accentColor.withOpacity(theme.isDark ? 0.25 : 0.15)
              : theme.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? theme.accentColor : theme.borderColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : theme.primaryText,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.accentColor : theme.primaryText,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dedicated, specific voice picker modal allowing filter by region, gender, and inline audio preview
class _BibleVoicePickerModal extends StatefulWidget {
  final List<TtsVoice> voices;
  final String? selectedVoiceName;
  final ReaderTheme readerTheme;
  final ValueChanged<TtsVoice> onSelectVoice;

  const _BibleVoicePickerModal({
    required this.voices,
    required this.selectedVoiceName,
    required this.readerTheme,
    required this.onSelectVoice,
  });

  @override
  State<_BibleVoicePickerModal> createState() => _BibleVoicePickerModalState();
}

class _BibleVoicePickerModalState extends State<_BibleVoicePickerModal> {
  String _searchQuery = '';
  String _selectedRegionFilter = 'en'; // 'all', 'en', 'us', 'gb', 'ng', 'au'
  String _selectedGenderFilter = 'all'; // 'all', 'Female', 'Male'
  String? _previewingVoiceName;

  @override
  void dispose() {
    if (_previewingVoiceName != null) {
      TtsService.instance.stop();
    }
    super.dispose();
  }

  Future<void> _previewVoice(TtsVoice voice) async {
    if (_previewingVoiceName == voice.name) {
      await TtsService.instance.stop();
      if (mounted) setState(() => _previewingVoiceName = null);
      return;
    }

    setState(() => _previewingVoiceName = voice.name);
    // Temporarily apply voice
    await TtsService.instance.setDetailedVoice(voice);
    const sample = "The Lord is my shepherd; I shall not want.";
    await TtsService.instance.speakAndWait(sample, withAmbient: false);
    if (mounted) {
      setState(() => _previewingVoiceName = null);
    }
  }

  List<TtsVoice> _filterVoices() {
    return widget.voices.where((v) {
      // 1. Search Query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchesName = v.displayName.toLowerCase().contains(q);
        final matchesLang = v.languageName.toLowerCase().contains(q);
        final matchesLocale = v.locale.toLowerCase().contains(q);
        if (!matchesName && !matchesLang && !matchesLocale) return false;
      }

      // 2. Region / Language Filter
      final lowerLocale = v.locale.toLowerCase();
      if (_selectedRegionFilter == 'en') {
        if (!lowerLocale.startsWith('en')) return false;
      } else if (_selectedRegionFilter == 'us') {
        if (!lowerLocale.contains('us')) return false;
      } else if (_selectedRegionFilter == 'gb') {
        if (!lowerLocale.contains('gb') && !lowerLocale.contains('uk')) return false;
      } else if (_selectedRegionFilter == 'au') {
        if (!lowerLocale.contains('au')) return false;
      } else if (_selectedRegionFilter == 'ng') {
        if (!lowerLocale.contains('ng')) return false;
      }

      // 3. Gender Filter
      if (_selectedGenderFilter != 'all' && v.gender != _selectedGenderFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.readerTheme;
    final isDark = theme.isDark;
    final filtered = _filterVoices();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0C0E1E).withOpacity(0.98) : theme.surface.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 44,
            height: 4.5,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.secondaryText.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          // Header
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Specific Narrator Voice',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: theme.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${filtered.length} voices available • Tap ▶ to test tone',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: theme.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Search Field
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 18, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: theme.primaryText),
                    decoration: InputDecoration(
                      hintText: 'Search voice name or region...',
                      hintStyle: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: theme.secondaryText.withOpacity(0.6)),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: Icon(Icons.close_rounded, size: 16, color: theme.secondaryText),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Region Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('English (All)', 'en', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
                const SizedBox(width: 6),
                _buildFilterChip('🇺🇸 US English', 'us', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
                const SizedBox(width: 6),
                _buildFilterChip('🇬🇧 UK English', 'gb', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
                const SizedBox(width: 6),
                _buildFilterChip('🇦🇺 Australia', 'au', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
                const SizedBox(width: 6),
                _buildFilterChip('🇳🇬 Nigeria', 'ng', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
                const SizedBox(width: 6),
                _buildFilterChip('🌐 All Languages', 'all', _selectedRegionFilter, (v) => setState(() => _selectedRegionFilter = v), theme),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Gender Filter Chips
          Row(
            children: [
              _buildFilterChip('All Voices', 'all', _selectedGenderFilter, (v) => setState(() => _selectedGenderFilter = v), theme),
              const SizedBox(width: 6),
              _buildFilterChip('♀ Female Only', 'Female', _selectedGenderFilter, (v) => setState(() => _selectedGenderFilter = v), theme),
              const SizedBox(width: 6),
              _buildFilterChip('♂ Male Only', 'Male', _selectedGenderFilter, (v) => setState(() => _selectedGenderFilter = v), theme),
            ],
          ),
          const SizedBox(height: 12),

          // Voice List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matching voices found.\nTry clearing your search or filter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: theme.secondaryText,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (ctx, i) {
                      final voice = filtered[i];
                      final isSelected = voice.name == widget.selectedVoiceName;
                      final isTesting = _previewingVoiceName == voice.name;

                      return InkWell(
                        onTap: () {
                          widget.onSelectVoice(voice);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.accentColor.withOpacity(isDark ? 0.22 : 0.12)
                                : theme.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? theme.accentColor : theme.borderColor,
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Flag / Icon
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Text(voice.countryFlag, style: const TextStyle(fontSize: 18)),
                              ),
                              const SizedBox(width: 10),

                              // Voice Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            voice.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 13,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? theme.accentColor : theme.primaryText,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: voice.gender == 'Female'
                                                ? Colors.pinkAccent.withOpacity(0.15)
                                                : Colors.blueAccent.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            voice.gender == 'Female' ? '♀' : '♂',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: voice.gender == 'Female' ? Colors.pinkAccent : Colors.blueAccent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${voice.languageName} • ${voice.locale} • ${voice.quality}',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10.5,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Inline Audio Preview Button
                              IconButton(
                                onPressed: () => _previewVoice(voice),
                                tooltip: isTesting ? 'Stop sample' : 'Listen to voice sample',
                                icon: Icon(
                                  isTesting ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                                  color: isTesting ? Colors.redAccent : theme.accentColor,
                                  size: 26,
                                ),
                              ),

                              // Selection Indicator
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: theme.accentColor, size: 20)
                              else
                                Icon(Icons.radio_button_unchecked_rounded, color: theme.secondaryText.withOpacity(0.4), size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String currentValue,
    ValueChanged<String> onSelect,
    ReaderTheme theme,
  ) {
    final isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : theme.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.borderColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : theme.primaryText,
          ),
        ),
      ),
    );
  }
}
