// lib/data/sources/remote/audio_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/audio_model.dart';
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

  /// Get audio files for a specific chapter for a given recitation
  /// API endpoint: GET /recitations/{id}/by_chapter/{chapterNumber}
  Future<List<AudioVerseFile>> getAudioByChapter(
    int recitationId,
    int chapterNumber,
  ) async {
    try {
      final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.recitationsBySurah(recitationId, chapterNumber)}');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Quran.com v4 returns either a single 'audio_file' or a list 'audio_files'
        final result = <AudioVerseFile>[];
        if (data['audio_files'] is List) {
          final list = data['audio_files'] as List;
          result.addAll(list.map((e) {
            final item = AudioVerseFile.fromJson(e as Map<String, dynamic>);
            // Fix relative URLs for verse-by-verse audio
            if (!item.url.startsWith('http')) {
              return AudioVerseFile(
                surahNumber: item.surahNumber,
                ayahNumber: item.ayahNumber,
                url: 'https://verses.quran.com/${item.url}',
                verseKey: item.verseKey,
                chapterId: item.chapterId,
                format: item.format,
              );
            }
            return item;
          }));
        } else if (data['audio_file'] is Map) {
          result.add(AudioVerseFile.fromJson(
              data['audio_file'] as Map<String, dynamic>));
        }
        return result;
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
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
}
