// lib/services/playlist_player_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user_data_models.dart';
import 'tts_service.dart';

class PlaylistPlayerService {
  PlaylistPlayerService._();
  static final PlaylistPlayerService instance = PlaylistPlayerService._();

  List<BiblePlaylistItem> _playlist = [];
  int _currentTrackIndex = 0;
  int _currentVerseIndex = 0;
  bool _isPlaying = false;
  bool _isLooping = false;
  double _speedMultiplier = 1.0;
  String _playlistTitle = '';

  int _playbackSessionId = 0;

  // Notifiers for UI reactivity
  final ValueNotifier<bool> isPlayingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> currentTrackIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> currentVerseIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<BiblePlaylistItem?> currentTrackNotifier = ValueNotifier<BiblePlaylistItem?>(null);
  final ValueNotifier<String> playlistTitleNotifier = ValueNotifier<String>('');
  final ValueNotifier<double> speedNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> isLoopingNotifier = ValueNotifier<bool>(false);

  List<BiblePlaylistItem> get playlist => _playlist;
  int get currentTrackIndex => _currentTrackIndex;
  int get currentVerseIndex => _currentVerseIndex;
  bool get isPlaying => _isPlaying;
  bool get isLooping => _isLooping;
  double get speedMultiplier => _speedMultiplier;
  String get playlistTitle => _playlistTitle;

  Future<void> loadPlaylist(
    String title,
    List<BiblePlaylistItem> items, {
    int initialTrackIndex = 0,
    bool autoPlay = true,
  }) async {
    await stop();

    _playlist = List.from(items);
    _playlistTitle = title;
    _currentTrackIndex = initialTrackIndex.clamp(0, items.isEmpty ? 0 : items.length - 1);
    _currentVerseIndex = 0;

    playlistTitleNotifier.value = title;
    currentTrackIndexNotifier.value = _currentTrackIndex;
    currentVerseIndexNotifier.value = 0;
    currentTrackNotifier.value = _playlist.isNotEmpty ? _playlist[_currentTrackIndex] : null;

    if (autoPlay && _playlist.isNotEmpty) {
      await play();
    }
  }

  Future<void> play() async {
    if (_playlist.isEmpty) return;
    _isPlaying = true;
    isPlayingNotifier.value = true;
    _playbackSessionId++;
    await _startPlaybackLoop(_playbackSessionId);
  }

  Future<void> pause() async {
    _isPlaying = false;
    isPlayingNotifier.value = false;
    await TtsService.instance.stop();
  }

  Future<void> resume() async {
    if (_playlist.isEmpty) return;
    await play();
  }

  Future<void> stop() async {
    _isPlaying = false;
    _playbackSessionId++;
    isPlayingNotifier.value = false;
    await TtsService.instance.stop();
  }

  Future<void> nextTrack() async {
    if (_playlist.isEmpty) return;
    await TtsService.instance.stop();
    if (_currentTrackIndex < _playlist.length - 1) {
      _currentTrackIndex++;
    } else {
      _currentTrackIndex = 0;
    }
    _currentVerseIndex = 0;
    _updateTrackState();
    if (_isPlaying) {
      _playbackSessionId++;
      await _startPlaybackLoop(_playbackSessionId);
    }
  }

  Future<void> previousTrack() async {
    if (_playlist.isEmpty) return;
    await TtsService.instance.stop();
    if (_currentVerseIndex > 0) {
      _currentVerseIndex = 0;
    } else if (_currentTrackIndex > 0) {
      _currentTrackIndex--;
      _currentVerseIndex = 0;
    } else {
      _currentTrackIndex = _playlist.length - 1;
      _currentVerseIndex = 0;
    }
    _updateTrackState();
    if (_isPlaying) {
      _playbackSessionId++;
      await _startPlaybackLoop(_playbackSessionId);
    }
  }

  Future<void> seekToTrack(int trackIndex) async {
    if (trackIndex < 0 || trackIndex >= _playlist.length) return;
    await TtsService.instance.stop();
    _currentTrackIndex = trackIndex;
    _currentVerseIndex = 0;
    _updateTrackState();
    if (_isPlaying) {
      _playbackSessionId++;
      await _startPlaybackLoop(_playbackSessionId);
    }
  }

  Future<void> setSpeed(double rate) async {
    _speedMultiplier = rate;
    speedNotifier.value = rate;
    final targetRate = (0.45 * rate).clamp(0.2, 1.0);
    await TtsService.instance.setSpeechRate(targetRate);
  }

  void toggleLoop() {
    _isLooping = !_isLooping;
    isLoopingNotifier.value = _isLooping;
  }

  void _updateTrackState() {
    currentTrackIndexNotifier.value = _currentTrackIndex;
    currentVerseIndexNotifier.value = _currentVerseIndex;
    currentTrackNotifier.value = _playlist.isNotEmpty && _currentTrackIndex < _playlist.length
        ? _playlist[_currentTrackIndex]
        : null;
  }

  Future<void> _startPlaybackLoop(int sessionId) async {
    while (_isPlaying && sessionId == _playbackSessionId && _currentTrackIndex < _playlist.length) {
      final track = _playlist[_currentTrackIndex];
      _updateTrackState();

      if (_currentVerseIndex == 0) {
        final introText = "Now reading ${track.displayTitle}.";
        await TtsService.instance.speakAndWait(introText);
        if (!_isPlaying || sessionId != _playbackSessionId) return;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      while (_isPlaying && sessionId == _playbackSessionId && _currentVerseIndex < track.verses.length) {
        currentVerseIndexNotifier.value = _currentVerseIndex;
        final verse = track.verses[_currentVerseIndex];
        
        final spokenText = verse.text;
        await TtsService.instance.speakAndWait(spokenText);

        if (!_isPlaying || sessionId != _playbackSessionId) return;

        _currentVerseIndex++;
        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (!_isPlaying || sessionId != _playbackSessionId) return;

      if (_currentTrackIndex < _playlist.length - 1) {
        _currentTrackIndex++;
        _currentVerseIndex = 0;
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        if (_isLooping) {
          _currentTrackIndex = 0;
          _currentVerseIndex = 0;
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          _isPlaying = false;
          isPlayingNotifier.value = false;
          _currentVerseIndex = 0;
          _updateTrackState();
          break;
        }
      }
    }
  }
}
