// lib/core/services/audio_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/data/sources/remote/audio_api.dart';

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
    final files = await dir.list().toList();
    return files.any((e) => e is File && e.path.endsWith('.mp3'));
  }

  Future<List<String>> getDownloadedSurahs(int recitationId) async {
    final base = await _recitationDir(recitationId);
    if (!await base.exists()) return [];
    final entries = await base.list().toList();
    final surahDirs = entries.whereType<Directory>().toList();
    return surahDirs
        .map((d) => d.path.split(Platform.pathSeparator).last)
        .toList();
  }

  /// Returns the local verse-level audio file if present (e.g. '1_1.mp3').
  Future<File?> getLocalAyahFile(
      int recitationId, int surahNumber, int ayahNumber) async {
    final dir = await _surahDir(recitationId, surahNumber);
    if (!await dir.exists()) return null;
    final target = File(
        '${dir.path}${Platform.pathSeparator}${surahNumber}_${ayahNumber}.mp3');
    if (await target.exists()) return target;
    // Some downloads may include format variations
    final files = await dir.list().toList();
    for (final e in files) {
      if (e is File) {
        final name = e.path.split(Platform.pathSeparator).last;
        if (name == '${surahNumber}_${ayahNumber}.mp3') {
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

      final targetDir = await _surahDir(recitation.id, surahNumber);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      int completed = 0;
      int successCount = 0;
      final total = files.length;
      for (final f in files) {
        final ext = (f.format ?? 'mp3').toLowerCase();
        final baseName = (f.verseKey.isNotEmpty)
            ? f.verseKey.replaceAll(':', '_')
            : 'surah_${surahNumber.toString().padLeft(3, '0')}';
        final fileName = '$baseName.$ext';
        final outPath =
            File('${targetDir.path}${Platform.pathSeparator}$fileName');
        if (await outPath.exists()) {
          completed++;
          onProgress?.call(completed / total);
          continue;
        }
        if (f.url.isEmpty) {
          // Skip if URL missing
          completed++;
          onProgress?.call(completed / total);
          continue;
        }
        final resp = await http.get(Uri.parse(f.url));
        if (resp.statusCode == 200) {
          await outPath.writeAsBytes(resp.bodyBytes);
          successCount++;
        } else {
          // Continue on individual failures
        }
        completed++;
        onProgress?.call(completed / total);
        // Throttle a bit to be gentle
        await Future.delayed(const Duration(milliseconds: 50));
      }

      return successCount > 0;
    } catch (e) {
      return false;
    }
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
