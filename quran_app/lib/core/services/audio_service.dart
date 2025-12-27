// lib/core/services/audio_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/data/sources/remote/audio_api.dart';
import '../quran/qcf_quran.dart';

typedef ProgressFn = void Function(double progress);

class AudioService {
  static final AudioService instance = AudioService._();
  AudioService._();

  final AudioApi _api = AudioApi();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    // Ensure base directories exist
    await _audioBaseDir();
    _initialized = true;
  }

  Future<List<AudioRecitation>> getAvailableRecitations() async {
    if (!_initialized) await initialize();
    return await _api.getAvailableRecitations();
  }

  /// Returns recitation ids that have any downloaded content.
  Future<List<int>> getDownloadedRecitationIds() async {
    final base = await _audioBaseDir();
    if (!await base.exists()) return [];
    final entries = await base.list().toList();
    return entries
        .whereType<Directory>()
        .map((d) => int.tryParse(d.path.split(Platform.pathSeparator).last))
        .whereType<int>()
        .toList();
  }

  Future<bool> isSurahDownloaded(int recitationId, int surahNumber) async {
    final dir = await _surahDir(recitationId, surahNumber);
    if (!await dir.exists()) return false;

    final totalVerses = getVerseCount(surahNumber);
    final files = (await dir.list().toList()).whereType<File>().toList();

    // Ensure every ayah has a corresponding file (any audio extension)
    for (var ayah = 1; ayah <= totalVerses; ayah++) {
      final prefix = '${surahNumber}_$ayah.';
      final hasFile = files.any(
          (f) => f.path.split(Platform.pathSeparator).last.startsWith(prefix));
      if (!hasFile) return false;
    }

    return true;
  }

  Future<List<String>> getDownloadedSurahs(int recitationId) async {
    final base = await _recitationDir(recitationId);
    if (!await base.exists()) return [];
    final entries = await base.list().toList();
    final surahDirs = entries.whereType<Directory>().toList();

    final valid = <String>[];
    for (final d in surahDirs) {
      final name = d.path.split(Platform.pathSeparator).last;
      final sNum = int.tryParse(name);
      if (sNum != null) {
        // Verify it is fully downloaded
        if (await isSurahDownloaded(recitationId, sNum)) {
          valid.add(name);
        }
      }
    }
    return valid;
  }

  /// Returns the local verse-level audio file if present (e.g. '1_1.mp3').
  Future<File?> getLocalAyahFile(
      int recitationId, int surahNumber, int ayahNumber) async {
    final dir = await _surahDir(recitationId, surahNumber);
    if (!await dir.exists()) return null;
    final target = File(
        '${dir.path}${Platform.pathSeparator}${surahNumber}_$ayahNumber.mp3');
    if (await target.exists()) return target;
    // Some downloads may include format variations
    final files = await dir.list().toList();
    for (final e in files) {
      if (e is File) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name == '${surahNumber}_$ayahNumber.mp3') {
          return e;
        }
      }
    }
    return null;
  }

  /// Delete all audio files for a recitation (entire folder).
  Future<void> deleteRecitation(int recitationId) async {
    final dir = await _recitationDir(recitationId);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Returns size in bytes for a recitation folder (best-effort).
  Future<int> getRecitationSizeBytes(int recitationId) async {
    final dir = await _recitationDir(recitationId);
    if (!await dir.exists()) return 0;
    int total = 0;
    final stack = <Directory>[dir];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final entries = await current.list().toList();
      for (final e in entries) {
        if (e is File) {
          total += await e.length();
        } else if (e is Directory) {
          stack.add(e);
        }
      }
    }
    return total;
  }

  /// Download audio files for a chapter (surah) for a given recitation.
  /// Saves files to application support dir: audio/<recitationId>/<surah>/<verseKey>.mp3
  Future<bool> downloadSurahAudio(
    AudioRecitation recitation,
    int surahNumber, {
    ProgressFn? onProgress,
  }) async {
    if (!_initialized) await initialize();

    try {
      final files = await _api.getAudioByChapter(recitation.id, surahNumber);
      if (files.isEmpty) return false;

      // Build a map ayah -> file to ensure we have all verses and correct naming.
      final totalVerses = getVerseCount(surahNumber);
      final verseMap = <int, AudioVerseFile>{};
      for (final f in files) {
        var ayahNum = f.ayahNumber;
        if (ayahNum <= 0) {
          ayahNum = _ayahFromKey(f.verseKey) ?? 0;
        }
        if (ayahNum > 0 && ayahNum <= totalVerses) {
          verseMap[ayahNum] = f;
        }
      }

      // If any verse is missing from the API payload, treat as failure.
      if (verseMap.length < totalVerses) {
        return false;
      }

      final targetDir = await _surahDir(recitation.id, surahNumber);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Identify files that need downloading
      final toDownload = <int>[];
      for (var ayah = 1; ayah <= totalVerses; ayah++) {
        final f = verseMap[ayah];
        if (f == null || f.url.isEmpty) return false;

        final ext = (f.format ?? 'mp3').toLowerCase();
        final fileName = '${surahNumber}_$ayah.$ext';
        final outPath =
            File('${targetDir.path}${Platform.pathSeparator}$fileName');

        if (!await outPath.exists()) {
          toDownload.add(ayah);
        }
      }

      int totalItems = totalVerses;
      // If we only count downloading items for progress, jump start progress for existing ones
      int completed = totalVerses - toDownload.length;

      if (completed == totalVerses) {
        onProgress?.call(1.0);
        return true;
      }

      onProgress?.call(completed / totalItems);

      // Process in batches
      const batchSize = 5;
      for (var i = 0; i < toDownload.length; i += batchSize) {
        final end = (i + batchSize < toDownload.length)
            ? i + batchSize
            : toDownload.length;
        final batch = toDownload.sublist(i, end);

        await Future.wait(batch.map((ayah) async {
          final f = verseMap[ayah]!;
          final ext = (f.format ?? 'mp3').toLowerCase();
          final fileName = '${surahNumber}_$ayah.$ext';
          final outPath =
              File('${targetDir.path}${Platform.pathSeparator}$fileName');

          try {
            final resp = await http.get(Uri.parse(f.url));
            if (resp.statusCode == 200) {
              await outPath.writeAsBytes(resp.bodyBytes);
            }
          } catch (_) {
            // Ignore individual failure to continue batch, verification at end will catch it
          }
        }));

        completed += batch.length;
        onProgress?.call(completed / totalItems);
      }

      return await isSurahDownloaded(recitation.id, surahNumber);
    } catch (e) {
      return false;
    }
  }

  int? _ayahFromKey(String key) {
    if (key.isEmpty) return null;
    final parts = key.split(':');
    if (parts.length != 2) return null;
    return int.tryParse(parts[1]);
  }

  // Paths
  Future<Directory> _audioBaseDir() async {
    final app = await getApplicationSupportDirectory();
    final dir = Directory('${app.path}${Platform.pathSeparator}audio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _recitationDir(int recitationId) async {
    final base = await _audioBaseDir();
    return Directory('${base.path}${Platform.pathSeparator}$recitationId');
  }

  Future<Directory> _surahDir(int recitationId, int surahNumber) async {
    final recDir = await _recitationDir(recitationId);
    return Directory(
        '${recDir.path}${Platform.pathSeparator}${surahNumber.toString().padLeft(3, '0')}');
  }
}
