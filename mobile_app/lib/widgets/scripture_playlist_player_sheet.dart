// lib/widgets/scripture_playlist_player_sheet.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_data_models.dart';
import '../services/playlist_player_service.dart';
import '../theme/imago_theme.dart';

class ScripturePlaylistPlayerSheet extends StatefulWidget {
  const ScripturePlaylistPlayerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ScripturePlaylistPlayerSheet(),
    );
  }

  @override
  State<ScripturePlaylistPlayerSheet> createState() => _ScripturePlaylistPlayerSheetState();
}

class _ScripturePlaylistPlayerSheetState extends State<ScripturePlaylistPlayerSheet>
    with SingleTickerProviderStateMixin {
  final PlaylistPlayerService _player = PlaylistPlayerService.instance;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _equalizerController;
  bool _showQueue = false;

  @override
  void initState() {
    super.initState();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _equalizerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.88;

    return ValueListenableBuilder<BiblePlaylistItem?>(
      valueListenable: _player.currentTrackNotifier,
      builder: (context, currentTrack, _) {
        if (currentTrack == null && _player.playlist.isEmpty) {
          return Container(
            height: 200,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF07091B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Text(
              'No playlist loaded',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.white54),
            ),
          );
        }

        return Container(
          height: sheetHeight,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF080B1E).withOpacity(0.96),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: Column(
                  children: [
                    _buildHandleBar(),
                    _buildHeaderBar(),
                    Expanded(
                      child: _showQueue ? _buildQueueList() : _buildTranscriptView(currentTrack),
                    ),
                    _buildControlsBar(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandleBar() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 44,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    return ValueListenableBuilder<String>(
      valueListenable: _player.playlistTitleNotifier,
      builder: (context, title, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ImagoColors.violet.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: ImagoColors.gold.withOpacity(0.4)),
                ),
                child: Icon(Icons.headphones_rounded, color: ImagoColors.gold, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : 'Scripture Playlist',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: ImagoColors.cream,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    ValueListenableBuilder<int>(
                      valueListenable: _player.currentTrackIndexNotifier,
                      builder: (context, trackIndex, _) {
                        final total = _player.playlist.length;
                        return Text(
                          'Track ${trackIndex + 1} of $total',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _showQueue ? Icons.notes_rounded : Icons.queue_music_rounded,
                  color: _showQueue ? ImagoColors.gold : Colors.white60,
                ),
                onPressed: () => setState(() => _showQueue = !_showQueue),
              ),
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white54, size: 28),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranscriptView(BiblePlaylistItem? currentTrack) {
    if (currentTrack == null || currentTrack.verses.isEmpty) {
      return Center(
        child: Text('No verses in track', style: TextStyle(color: Colors.white54)),
      );
    }

    return Column(
      children: [
        // Track Header Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ImagoColors.violet.withOpacity(0.25),
                const Color(0xFF1B1147).withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ImagoColors.gold.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: ImagoColors.violet.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTrack.displayTitle,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        color: ImagoColors.gold,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${currentTrack.totalVerses} ${currentTrack.totalVerses == 1 ? "Verse" : "Verses"}',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              _buildEqualizerWave(),
            ],
          ),
        ),

        // Scrollable Verses List with active highlight
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: _player.currentVerseIndexNotifier,
            builder: (context, activeVerseIndex, _) {
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                itemCount: currentTrack.verses.length,
                itemBuilder: (context, index) {
                  final verse = currentTrack.verses[index];
                  final isCurrentSpoken = index == activeVerseIndex && _player.isPlaying;

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isCurrentSpoken
                          ? ImagoColors.violet.withOpacity(0.28)
                          : Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrentSpoken
                            ? ImagoColors.gold.withOpacity(0.8)
                            : Colors.white.withOpacity(0.06),
                        width: isCurrentSpoken ? 1.5 : 1.0,
                      ),
                      boxShadow: isCurrentSpoken
                          ? [
                              BoxShadow(
                                color: ImagoColors.gold.withOpacity(0.2),
                                blurRadius: 12,
                                spreadRadius: 1,
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCurrentSpoken
                                ? ImagoColors.gold
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${verse.verse}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: isCurrentSpoken ? Colors.black : ImagoColors.cream,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            verse.text,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: isCurrentSpoken ? Colors.white : Colors.white.withOpacity(0.75),
                              fontSize: 15,
                              height: 1.55,
                              fontWeight: isCurrentSpoken ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: _player.playlist.length,
      itemBuilder: (context, index) {
        final item = _player.playlist[index];
        final isCurrentTrack = index == _player.currentTrackIndex;

        return GestureDetector(
          onTap: () {
            _player.seekToTrack(index);
            setState(() => _showQueue = false);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isCurrentTrack
                  ? ImagoColors.violet.withOpacity(0.25)
                  : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentTrack
                    ? ImagoColors.gold.withOpacity(0.6)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: isCurrentTrack ? ImagoColors.gold : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayTitle,
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          color: isCurrentTrack ? ImagoColors.gold : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${item.totalVerses} ${item.totalVerses == 1 ? "verse" : "verses"}',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isCurrentTrack)
                  Icon(Icons.volume_up_rounded, color: ImagoColors.gold, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEqualizerWave() {
    return ValueListenableBuilder<bool>(
      valueListenable: _player.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        if (!isPlaying) return const SizedBox.shrink();

        return AnimatedBuilder(
          animation: _equalizerController,
          builder: (context, _) {
            final val = _equalizerController.value;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(4, (index) {
                final heights = [14.0, 24.0, 18.0, 28.0];
                final multiplier = (index % 2 == 0) ? val : (1.0 - val);
                final h = (heights[index] * (0.4 + 0.6 * multiplier)).clamp(6.0, 30.0);

                return Container(
                  width: 3.5,
                  height: h,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: ImagoColors.gold,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }

  Widget _buildControlsBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: ImagoColors.isDark ? const Color(0xFF040510).withOpacity(0.9) : ImagoColors.surface,
        border: Border(top: BorderSide(color: ImagoColors.borderColor)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed selector
              ValueListenableBuilder<double>(
                valueListenable: _player.speedNotifier,
                builder: (context, speed, _) {
                  return GestureDetector(
                    onTap: () {
                      final speeds = [0.8, 1.0, 1.25, 1.5];
                      final nextIdx = (speeds.indexOf(speed) + 1) % speeds.length;
                      _player.setSpeed(speeds[nextIdx]);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Text(
                        '${speed}x',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: ImagoColors.cream,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Transport Controls: Prev, Play/Pause, Next
              Row(
                children: [
                  IconButton(
                    iconSize: 32,
                    icon: Icon(Icons.skip_previous_rounded, color: Colors.white.withOpacity(0.85)),
                    onPressed: () => _player.previousTrack(),
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<bool>(
                    valueListenable: _player.isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return GestureDetector(
                        onTap: () {
                          if (isPlaying) {
                            _player.pause();
                          } else {
                            _player.play();
                          }
                        },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: ImagoColors.violetGradient,
                            boxShadow: [
                              BoxShadow(
                                color: ImagoColors.violet.withOpacity(0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    iconSize: 32,
                    icon: Icon(Icons.skip_next_rounded, color: Colors.white.withOpacity(0.85)),
                    onPressed: () => _player.nextTrack(),
                  ),
                ],
              ),

              // Loop Toggle
              ValueListenableBuilder<bool>(
                valueListenable: _player.isLoopingNotifier,
                builder: (context, isLooping, _) {
                  return IconButton(
                    icon: Icon(
                      Icons.repeat_rounded,
                      color: isLooping ? ImagoColors.gold : Colors.white38,
                    ),
                    onPressed: () => _player.toggleLoop(),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
