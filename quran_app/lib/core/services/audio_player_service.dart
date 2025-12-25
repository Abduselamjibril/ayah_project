import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import '../../data/sources/remote/audio_api.dart';
import 'audio_service.dart';
import 'audio_notification_service.dart';

/// Thin wrapper around audioplayers for verse playback.
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._();
  AudioPlayerService._() {
    // Ensure audio routes to device speaker and has proper session settings
    _player.setAudioContext(AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        audioFocus: AndroidAudioFocus.gain,
        stayAwake: true,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: const {},
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
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
  final ValueNotifier<String> reciterNameNotifier =
      ValueNotifier('Mishary Alafasy');

  int _recitationId = 7; // Default to Mishary Alafasy
  String _recitationName = 'Mishary Alafasy';
  bool _hasSource = false;
  bool _userSelectedReciter = false;

  int get recitationId => _recitationId;
  String get recitationName => _recitationName;
  bool get hasSource => _hasSource;

  void setRecitation(int id, {String? name}) {
    _recitationId = id;
    _recitationName = name ?? 'Recitation $id';
    _userSelectedReciter = true;
    reciterNameNotifier.value = _recitationName;
  }

  void setRecitationInfo({required int id, required String name}) {
    _recitationId = id;
    _recitationName = name;
    _userSelectedReciter = true;
    reciterNameNotifier.value = _recitationName;
  }

  bool get userSelectedReciter => _userSelectedReciter;

  AudioRecitation getSelectedRecitation() =>
      AudioRecitation(id: _recitationId, reciterName: _recitationName);

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

  /// Play a verse ensuring the surah is downloaded first. This will prompt for
  /// reciter selection only if the user hasn't already chosen one (or if
  /// `forceReciter` is true). UI feedback uses the `isDownloading`/`downloadProgress` notifiers.
  Future<void> playAyahWithDownload(BuildContext context, int surah, int ayah,
      {bool forceReciter = false}) async {
    AudioRecitation? recitation;
    if (!forceReciter && _userSelectedReciter) {
      recitation = getSelectedRecitation();
    } else {
      await _storage.initialize();
      final recitations = await _storage.getAvailableRecitations();
      if (!context.mounted) return;
      final chosen = await showModalBottomSheet<AudioRecitation>(
        context: context,
        builder: (context) {
          final maxHeight = MediaQuery.of(context).size.height * 0.7 > 520.0
              ? 520.0
              : MediaQuery.of(context).size.height * 0.7;
          return SafeArea(
            child: SizedBox(
              height: maxHeight,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('Choose Reciter',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: recitations.length,
                      itemBuilder: (context, index) {
                        final r = recitations[index];
                        return ListTile(
                          title: Text(r.reciterName),
                          subtitle: r.style != null ? Text(r.style!) : null,
                          onTap: () => Navigator.pop(context, r),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (chosen != null) {
        recitation = chosen;
        setRecitationInfo(id: chosen.id, name: chosen.reciterName);
      }
    }
    if (recitation == null) return;

    await _storage.initialize();
    final local = await _storage.getLocalAyahFile(recitation.id, surah, ayah);
    if (local == null) {
      final ok = await downloadSurahIfNeeded(recitation, surah);
      if (!ok) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not download audio')));
        return;
      }
    }
    await playAyahPreferLocal(
        surah: surah,
        ayah: ayah,
        recitationId: recitation.id,
        reciterName: recitation.reciterName);
  }

  /// Ensure surah is downloaded; starts download as early as possible for faster feedback.
  Future<bool> downloadSurahIfNeeded(
      AudioRecitation recitation, int surah) async {
    // Set UI state immediately for responsiveness
    isDownloading.value = true;
    downloadProgress.value = 0.0;
    try {
      // Start initialization and download status check in parallel
      final initFuture = _storage.initialize();
      final isDownloadedFuture =
          _storage.isSurahDownloaded(recitation.id, surah);
      await initFuture;
      final already = await isDownloadedFuture;
      if (already) return true;
      // Start download as soon as possible
      final ok = await _storage.downloadSurahAudio(
        recitation,
        surah,
        onProgress: (p) {
          downloadProgress.value = p;
          // Update the system notification progress so the user sees download progress
          try {
            AudioNotificationService.instance.showDownloadProgress(
              title: 'Downloading Surah ${surah.toString().padLeft(3, '0')}',
              reciterName: _recitationName,
              progress: p,
            );
          } catch (_) {}
        },
      );
      return ok;
    } catch (_) {
      return false;
    } finally {
      // Clear download UI state and cancel download notification (if any)
      isDownloading.value = false;
      downloadProgress.value = 0.0;
      try {
        await AudioNotificationService.instance.cancel();
      } catch (_) {}
    }
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
