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

  Future<List<TafsirAyah>> downloadTafsir(
    int tafsirId, {
    Function(int currentSurah, int totalSurahs)? onProgress,
  }) async {
    final List<TafsirAyah> allAyahs = [];
    const totalSurahs = 114;

    try {
      print('=== TAFSIR API: Starting download for tafsir ID $tafsirId ===');

      // Download each surah
      for (int surahNumber = 1; surahNumber <= totalSurahs; surahNumber++) {
        if (onProgress != null) {
          onProgress(surahNumber, totalSurahs);
        }

        final uri = Uri.parse(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.tafsirsBySurah(tafsirId, surahNumber)}');

        print('TAFSIR API: Downloading surah $surahNumber/$totalSurahs');
        print('TAFSIR API: URL = $uri');

        final response = await http.get(uri).timeout(_timeout);

        print('TAFSIR API: Response status = ${response.statusCode}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print('TAFSIR API: Response keys = ${data.keys.toList()}');

          if (data['tafsirs'] != null) {
            final tafsirsList = data['tafsirs'] as List;
            print(
                'TAFSIR API: Found ${tafsirsList.length} tafsir entries for surah $surahNumber');

            if (tafsirsList.isNotEmpty) {
              // Sample first entry
              print(
                  'TAFSIR API: Sample entry keys = ${tafsirsList.first.keys.toList()}');
              print(
                  'TAFSIR API: Sample verse_key = ${tafsirsList.first['verse_key']}');
              print(
                  'TAFSIR API: Sample resource_id = ${tafsirsList.first['resource_id']}');
            }

            final tafsirs =
                tafsirsList.map((json) => TafsirAyah.fromJson(json)).toList();
            allAyahs.addAll(tafsirs);
            print('TAFSIR API: Total ayahs so far = ${allAyahs.length}');
          } else {
            print('TAFSIR API: WARNING - No "tafsirs" key in response');
            print(
                'TAFSIR API: Response body = ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...');
          }
        } else {
          print('TAFSIR API: ERROR - HTTP ${response.statusCode}');
          print('TAFSIR API: Error body = ${response.body}');
          throw Exception(
              'HTTP ${response.statusCode} for surah $surahNumber: ${response.body}');
        }

        // Small delay to avoid rate limiting
        if (surahNumber < totalSurahs) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('TAFSIR API: Download complete - ${allAyahs.length} total verses');
      return allAyahs;
    } catch (e, stackTrace) {
      print('TAFSIR API: ERROR - Failed to download: $e');
      print('TAFSIR API: Stack trace: $stackTrace');
      throw Exception('Failed to download tafsir $tafsirId: $e');
    }
  }
}
