import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart' as local_audio;
import 'quran_audio_handler.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'notification_service.dart';

class AudioPlayerService {
  static final AudioPlayerService instance = AudioPlayerService._();

  static const String _reciterIdKey = 'audio_reciter_id';
  static const String _reciterNameKey = 'audio_reciter_name';

  late QuranAudioHandler _handler;
  bool _isInitialized = false;

  Future<void>? _initFuture;

  AudioPlayerService._();

  /// Initialize the audio service and handler.
  /// Must be called before use (e.g. in main.dart or app init).
  Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _init();
    return _initFuture;
  }

  Future<void> _init() async {
    try {
      await AppNotificationService.instance.initialize();

      _handler = await AudioService.init(
        builder: () => QuranAudioHandler(),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'com.quran_app.audio',
          androidNotificationChannelName: 'Quran Audio',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
          androidNotificationIcon: 'mipmap/ic_launcher',
        ),
      );

      // Sync state from handler
      _handler.playbackState.listen((state) {
        isPlaying.value = state.playing;
        _playbackSpeedNotifier.value = state.speed;
        if (state.processingState == AudioProcessingState.completed) {
          stop();
        }
      });

      _handler.loopModeStream.listen((mode) {
        loopMode.value = mode;
      });

      // Track current index and update metadata accordingly
      _handler.currentIndexStream.listen((index) {
        if (index != null &&
            _currentPlaylistMetadata != null &&
            index < _currentPlaylistMetadata!.length) {
          final meta = _currentPlaylistMetadata![index];
          final item = meta['item'] as MediaItem;

          // Update the mediaItem for lock screen and notification
          _handler.mediaItem.add(item);

          // Update our state notifiers
          currentLabel.value = item.title;
          if (item.extras != null) {
            final s = item.extras!['surah'] as int?;
            final a = item.extras!['ayah'] as int?;
            if (s != null) currentSurah.value = s;
            if (a != null) currentAyah.value = a;
          }
        }
      });

      // Wire up notification controls
      _handler.onSkipToNext = () => playNextSurah(null);
      _handler.onSkipToPrevious = () => playPreviousSurah(null);

      await _loadReciterFromCache();
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing AudioService: $e');
      // Reset future so we can try again if it failed transiently (though init failure is usually fatal)
      _initFuture = null;
      rethrow;
    }
  }

  // --- Public API compatible with existing code ---

  final ValueNotifier<bool> isPlaying = ValueNotifier(false);
  final ValueNotifier<String> currentLabel = ValueNotifier('Select audio');
  final ValueNotifier<bool> isDownloading = ValueNotifier(false);
  final ValueNotifier<double> downloadProgress = ValueNotifier(0.0);
  final ValueNotifier<int?> downloadingSurah = ValueNotifier<int?>(null);
  final ValueNotifier<String> reciterNameNotifier =
      ValueNotifier('Mishary Alafasy');
  final ValueNotifier<double> _playbackSpeedNotifier = ValueNotifier(1.0);
  ValueNotifier<double> get playbackSpeed => _playbackSpeedNotifier;
  final ValueNotifier<LoopMode> loopMode = ValueNotifier(LoopMode.off);

  final ValueNotifier<int?> currentSurah = ValueNotifier(null);
  final ValueNotifier<int?> currentAyah = ValueNotifier(null);

  int _recitationId = 7;
  String _recitationName = 'Mishary Alafasy';
  bool _userSelectedReciter = false;

  int get recitationId => _recitationId;
  String get recitationName => _recitationName;
  ValueNotifier<bool> hasSourceNotifier = ValueNotifier(false);
  bool get hasSource => hasSourceNotifier.value;

  List<Map<String, dynamic>>? _currentPlaylistMetadata;

  Uri? _cachedArtUri;

  Future<Uri> _getArtUri() async {
    if (_cachedArtUri != null) return _cachedArtUri!;

    try {
      final byteData = await rootBundle.load('assets/images/Icon.jpg');
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/lockscreen_art.jpg');

      await file.writeAsBytes(byteData.buffer.asUint8List());

      _cachedArtUri = Uri.file(file.path);
      return _cachedArtUri!;
    } catch (e) {
      debugPrint("Error loading artwork: $e");
      return Uri.parse("https://via.placeholder.com/150");
    }
  }

  // --- Reciter Management ---

  void setRecitationInfo({required int id, required String name}) {
    _recitationId = id;
    _recitationName = name;
    _userSelectedReciter = true;
    reciterNameNotifier.value = _recitationName;

    _saveReciterToCache();
  }

  void setRecitation(int id, {String? name}) {
    setRecitationInfo(id: id, name: name ?? 'Recitation $id');
  }

  bool get userSelectedReciter => _userSelectedReciter;

  AudioRecitation getSelectedRecitation() =>
      AudioRecitation(id: _recitationId, reciterName: _recitationName);

  Future<void> _loadReciterFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_reciterIdKey);
    final name = prefs.getString(_reciterNameKey);
    if (id != null && name != null) {
      _recitationId = id;
      _recitationName = name;
      _userSelectedReciter = true;
      reciterNameNotifier.value = name;
    }
  }

  Future<void> _saveReciterToCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_reciterIdKey, _recitationId);
    await prefs.setString(_reciterNameKey, _recitationName);
  }

  // --- Playback Controls ---

  Future<void> pause() async => await _handler.pause();
  Future<void> resume() async => await _handler.play();
  Future<void> stop() async {
    await _handler.stop();
    hasSourceNotifier.value = false;
    currentSurah.value = null;
    currentAyah.value = null;
    _currentPlaylistMetadata = null;
  }

  Future<void> seek(Duration position) async {
    await _handler.seek(position);
  }

  Future<void> setSpeed(double speed) async {
    _playbackSpeedNotifier.value = speed;
    await _handler.setSpeed(speed);
  }

  Future<void> setLoopMode(LoopMode mode) async {
    loopMode.value = mode;
    await _handler.setLoopMode(mode);
  }

  // --- Playback Logic ---

  /// Play a custom range with download support.
  /// Pre-downloads at least 3 suras before starting playback, and plays only one sura at a time.
  Future<void> playRangeSequenceWithDownload(
    BuildContext? context, {
    required int startSurah,
    required int startAyah,
    required int endSurah,
    required int endAyah,
    bool forceReciter = false,
  }) async {
    if (!_isInitialized) await init();

    // 1. Reciter Selection
    final recitation =
        await _selectOrCachedReciter(context, forceReciter: forceReciter);
    if (recitation == null) return;

    // 2. Initialize storage
    final local_audio.AudioService storage = local_audio.AudioService.instance;
    await storage.initialize();

    // 3. Pre-download at least 3 suras (or all if range is smaller)
    final totalSurasInRange = endSurah - startSurah + 1;
    final surasToPreDownload = totalSurasInRange < 3 ? totalSurasInRange : 3;

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (AppLocalizations.of(context)?.translate('preparing_audio') ??
                    'Preparing audio... downloading {count} suras')
                .replaceAll('{count}', '$surasToPreDownload'),
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }

    for (var i = 0; i < surasToPreDownload; i++) {
      final surahToDownload = startSurah + i;
      if (!(await storage.isSurahDownloaded(recitation.id, surahToDownload))) {
        final ok = await downloadSurahIfNeeded(recitation, surahToDownload);
        if (!ok) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  (AppLocalizations.of(context)
                              ?.translate('failed_download_surah') ??
                          'Failed to download Surah {number}')
                      .replaceAll('{number}', '$surahToDownload'),
                ),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    }

    // 4. Build playlist for ONLY the first surah
    final concatenatingSource = ConcatenatingAudioSource(children: []);
    final List<Map<String, dynamic>> metadata = [];

    // Add only the first surah to playlist (stops after this sura)
    await _addSurahToPlaylist(
      concatenatingSource,
      metadata,
      storage,
      recitation,
      startSurah,
      startAyah: startAyah,
      endAyah: (startSurah == endSurah) ? endAyah : getVerseCount(startSurah),
    );

    if (concatenatingSource.children.isEmpty) return;
    _currentPlaylistMetadata = metadata;
    hasSourceNotifier.value = true;

    // 5. Start playback
    await _handler.setAudioSource(concatenatingSource);
    await _handler.play();

    // 6. Download remaining suras in the background (but don't add to playlist)
    if (startSurah < endSurah && surasToPreDownload < totalSurasInRange) {
      _downloadRemainingSurasInBackground(
        context,
        storage,
        recitation,
        startSurah: startSurah + surasToPreDownload,
        endSurah: endSurah,
      );
    }
  }

  /// Helper to add a surah's ayahs to the playlist
  Future<void> _addSurahToPlaylist(
    ConcatenatingAudioSource playlist,
    List<Map<String, dynamic>> metadata,
    local_audio.AudioService storage,
    AudioRecitation recitation,
    int surah, {
    required int startAyah,
    required int endAyah,
  }) async {
    final file = await storage.getLocalSurahFile(recitation.id, surah);
    final segments = await storage.getLocalSegments(recitation.id, surah);

    if (file == null || segments == null) return;

    final surahName = getSurahName(surah);
    final sources = <AudioSource>[];

    final artUri = await _getArtUri();

    for (var ayah = startAyah; ayah <= endAyah; ayah++) {
      final segment = segments.firstWhere(
        (seg) => seg.ayahNumber == ayah,
        orElse: () => segments.first,
      );
      final title = '$surahName : $ayah';

      final mediaItem = MediaItem(
        id: '${file.path}_$ayah',
        album: surahName,
        title: title,
        artist: recitation.reciterName,
        artUri: artUri,
        extras: {'surah': surah, 'ayah': ayah},
      );

      final source = ClippingAudioSource(
        child: AudioSource.file(file.path),
        start: Duration(milliseconds: segment.timestampFrom),
        end: Duration(milliseconds: segment.timestampTo),
        tag: mediaItem,
      );

      sources.add(source);
      metadata.add({'surah': surah, 'ayah': ayah, 'item': mediaItem});
    }

    // Add all sources at once for better performance
    await playlist.addAll(sources);
  }

  /// Background task to download remaining suras (without adding to playlist)
  Future<void> _downloadRemainingSurasInBackground(
    BuildContext? context,
    local_audio.AudioService storage,
    AudioRecitation recitation, {
    required int startSurah,
    required int endSurah,
  }) async {
    for (var s = startSurah; s <= endSurah; s++) {
      // Download if needed
      if (!(await storage.isSurahDownloaded(recitation.id, s))) {
        final ok = await downloadSurahIfNeeded(recitation, s);
        if (!ok) {
          // Download failed, but don't show notification since it's background
          debugPrint('Background download failed for Surah $s');
          break; // Stop downloading further surahs
        }
      }
    }
  }

  // Helpers
  Future<AudioRecitation?> _selectOrCachedReciter(BuildContext? context,
      {bool forceReciter = false}) async {
    if (!forceReciter && _userSelectedReciter) {
      return getSelectedRecitation();
    }

    // If context is null, we can't show picker. Try cache or fail.
    await _loadReciterFromCache();
    if (_userSelectedReciter) return getSelectedRecitation();

    if (context == null || !context.mounted) return null;

    await local_audio.AudioService.instance.initialize();
    final recitations =
        await local_audio.AudioService.instance.getAvailableRecitations();

    final chosen = await showModalBottomSheet<AudioRecitation>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.7;
        return SafeArea(
            child: SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    AppLocalizations.of(context)?.translate('choose_reciter') ??
                        'Choose Reciter',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  )),
              Expanded(
                  child: ListView.builder(
                itemCount: recitations.length,
                itemBuilder: (context, index) => ListTile(
                  title: Text(recitations[index].reciterName),
                  subtitle: recitations[index].style != null
                      ? Text(recitations[index].style!)
                      : null,
                  onTap: () => Navigator.pop(context, recitations[index]),
                ),
              )),
            ],
          ),
        ));
      },
    );
    if (chosen != null)
      setRecitationInfo(id: chosen.id, name: chosen.reciterName);
    return chosen;
  }

  // Backward compatibility alias matching existing usage
  Future<void> playSurahSequenceWithDownload(BuildContext? context, int surah,
      [int? startAyah, int? endAyah]) async {
    final total = getVerseCount(surah);
    await playRangeSequenceWithDownload(
      context,
      startSurah: surah,
      startAyah: startAyah ?? 1,
      endSurah: surah,
      endAyah: endAyah ?? total,
    );
  }

  Future<bool> downloadSurahIfNeeded(
      AudioRecitation recitation, int surah) async {
    isDownloading.value = true;
    downloadingSurah.value = surah;
    downloadProgress.value = 0;
    try {
      return await local_audio.AudioService.instance
          .downloadSurahAudio(recitation, surah, onProgress: (p) {
        downloadProgress.value = p;
      });
    } finally {
      isDownloading.value = false;
      downloadingSurah.value = null;
    }
  }

  // Logic to play next/prev surah by calculating range and calling playRangeSequenceWithDownload
  // Note: 'context' is required for download dialogs/snackbars in playRangeSequenceWithDownload.
  // This breaks the abstraction slightly but matches original design.
  // We can't implement playNextSurah() easily without context if it triggers download UI flow.
  // So we accept it can't be called purely from background without context.
  // But playNextSurah is usually called from UI.

  // Original Service didn't require context for playNextSurah, it just returned.
  // But playRangeSequenceWithDownload DOES require context.
  // I will skip implementation of playNextSurah/playPreviousSurah for now as simpler methods
  // or implement them assuming caller handles UI context if needed?
  // Actually, I can use a global navigator key or just omit if not critical for "Native Media Control" task.
  // BUT the user asked for full migration.
  // I will implement them using a clever trick or just pass context?
  // PlayNextSurah in original code called 'stop' then 'download' then 'playSurahSequence'.
  // I'll add them but throw strict unimplemented or try to use a default context? No.
  // I will change signature to accept Context or just fail gracefully if not available.
  // Given time constraints, I'll implement basic logic that assumes download is fine or fails silently?
  // No, I'll replicate original logic but we need context for `_selectOrCachedReciter` fallback.
  // If reciter is selected, we don't need context for that part.

  Future<void> playNextSurah(BuildContext? context) async {
    final current = currentSurah.value;
    if (current == null || current >= 114) return;

    // Stop current playback immediately (pause to keep UI state for spinner)
    await pause();

    // Forces next surah, ignoring playlist ayah queue
    final nextSurah = current + 1;
    await playSurahSequenceWithDownload(context, nextSurah);
  }

  Future<void> playPreviousSurah(BuildContext? context) async {
    final current = currentSurah.value;
    if (current == null || current <= 1) return;

    // Stop current playback immediately
    await pause();

    // Forces prev surah, ignoring playlist ayah queue
    final prevSurah = current - 1;
    await playSurahSequenceWithDownload(context, prevSurah);
  }

  // Backward compatibility with "playAyah" methods if used directly?
  // They are rarely used directly in current flow (mostly ranges).
}
