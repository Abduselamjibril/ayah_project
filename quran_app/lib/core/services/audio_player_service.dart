import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../../data/sources/remote/audio_api.dart';
import 'audio_service.dart';
import 'audio_notification_service.dart';

/// Thin wrapper around audioplayers for verse playback.
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._() {
    // Ensure audio routes to device speaker and has proper session settings
    _player.setAudioContext(AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: true,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {},
      ),
    ));
    _player.onPlayerStateChanged.listen((state) {
      isPlaying.value = state == PlayerState.playing;
      if (state == PlayerState.stopped) {
        _hasSource = false;
        AudioNotificationService.instance.cancel();
      }
    });
    _player.onPlayerComplete.listen((_) {
      isPlaying.value = false;
      _hasSource = false;
      AudioNotificationService.instance.cancel();
    });

    // Keep the notification in sync with play/pause changes
    isPlaying.addListener(() {
      final playing = isPlaying.value;
      final label = currentLabel.value;
      if (_hasSource) {
        AudioNotificationService.instance.showNowPlaying(
          title: label,
          reciterName: _recitationName,
          isPlaying: playing,
        );
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final AudioApi _api = AudioApi();
  final AudioService _storage = AudioService.instance;

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<String> currentLabel = ValueNotifier('Select audio');

  int _recitationId = 7; // Default to Mishary Alafasy
  String _recitationName = 'Mishary Alafasy';
  bool _hasSource = false;

  int get recitationId => _recitationId;
  String get recitationName => _recitationName;
  bool get hasSource => _hasSource;

  void setRecitation(int id, {String? name}) {
    _recitationId = id;
    _recitationName = name ?? 'Recitation $id';
  }

  void setRecitationInfo({required int id, required String name}) {
    _recitationId = id;
    _recitationName = name;
  }

  /// Waits until the current audio finishes or is stopped.
  Future<void> waitForCompleteOrStop() async {
    await Future.any([
      _player.onPlayerComplete.first,
      _player.onPlayerStateChanged.firstWhere(
        (state) => state == PlayerState.stopped,
      ),
    ]);
  }

  Future<void> playAyah({
    required int surah,
    required int ayah,
    int? recitationId,
    String? surahName,
    String? reciterName,
  }) async {
    final rid = recitationId ?? _recitationId;
    final reciterLabel = reciterName ?? _recitationName;
    final surahLabel = surahName ?? 'Surah $surah';
    final file = await _api.getAudioByAyah(rid, surah, ayah);
    if (file == null || file.url.isEmpty) {
      throw Exception('Audio not available for reciter $reciterLabel');
    }
    currentLabel.value = '$surahLabel, Ayah $ayah • $reciterLabel';
    _hasSource = true;
    await _player.stop();
    await _player.play(UrlSource(file.url));
    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: reciterLabel,
      isPlaying: true,
    );
  }

  Future<void> pause() async {
    await _player.pause();
    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: _recitationName,
      isPlaying: false,
    );
  }

  Future<void> resume() async {
    if (!_hasSource) throw Exception('No audio loaded');
    await _player.resume();
    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: _recitationName,
      isPlaying: true,
    );
  }

  Future<void> stop() async {
    _hasSource = false;
    isPlaying.value = false;
    await _player.stop();
    await AudioNotificationService.instance.cancel();
  }

  /// Play a verse, preferring a locally downloaded file if present.
  Future<void> playAyahPreferLocal({
    required int surah,
    required int ayah,
    int? recitationId,
    String? surahName,
    String? reciterName,
  }) async {
    final rid = recitationId ?? _recitationId;
    final reciterLabel = reciterName ?? _recitationName;
    final surahLabel = surahName ?? 'Surah $surah';
    await _storage.initialize();
    final local = await _storage.getLocalAyahFile(rid, surah, ayah);
    if (local != null) {
      currentLabel.value = '$surahLabel, Ayah $ayah • $reciterLabel';
      _hasSource = true;
      await _player.stop();
      await _player.play(DeviceFileSource(local.path));
      await AudioNotificationService.instance.showNowPlaying(
        title: currentLabel.value,
        reciterName: reciterLabel,
        isPlaying: true,
      );
      return;
    }
    await playAyah(
      surah: surah,
      ayah: ayah,
      recitationId: rid,
      surahName: surahLabel,
      reciterName: reciterLabel,
    );
  }
}
