// lib/core/services/audio_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran_app/data/models/audio_model.dart';
import 'package:quran_app/data/models/chapter_audio.dart';
import 'package:quran_app/data/models/audio_segment.dart';
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

  /// Check if a surah is downloaded (segmented format)
  Future<bool> isSurahDownloaded(int recitationId, int surahNumber) async {
    final audioFile = await getLocalSurahFile(recitationId, surahNumber);
    final segmentsFile = await _getSegmentsFile(recitationId, surahNumber);

    // Both audio file and segments metadata must exist
    return audioFile != null &&
        segmentsFile != null &&
        await audioFile.exists() &&
        await segmentsFile.exists();
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

  /// Get the local Surah audio file (segmented format)
  Future<File?> getLocalSurahFile(int recitationId, int surahNumber) async {
    final dir = await _surahDir(recitationId, surahNumber);
    if (!await dir.exists()) return null;

    final audioFile = File('${dir.path}${Platform.pathSeparator}audio.mp3');
    if (await audioFile.exists()) {
      return audioFile;
    }
    return null;
  }

  /// Get the segments metadata for a Surah
  Future<List<AudioSegment>?> getLocalSegments(
      int recitationId, int surahNumber) async {
    final segmentsFile = await _getSegmentsFile(recitationId, surahNumber);
    if (segmentsFile == null || !await segmentsFile.exists()) return null;

    try {
      final content = await segmentsFile.readAsString();
      final json = jsonDecode(content) as List;
      return json
          .map((seg) => AudioSegment.fromJson(seg as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
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

  /// Download audio file for a chapter (surah) using segmented API.
  /// Saves single audio file and segments metadata to: audio/<recitationId>/<surah>/
  Future<bool> downloadSurahAudio(
    AudioRecitation recitation,
    int surahNumber, {
    ProgressFn? onProgress,
  }) async {
    if (!_initialized) await initialize();

    try {
      // Check if already downloaded
      if (await isSurahDownloaded(recitation.id, surahNumber)) {
        onProgress?.call(1.0);
        return true;
      }

      // Fetch chapter audio metadata with segments
      final chapterAudio = await _api.getChapterRecitation(
        recitation.id,
        surahNumber,
      );

      if (chapterAudio == null || chapterAudio.audioUrl.isEmpty) {
        return false;
      }

      final targetDir = await _surahDir(recitation.id, surahNumber);
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // Download the single audio file with progress tracking
      final audioFile =
          File('${targetDir.path}${Platform.pathSeparator}audio.mp3');
      final response = await http.get(
        Uri.parse(chapterAudio.audioUrl),
      );

      if (response.statusCode != 200) {
        return false;
      }

      // Write audio file
      await audioFile.writeAsBytes(response.bodyBytes);
      onProgress?.call(0.9); // Audio downloaded

      // Save segments metadata as JSON
      final segmentsFile =
          File('${targetDir.path}${Platform.pathSeparator}segments.json');
      final segmentsJson =
          chapterAudio.segments.map((seg) => seg.toJson()).toList();
      await segmentsFile.writeAsString(jsonEncode(segmentsJson));

      onProgress?.call(1.0); // Complete
      return await isSurahDownloaded(recitation.id, surahNumber);
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

  Future<File?> _getSegmentsFile(int recitationId, int surahNumber) async {
    final dir = await _surahDir(recitationId, surahNumber);
    if (!await dir.exists()) return null;
    return File('${dir.path}${Platform.pathSeparator}segments.json');
  }
}
