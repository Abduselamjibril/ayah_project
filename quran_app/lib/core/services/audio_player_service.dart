import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/data/models/audio_segment.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Only clear _hasSource on stop if we're not in the middle of a sequence
      if (state == PlayerState.stopped && !_inSequence) {
        _hasSource = false;
        AudioNotificationService.instance.cancel();
      }
    });
    // Note: We don't set _hasSource = false on completion here because
    // that would break sequence playback. The playSurahSequence method
    // handles cleanup properly when the entire sequence completes.

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
  bool _inSequence = false; // Track if we're currently playing a sequence

  // Segmented audio support
  List<AudioSegment>? _currentSegments; // Cache segments for current Surah
  StreamSubscription<Duration>?
      _positionSubscription; // Listen to playback position
  int? _currentPlayingSurah; // Track which Surah audio is loaded

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

  /// Return the cached recitation or prompt the user to choose one.
  Future<AudioRecitation?> _selectOrCachedReciter(BuildContext context,
      {bool forceReciter = false}) async {
    if (!forceReciter && _userSelectedReciter) {
      return getSelectedRecitation();
    }

    await _storage.initialize();
    final recitations = await _storage.getAvailableRecitations();
    if (!context.mounted) return null;

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
      setRecitationInfo(id: chosen.id, name: chosen.reciterName);
    }
    return chosen;
  }

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

  /// Play a single ayah using segmented audio.
  /// Note: This will play just the specific ayah by seeking to its timestamp.
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

    // Use the playAyahPreferLocal which now only uses segmented audio
    await playAyahPreferLocal(
      surah: surah,
      ayah: ayah,
      recitationId: rid,
      surahName: surahLabel,
      reciterName: reciterLabel,
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
    _inSequence = false; // Clear sequence flag
    _hasSource = false;
    currentSurah.value = null;
    currentAyah.value = null;
    isPlaying.value = false;
    await _stopPositionMonitoring(); // Stop monitoring
    _currentSegments = null; // Clear segments
    _currentPlayingSurah = null;
    await _player.stop();
    await AudioNotificationService.instance.cancel();
  }

  /// Play a verse ensuring the surah is downloaded first. This will prompt for
  /// reciter selection only if the user hasn't already chosen one (or if
  /// `forceReciter` is true). UI feedback uses the `isDownloading`/`downloadProgress` notifiers.
  Future<void> playAyahWithDownload(BuildContext context, int surah, int ayah,
      {bool forceReciter = false}) async {
    final recitation =
        await _selectOrCachedReciter(context, forceReciter: forceReciter);
    if (recitation == null) return;

    await _storage.initialize();

    // Check if Surah is downloaded (segmented format)
    final isDownloaded = await _storage.isSurahDownloaded(recitation.id, surah);
    if (!isDownloaded) {
      final ok = await downloadSurahIfNeeded(recitation, surah);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not download audio')),
          );
        }
        return;
      }
    }

    await playAyahPreferLocal(
        surah: surah,
        ayah: ayah,
        recitationId: recitation.id,
        reciterName: recitation.reciterName);
  }

  /// Play a surah sequence ensuring reciter selection and download first.
  /// This will play from [startAyah] to the end of the surah continuously.
  /// Prompts for reciter selection if needed, downloads the surah if not cached,
  /// then plays the sequence.
  Future<void> playSurahSequenceWithDownload(
    BuildContext context,
    int surah,
    int startAyah, {
    bool forceReciter = false,
  }) async {
    final recitation =
        await _selectOrCachedReciter(context, forceReciter: forceReciter);
    if (recitation == null) return;

    await _storage.initialize();

    // Check if surah is downloaded, if not download it
    final hasLocal = await _storage.isSurahDownloaded(recitation.id, surah);
    if (!hasLocal) {
      final ok = await downloadSurahIfNeeded(recitation, surah);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Could not download audio for Surah $surah')),
          );
        }
        return;
      }
    }

    // Play the surah sequence from startAyah to the end
    await playSurahSequence(
      surah: surah,
      startAyah: startAyah,
      surahLabel: getSurahName(surah),
      reciterName: recitation.reciterName,
    );
  }

  /// Ensure surah is downloaded; starts download as early as possible for faster feedback.
  Future<bool> downloadSurahIfNeeded(AudioRecitation recitation, int surah,
      {String? notificationTitle}) async {
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
              title: notificationTitle ??
                  'Downloading Surah ${surah.toString().padLeft(3, '0')}',
              reciterName: recitation.reciterName,
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

  /// Play an ayah using locally downloaded segmented audio.
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

    // Load segmented audio
    final surahFile = await _storage.getLocalSurahFile(rid, surah);
    final segments = await _storage.getLocalSegments(rid, surah);

    if (surahFile == null || segments == null || segments.isEmpty) {
      throw Exception('Surah $surah not downloaded. Please download it first.');
    }

    currentSurah.value = surah;
    currentAyah.value = ayah;
    currentLabel.value = '$surahLabel, Ayah $ayah • $reciterLabel';

    await _player.stop();

    // Use segmented audio format
    _currentSegments = segments;
    _currentPlayingSurah = surah;

    await _player.setSource(DeviceFileSource(surahFile.path));

    // Find the segment for this ayah and seek to it
    final segment = segments.firstWhere(
      (seg) => seg.ayahNumber == ayah,
      orElse: () => segments.first,
    );

    await _player.seek(Duration(milliseconds: segment.timestampFrom));
    await _player.resume();

    // Start monitoring position for ayah tracking
    _startPositionMonitoring();

    // Set _hasSource AFTER playing to prevent the stop() call above from clearing it
    _hasSource = true;

    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: reciterLabel,
      isPlaying: true,
    );
  }

  /// Plays a sequence of ayahs for the given Surah using seamless segmented audio.
  /// If [endAyah] is provided, it plays until that ayah finishes, otherwise plays to end of Surah.
  Future<void> playSurahSequence({
    required int surah,
    required String surahLabel,
    required String reciterName,
    int startAyah = 1,
    int? endAyah,
  }) async {
    // Invalidate any old sequence
    final token = ++_serviceSequenceToken;
    _inSequence = true;

    await _player.stop();
    await _storage.initialize();

    // Load segmented audio
    final surahFile = await _storage.getLocalSurahFile(_recitationId, surah);
    final segments = await _storage.getLocalSegments(_recitationId, surah);

    if (surahFile == null || segments == null || segments.isEmpty) {
      throw Exception('Surah $surah not downloaded. Please download it first.');
    }

    // Use segmented audio format - seamless playback!
    _currentSegments = segments;
    _currentPlayingSurah = surah;
    currentSurah.value = surah;
    currentAyah.value = startAyah;
    currentLabel.value = '$surahLabel, Ayah $startAyah • $reciterName';
    _hasSource = true;

    await _player.setSource(DeviceFileSource(surahFile.path));

    // Find the segment for startAyah and seek to it
    final startSegment = segments.firstWhere(
      (seg) => seg.ayahNumber == startAyah,
      orElse: () => segments.first,
    );

    // Calculate duration to play if we have an end point
    // Note: This is tricky with audioplayers as we can't set an end point easily.
    // We rely on _startPositionMonitoring to stop playback if we exceed endAyah.

    await _player.seek(Duration(milliseconds: startSegment.timestampFrom));
    await _player.resume();

    // Start monitoring position to update current ayah
    // We pass endAyah to monitoring if needed?
    // Actually, _startPositionMonitoring just updates currentAyah.
    // We need to check completion logic separately.
    _startPositionMonitoring();

    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: reciterName,
      isPlaying: true,
    );

    // Custom wait loop that checks for endAyah
    if (endAyah != null) {
      await _waitForAyahCompletion(endAyah, token);
    } else {
      await waitForCompleteOrStop();
    }

    // Clear state if finished naturally
    if (token == _serviceSequenceToken && _inSequence) {
      _inSequence = false;
      // Only clear if we are NOT part of a larger range sequence calling this
      // But wait, playRangeSequence calls this.
      // If we clear here, playRangeSequence loop might break?
      // playRangeSequence handles its own loop break checks.

      // If we were called directly (single surah), clear.
      // If called from playRangeSequence, we probably want to just return.
      // But simple fix: playRangeSequence will call stop() or setup next surah effectively.

      // Actually, playRangeSequence waits for this future to complete.
      // If we stop here, we clear state.

      // Let's make playSurahSequence NOT clear state automatically if it's just a helper?
      // Or playRangeSequence should be the one managing state?

      // Use a flag or check? existing logic cleared it.
      // We will remove the auto-clear here and let the caller handle it or
      // only clear if it's the "last" action.
      // But we don't know if it's the last action.

      // Safer: Reset flags but let playRangeSequence continue.
      // Actually, if we clear `isPlaying`, UI might flicker.

      // Restoring original clear logic but only if NOT part of a range?
      // Actually, playRangeSequence runs `playSurahSequence` then loops.
      // If `playSurahSequence` clears `isPlaying=false`, the UI shows pause between surahs.
      // That's acceptable.

      await _stopPositionMonitoring();
      if (endAyah == null) {
        // Full surah finish - natural clear
        // But playRangeSequence needs to continue.
      }
    }
  }

  /// Helper to wait until playback reaches the end of endAyah
  Future<void> _waitForAyahCompletion(int endAyah, int token) async {
    final completer = Completer<void>();

    // We need to check segments to know when the endAyah finishes
    // or just monitor currentAyah change.

    // Simple approach: Check periodically if currentAyah > endAyah or if completed
    Timer? checkTimer;
    checkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (token != _serviceSequenceToken || !_hasSource || !isPlaying.value) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      if (_player.state == PlayerState.completed) {
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
        return;
      }

      // Check if we passed the end ayah
      // This relies on _currentAyah being updated by position monitor
      final current = currentAyah.value;
      if (current != null && current > endAyah) {
        // We moved past the end ayah
        _player.pause(); // Stop playback
        timer.cancel();
        if (!completer.isCompleted) completer.complete();
      }
    });

    await completer.future;
    checkTimer?.cancel();
  }

  Future<void> _completionReset() async {
    _inSequence = false;
    await _stopPositionMonitoring();
    currentSurah.value = null;
    currentAyah.value = null;
    currentLabel.value = '';
    _hasSource = false;
    isPlaying.value = false;
    _currentSegments = null;
    _currentPlayingSurah = null;
    await AudioNotificationService.instance.cancel();
  }

  /// Internal helper to play surah sequence without changing global token
  Future<void> _playSurahSequenceInternal({
    required int token,
    required int surah,
    required String surahLabel,
    required String reciterName,
    int startAyah = 1,
    int? endAyah,
  }) async {
    await _player.stop();
    await _storage.initialize();

    // Load segmented audio
    final surahFile = await _storage.getLocalSurahFile(_recitationId, surah);
    final segments = await _storage.getLocalSegments(_recitationId, surah);

    if (surahFile == null || segments == null || segments.isEmpty) {
      throw Exception('Surah $surah not downloaded. Please download it first.');
    }

    // Use segmented audio format - seamless playback!
    _currentSegments = segments;
    _currentPlayingSurah = surah;
    currentSurah.value = surah;
    currentAyah.value = startAyah;
    currentLabel.value = '$surahLabel, Ayah $startAyah • $reciterName';
    _hasSource = true;

    await _player.setSource(DeviceFileSource(surahFile.path));

    // Find the segment for startAyah and seek to it
    final startSegment = segments.firstWhere(
      (seg) => seg.ayahNumber == startAyah,
      orElse: () => segments.first,
    );

    await _player.seek(Duration(milliseconds: startSegment.timestampFrom));
    await _player.resume();

    // Start monitoring position to update current ayah
    _startPositionMonitoring();

    await AudioNotificationService.instance.showNowPlaying(
      title: currentLabel.value,
      reciterName: reciterName,
      isPlaying: true,
    );

    // Custom wait loop that checks for endAyah
    if (endAyah != null) {
      await _waitForAyahCompletion(endAyah, token);
    } else {
      await waitForCompleteOrStop();
    }

    await _stopPositionMonitoring();
  }

  /// Plays a custom range of verses from [startSurah]:[startAyah] to [endSurah]:[endAyah].
  /// This supports both single-surah and cross-surah playback.
  Future<void> playRangeSequence({
    required int startSurah,
    required int startAyah,
    required int endSurah,
    required int endAyah,
    required String reciterName,
  }) async {
    // Invalidate any old sequence
    final token = ++_serviceSequenceToken;
    _inSequence = true;

    await _player.stop();

    // Play through all surahs in the range
    for (var surah = startSurah; surah <= endSurah; surah++) {
      if (token != _serviceSequenceToken) break;

      final totalAyat = getVerseCount(surah);
      final firstAyah = (surah == startSurah) ? startAyah : 1;
      final lastAyah = (surah == endSurah) ? endAyah : totalAyat;

      // Play the chunk for this surah
      final targetEndAyah = (lastAyah == totalAyat) ? null : lastAyah;

      // Use internal method so we don't reset the token
      await _playSurahSequenceInternal(
          token: token,
          surah: surah,
          surahLabel: getSurahName(surah),
          reciterName: reciterName,
          startAyah: firstAyah,
          endAyah: targetEndAyah);

      if (token != _serviceSequenceToken) break;
    }

    // Clear state if finished naturally
    if (token == _serviceSequenceToken) {
      await _completionReset();
    }
  }

  /// Play a custom range with download support.
  /// This validates the range, downloads all required surahs, then plays the range.
  Future<void> playRangeSequenceWithDownload(
    BuildContext context, {
    required int startSurah,
    required int startAyah,
    required int endSurah,
    required int endAyah,
    bool forceReciter = false,
  }) async {
    // Validate range
    final startPage = getPageNumber(startSurah, startAyah);
    final endPage = getPageNumber(endSurah, endAyah);

    if (startPage > endPage ||
        (startSurah == endSurah && startAyah > endAyah)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid range: end point must be after start point'),
          ),
        );
      }
      return;
    }

    final recitation =
        await _selectOrCachedReciter(context, forceReciter: forceReciter);
    if (recitation == null) return;

    await _storage.initialize();

    // Download all required surahs
    for (var surah = startSurah; surah <= endSurah; surah++) {
      final hasLocal = await _storage.isSurahDownloaded(recitation.id, surah);
      if (!hasLocal) {
        final surahName = getSurahName(surah);
        final ok = await downloadSurahIfNeeded(
          recitation,
          surah,
          notificationTitle: 'Downloading $surahName',
        );
        if (!ok) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not download audio for $surahName'),
              ),
            );
          }
          return;
        }
      }
    }

    // Play the range
    await playRangeSequence(
      startSurah: startSurah,
      startAyah: startAyah,
      endSurah: endSurah,
      endAyah: endAyah,
      reciterName: recitation.reciterName,
    );
  }

  /// Play the next surah in sequence (auto-downloads if needed)
  Future<void> playNextSurah() async {
    final currentSurahNum = currentSurah.value;
    if (currentSurahNum == null || currentSurahNum >= 114) return;

    // Stop current playback immediately so we don't play while downloading/buffering
    await stop();

    final nextSurah = currentSurahNum + 1;

    // Auto-download if not available
    final isDownloaded =
        await _storage.isSurahDownloaded(_recitationId, nextSurah);
    if (!isDownloaded) {
      final recitation = AudioRecitation(
        id: _recitationId,
        reciterName: _recitationName,
      );
      final ok = await downloadSurahIfNeeded(recitation, nextSurah);
      if (!ok) return; // Download failed
    }

    final surahName = getSurahName(nextSurah);

    await playSurahSequence(
      surah: nextSurah,
      startAyah: 1,
      surahLabel: surahName,
      reciterName: _recitationName,
    );
  }

  /// Play the previous surah in sequence (auto-downloads if needed)
  Future<void> playPreviousSurah() async {
    final currentSurahNum = currentSurah.value;
    if (currentSurahNum == null || currentSurahNum <= 1) return;

    // Stop current playback immediately
    await stop();

    final prevSurah = currentSurahNum - 1;

    // Auto-download if not available
    final isDownloaded =
        await _storage.isSurahDownloaded(_recitationId, prevSurah);
    if (!isDownloaded) {
      final recitation = AudioRecitation(
        id: _recitationId,
        reciterName: _recitationName,
      );
      final ok = await downloadSurahIfNeeded(recitation, prevSurah);
      if (!ok) return; // Download failed
    }

    final surahName = getSurahName(prevSurah);

    await playSurahSequence(
      surah: prevSurah,
      startAyah: 1,
      surahLabel: surahName,
      reciterName: _recitationName,
    );
  }

  /// Start monitoring playback position to track current ayah
  void _startPositionMonitoring() {
    _stopPositionMonitoring(); // Cancel any existing subscription

    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (_currentSegments != null && _currentSegments!.isNotEmpty) {
        final positionMs = position.inMilliseconds;

        // Find which ayah we're currently playing
        for (final segment in _currentSegments!) {
          if (segment.containsPosition(positionMs)) {
            final newAyah = segment.ayahNumber;
            if (newAyah != currentAyah.value) {
              currentAyah.value = newAyah;
              // Update notification with current ayah
              if (_hasSource && _currentPlayingSurah != null) {
                final surahName = getSurahName(_currentPlayingSurah!);
                currentLabel.value =
                    '$surahName, Ayah $newAyah • $_recitationName';
                AudioNotificationService.instance.showNowPlaying(
                  title: currentLabel.value,
                  reciterName: _recitationName,
                  isPlaying: isPlaying.value,
                );
              }
            }
            break;
          }
        }
      }
    });
  }

  /// Stop monitoring playback position
  Future<void> _stopPositionMonitoring() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }
}
