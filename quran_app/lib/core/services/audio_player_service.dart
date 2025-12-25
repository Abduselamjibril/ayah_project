import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/sources/remote/audio_api.dart';
import 'audio_service.dart';
import 'audio_notification_service.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';

/// Thin wrapper around audioplayers for verse playback.
class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._();

  // Cache keys for persistent storage
  static const String _reciterIdKey = 'audio_reciter_id';
  static const String _reciterNameKey = 'audio_reciter_name';

  AudioPlayerService._() {
    // Load cached reciter selection
    _loadReciterFromCache();
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
  final ValueNotifier<int?> downloadingSurah = ValueNotifier<int?>(null);
  final ValueNotifier<String> reciterNameNotifier =
      ValueNotifier('Mishary Alafasy');

  final ValueNotifier<int?> currentSurah = ValueNotifier(null);
  final ValueNotifier<int?> currentAyah = ValueNotifier(null);

  int _recitationId = 7; // Default to Mishary Alafasy
  String _recitationName = 'Mishary Alafasy';
  bool _hasSource = false;
  bool _userSelectedReciter = false;

  // Sequence control
  int _serviceSequenceToken = 0;

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
    _saveReciterToCache(); // Persist selection
  }

  bool get userSelectedReciter => _userSelectedReciter;

  AudioRecitation getSelectedRecitation() =>
      AudioRecitation(id: _recitationId, reciterName: _recitationName);

  /// Load cached reciter selection from SharedPreferences
  Future<void> _loadReciterFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedId = prefs.getInt(_reciterIdKey);
      final cachedName = prefs.getString(_reciterNameKey);

      if (cachedId != null && cachedName != null) {
        _recitationId = cachedId;
        _recitationName = cachedName;
        _userSelectedReciter = true;
        reciterNameNotifier.value = cachedName;
      }
    } catch (e) {
      // If cache loading fails, use defaults
      debugPrint('Failed to load cached reciter: $e');
    }
  }

  /// Save reciter selection to SharedPreferences
  Future<void> _saveReciterToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_reciterIdKey, _recitationId);
      await prefs.setString(_reciterNameKey, _recitationName);
    } catch (e) {
      debugPrint('Failed to save reciter to cache: $e');
    }
  }

  /// Waits until the current audio finishes or is stopped.
  Future<void> waitForCompleteOrStop() async {
    await Future.any([
      _player.onPlayerComplete.first,
      _player.onPlayerStateChanged.firstWhere(
        (state) =>
            state == PlayerState.stopped || state == PlayerState.completed,
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
    currentSurah.value = surah;
    currentAyah.value = ayah;
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
    _serviceSequenceToken++; // invalidates any running sequence
    _hasSource = false;
    currentSurah.value = null;
    currentAyah.value = null;
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
    downloadingSurah.value = surah;
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
      downloadingSurah.value = null;
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

    currentSurah.value = surah;
    currentAyah.value = ayah;
    currentLabel.value = '$surahLabel, Ayah $ayah • $reciterLabel';
    _hasSource = true;

    await _player.stop();

    if (local != null) {
      await _player.play(DeviceFileSource(local.path));
    } else {
      // Fallback if local play requested but somehow file missing
      final file = await _api.getAudioByAyah(rid, surah, ayah);
      if (file != null && file.url.isNotEmpty) {
        await _player.play(UrlSource(file.url));
      } else {
        return; // failed
      }
    }

    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: reciterLabel,
      isPlaying: true,
    );
  }

  /// Plays a sequence of verses for the given Surah, starting from [startAyah].
  /// This manages the loop internally.
  Future<void> playSurahSequence({
    required int surah,
    required String surahLabel,
    required String reciterName,
    int startAyah = 1,
  }) async {
    // Invalidate any old sequence
    final token = ++_serviceSequenceToken;

    await _player.stop();
    final totalAyat = getVerseCount(surah);

    for (var ayah = startAyah; ayah <= totalAyat; ayah++) {
      // Check for cancellation
      if (token != _serviceSequenceToken) break;

      try {
        // We assume files are already downloaded or we rely on playAyahPreferLocal fallback.
        // For smoother experience, the caller should ensure downloadSurahIfNeeded called first.
        await playAyahPreferLocal(
          surah: surah,
          ayah: ayah,
          surahName: surahLabel,
          reciterName: reciterName,
        );
      } catch (e) {
        // Error playing this ayah, stop sequence
        break;
      }

      await waitForCompleteOrStop();

      // If stopped explicitly by user, we stop loop
      if (token != _serviceSequenceToken || !_hasSource) {
        break;
      }
    }

    // Clear state if finished naturally
    if (token == _serviceSequenceToken) {
      currentSurah.value = null;
      currentAyah.value = null;
      _hasSource = false;
      isPlaying.value = false;
      await AudioNotificationService.instance.cancel();
    }
  }
}
