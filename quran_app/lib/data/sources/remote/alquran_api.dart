// lib/data/sources/remote/alquran_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API client for AlQuran.cloud
class AlQuranApi {
  static const String _baseUrl = 'https://api.alquran.cloud/v1';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get list of all available editions (translations and tafsirs)
  ///
  /// Optional filters:
  /// - [format]: 'text' or 'audio'
  /// - [language]: 2-digit language code (e.g., 'en', 'ar', 'fr')
  /// - [type]: 'translation', 'tafsir', 'versebyverse', etc.
  Future<List<Map<String, dynamic>>> getEditions({
    String? format,
    String? language,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (format != null) queryParams['format'] = format;
      if (language != null) queryParams['language'] = language;
      if (type != null) queryParams['type'] = type;

      final uri = Uri.parse('$_baseUrl/edition')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch editions: $e');
    }
  }

  /// Get a specific ayah with translation/tafsir
  ///
  /// [ayahNumber]: Absolute ayah number (1-6236) or "surah:ayah" format (e.g., "2:255")
  /// [edition]: Edition identifier (e.g., 'en.asad', 'ar.muyassar')
  Future<Map<String, dynamic>> getAyah(
      String ayahNumber, String edition) async {
    try {
      final uri = Uri.parse('$_baseUrl/ayah/$ayahNumber/$edition');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return data['data'];
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch ayah: $e');
    }
  }

  /// Get multiple editions of the same ayah
  ///
  /// [ayahNumber]: Absolute ayah number (1-6236) or "surah:ayah" format
  /// [editions]: Comma-separated list of edition identifiers
  Future<List<Map<String, dynamic>>> getAyahMultipleEditions(
    String ayahNumber,
    List<String> editions,
  ) async {
    try {
      final editionString = editions.join(',');
      final uri =
          Uri.parse('$_baseUrl/ayah/$ayahNumber/editions/$editionString');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch ayah editions: $e');
    }
  }

  /// Get a complete surah with translation/tafsir
  ///
  /// [surahNumber]: Surah number (1-114)
  /// [edition]: Edition identifier (e.g., 'en.asad', 'ar.muyassar')
  /// [offset]: Skip first N ayahs
  /// [limit]: Limit number of ayahs returned
  Future<Map<String, dynamic>> getSurah(
    int surahNumber,
    String edition, {
    int? offset,
    int? limit,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (offset != null) queryParams['offset'] = offset.toString();
      if (limit != null) queryParams['limit'] = limit.toString();

      final uri = Uri.parse('$_baseUrl/surah/$surahNumber/$edition')
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return data['data'];
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch surah: $e');
    }
  }

  /// Get multiple editions of the same surah
  ///
  /// [surahNumber]: Surah number (1-114)
  /// [editions]: List of edition identifiers
  Future<List<Map<String, dynamic>>> getSurahMultipleEditions(
    int surahNumber,
    List<String> editions,
  ) async {
    try {
      final editionString = editions.join(',');
      final uri =
          Uri.parse('$_baseUrl/surah/$surahNumber/editions/$editionString');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return List<Map<String, dynamic>>.from(data['data']);
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch surah editions: $e');
    }
  }

  /// Get complete Quran in a specific edition
  ///
  /// [edition]: Edition identifier (e.g., 'en.asad', 'quran-uthmani')
  Future<Map<String, dynamic>> getQuran(String edition) async {
    try {
      final uri = Uri.parse('$_baseUrl/quran/$edition');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          return data['data'];
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch Quran: $e');
    }
  }

  /// Helper: Convert surah:ayah to absolute ayah number
  /// This is useful when you have surah and ayah numbers separately
  static String formatAyahReference(int surahNumber, int ayahNumber) {
    return '$surahNumber:$ayahNumber';
  }
}
