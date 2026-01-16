import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'audio_service.dart' as local_audio;
import 'quran_audio_handler.dart';
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
        ),
      );

      // Sync state from handler
      _handler.playbackState.listen((state) {
        isPlaying.value = state.playing;
        if (state.processingState == AudioProcessingState.completed) {
          stop();
        }
      });

      _handler.mediaItem.listen((item) {
        if (item != null) {
          currentLabel.value = item.title;
          if (item.extras != null) {
            final s = item.extras!['surah'] as int?;
            final a = item.extras!['ayah'] as int?;
            if (s != null) currentSurah.value = s;
            if (a != null) currentAyah.value = a;
          }
        }
      });

      // just_audio's currentIndexStream logic is encapsulated in handler's metadata update if configured,
      // but we can also listen to handler's queue or custom stream if exposed.
      // Our handler exposes currentIndexStream.
      _handler.currentIndexStream.listen((index) {
        // We rely on MediaItem updates from just_audio_background (if used) or manual updates.
        // But wait, using ClippingAudioSource with tag, just_audio updates the 'sequenceState'.
        // 'audio_service' with just_audio integration usually updates MediaItem automatically if configured?
        // No, we need to map index to MediaItem manually in the handler or here.
        // Since we didn't add logic in Handler to map index -> MediaItem, we should do it here if possible,
        // OR update Handler to do it.
        // BETTER: AudioPlayerService knows the playlist.
        if (index != null &&
            _currentPlaylistMetadata != null &&
            index < _currentPlaylistMetadata!.length) {
          final meta = _currentPlaylistMetadata![index];
          final item = meta['item'] as MediaItem;
          // We manually push this item as 'current' to the handler so lock screen updates
          // _handler.playMediaItem(
          //     item); // specific method I added, but wait, this might restart playback?
          // My 'playMediaItem' implementation:
          // mediaItem.add(item); setUrl/FilePath...
          // That restarts playback! Bad!

          // We need a way to just Update Metadata without changing source.
          // BaseAudioHandler has `mediaItem.add(item)`.
          // So we can just call that on handler.
          // But `_handler` field is `QuranAudioHandler`.
          // I should expose a method `updateCurrentItem(MediaItem item)`.
          // Or just access `.mediaItem.add`.
          _handler.mediaItem.add(item);
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

  // --- Playback Logic ---

  /// Play a custom range with download support.
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

    // 2. Download all Surahs in range
    final local_audio.AudioService storage = local_audio.AudioService.instance;
    await storage.initialize();

    for (var s = startSurah; s <= endSurah; s++) {
      if (!(await storage.isSurahDownloaded(recitation.id, s))) {
        final ok = await downloadSurahIfNeeded(recitation, s);
        if (!ok) {
          if (context != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to download Surah $s')));
          }
          return;
        }
      }
    }

    // 3. Build Playlist
    final List<AudioSource> sources = [];
    final List<Map<String, dynamic>> metadata = [];

    for (var s = startSurah; s <= endSurah; s++) {
      final totalAyahs = getVerseCount(s);
      final first = (s == startSurah) ? startAyah : 1;
      final last = (s == endSurah) ? endAyah : totalAyahs;

      final file = await storage.getLocalSurahFile(recitation.id, s);
      final segments = await storage.getLocalSegments(recitation.id, s);

      if (file == null || segments == null) continue;

      for (var ayah = first; ayah <= last; ayah++) {
        final segment = segments.firstWhere((seg) => seg.ayahNumber == ayah,
            orElse: () => segments.first);
        final surahName = getSurahName(s);
        final title = '$surahName : $ayah';

        final mediaItem = MediaItem(
          id: '${file.path}_$ayah', // Unique ID helps just_audio
          album: surahName,
          title: title,
          artist: recitation.reciterName,
          artUri: Uri.parse('asset:///assets/images/Icon.jpg'),
          extras: {'surah': s, 'ayah': ayah},
        );

        final source = ClippingAudioSource(
          child: AudioSource.file(file.path),
          start: Duration(milliseconds: segment.timestampFrom),
          end: Duration(milliseconds: segment.timestampTo),
          tag: mediaItem,
        );

        sources.add(source);
        metadata.add({'surah': s, 'ayah': ayah, 'item': mediaItem});
      }
    }

    if (sources.isEmpty) return;

    _currentPlaylistMetadata = metadata;
    hasSourceNotifier.value = true;

    // 4. Play
    // ConcatenatingAudioSource makes gapless playback possible with buffering
    await _handler.setAudioSource(ConcatenatingAudioSource(children: sources));
    await _handler.play();
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
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Choose Reciter',
                      style: TextStyle(fontWeight: FontWeight.bold))),
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
      final notifId = surah; // Use surah ID as notification ID
      return await local_audio.AudioService.instance
          .downloadSurahAudio(recitation, surah, onProgress: (p) {
        downloadProgress.value = p;
        AppNotificationService.instance
            .showProgress(notifId, 'Downloading Surah $surah', p);
      });
    } finally {
      AppNotificationService.instance.cancel(surah);
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
