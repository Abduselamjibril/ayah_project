import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Handler for background audio playback using audio_service and just_audio.
class QuranAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  QuranAudioHandler() {
    // Broadcast playback state changes to audio_service
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // If you support a queue/playlist, you can pipe effective indices too
    // _player.currentIndexStream...
  }

  VoidCallback? onSkipToNext;
  VoidCallback? onSkipToPrevious;

  /// Transform just_audio events into audio_service PlaybackState
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    if (onSkipToNext != null) {
      onSkipToNext!();
    } else {
      _player.seekToNext();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (onSkipToPrevious != null) {
      onSkipToPrevious!();
    } else {
      _player.seekToPrevious();
    }
  }

  bool get hasNext => _player.hasNext;
  bool get hasPrevious => _player.hasPrevious;

  /// Helper to play a specific media item by URL (file path or remote)
  Future<void> playMediaItem(MediaItem item) async {
    // Update the current media item for lock screen metadata
    mediaItem.add(item);

    // Set the source
    try {
      if (item.id.startsWith('http')) {
        await _player.setUrl(item.id);
      } else {
        await _player.setFilePath(item.id);
      }
      play();
    } catch (e) {
      print("Error loading audio: $e");
    }
  }

  Future<void> setAudioSource(AudioSource source, {bool preload = true}) async {
    await _player.setAudioSource(source, preload: preload);
  }

  Stream<int?> get currentIndexStream => _player.currentIndexStream;
}
