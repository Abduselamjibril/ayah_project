// lib/data/sources/remote/tafsir_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/tafsir_model.dart';
import '../../../core/constants/api_endpoints.dart';

/// API client for fetching Quran tafsirs from Quran.com
class TafsirApi {
  static const Duration _timeout = Duration(seconds: 30);

  /// Get list of all available tafsir editions
  ///
  /// Returns a list of TafsirEdition objects with metadata
  /// API endpoint: GET /resources/tafsirs
  Future<List<TafsirEdition>> getAvailableTafsirs({String? language}) async {
    try {
      // Build API URL
      final uri = language != null
          ? Uri.parse(
              '${ApiEndpoints.baseUrl}${ApiEndpoints.tafsirs}?language=$language')
          : Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.tafsirs}');

      print('Fetching tafsirs from API: $uri');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['tafsirs'] != null) {
          final tafsirs = (data['tafsirs'] as List)
              .map((json) => TafsirEdition.fromJson(json))
              .toList();

          return tafsirs;
        }
        throw Exception('API returned invalid data structure');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch available tafsirs: $e');
    }
  }

  /// Download complete Quran tafsir for a specific edition
  ///
  /// [tafsirId]: Tafsir resource ID (integer, e.g., 169)
  /// Returns complete Quran data with all surahs and ayahs
  /// Note: This requires 114 API calls (one per surah)
  Future<List<TafsirAyah>> downloadTafsir(
    int tafsirId, {
    Function(int currentSurah, int totalSurahs)? onProgress,
  }) async {
    final List<TafsirAyah> allAyahs = [];
    const totalSurahs = 114;

    try {
      // Download each surah
      for (int surahNumber = 1; surahNumber <= totalSurahs; surahNumber++) {
        if (onProgress != null) {
          onProgress(surahNumber, totalSurahs);
        }

        final uri = Uri.parse(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.tafsirsBySurah(tafsirId, surahNumber)}&fields=verse_key');

        print('Downloading tafsir for surah $surahNumber/$totalSurahs');
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['tafsirs'] != null) {
            final tafsirs = (data['tafsirs'] as List)
                .map((json) => TafsirAyah.fromJson(json))
                .toList();
            allAyahs.addAll(tafsirs);
          }
        } else {
          throw Exception(
              'HTTP ${response.statusCode} for surah $surahNumber: ${response.body}');
        }

        // Small delay to avoid rate limiting
        if (surahNumber < totalSurahs) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('Download complete: ${allAyahs.length} verses');
      return allAyahs;
    } catch (e) {
      throw Exception('Failed to download tafsir $tafsirId: $e');
    }
  }
}
