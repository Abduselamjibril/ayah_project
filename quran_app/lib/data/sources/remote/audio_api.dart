// lib/data/sources/remote/audio_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/audio_model.dart';
import '../../models/chapter_audio.dart';
import '../../../core/constants/api_endpoints.dart';

/// API client for fetching Quran audio recitations and files
class AudioApi {
  static const Duration _timeout = Duration(seconds: 30);

  /// Get list of all available audio recitations (reciters)
  /// API endpoint: GET /resources/recitations
  Future<List<AudioRecitation>> getAvailableRecitations() async {
    try {
      final uri =
          Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.recitations}');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data['recitations'] ?? data['data'] ?? []) as List;
        return list.map((e) => AudioRecitation.fromJson(e)).toList();
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Failed to fetch recitations: $e');
    }
  }

  /// Get audio files for a specific chapter for a given recitation.
  /// Handles pagination to ensure all verses are fetched.
  /// API endpoint: GET /recitations/{id}/by_chapter/{chapterNumber}
  Future<List<AudioVerseFile>> getAudioByChapter(
    int recitationId,
    int chapterNumber, {
    int perPage = 200,
  }) async {
    try {
      final result = <AudioVerseFile>[];
      var page = 1;
      var totalPages = 1;

      do {
        final uri = Uri.parse(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.recitationsBySurah(recitationId, chapterNumber)}?page=$page&per_page=$perPage');
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }

        final data = json.decode(response.body);
        // Pagination metadata (if present)
        final pagination = data['pagination'] as Map<String, dynamic>?;
        if (pagination != null) {
          totalPages = (pagination['total_pages'] as int?) ?? totalPages;
        }

        if (data['audio_files'] is List) {
          final list = data['audio_files'] as List;
          for (final e in list) {
            final item = AudioVerseFile.fromJson(e as Map<String, dynamic>);
            if (!item.url.startsWith('http')) {
              result.add(AudioVerseFile(
                surahNumber: item.surahNumber,
                ayahNumber: item.ayahNumber,
                url: 'https://verses.quran.com/${item.url}',
                verseKey: item.verseKey,
                chapterId: item.chapterId,
                format: item.format,
              ));
            } else {
              result.add(item);
            }
          }
        } else if (data['audio_file'] is Map) {
          result.add(AudioVerseFile.fromJson(
              data['audio_file'] as Map<String, dynamic>));
        }

        page++;
      } while (page <= totalPages);

      return result;
    } catch (e) {
      throw Exception(
          'Failed to fetch audio for recitation $recitationId, chapter $chapterNumber: $e');
    }
  }

  /// Get audio for a specific ayah (surah:ayah) for a given recitation.
  /// API endpoint: GET /recitations/{id}/by_ayah/{surah}:{ayah}
  Future<AudioVerseFile?> getAudioByAyah(
    int recitationId,
    int surah,
    int ayah,
  ) async {
    try {
      final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.recitationsByAyah(recitationId, surah, ayah)}');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['audio_files'] is List &&
            (data['audio_files'] as List).isNotEmpty) {
          final first = (data['audio_files'] as List).first;
          return AudioVerseFile.fromJson(first as Map<String, dynamic>);
        }
        if (data['audio_file'] is Map) {
          return AudioVerseFile.fromJson(
              data['audio_file'] as Map<String, dynamic>);
        }
        return null;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception(
          'Failed to fetch audio for recitation $recitationId, ayah $surah:$ayah: $e');
    }
  }

  /// Get chapter recitation with timestamp segments for each ayah
  /// API endpoint: GET /chapter_recitations/{reciter_id}/{chapter_id}?segments=true
  Future<ChapterAudio?> getChapterRecitation(
    int reciterId,
    int chapterId,
  ) async {
    try {
      final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chapterRecitations(reciterId, chapterId)}?segments=true');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return ChapterAudio.fromJson(data);
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception(
          'Failed to fetch chapter recitation for reciter $reciterId, chapter $chapterId: $e');
    }
  }
}
