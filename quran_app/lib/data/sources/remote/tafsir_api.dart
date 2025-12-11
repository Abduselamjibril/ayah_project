// lib/data/sources/remote/tafsir_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// API client for fetching Quran tafsirs from AlQuran.cloud
class TafsirApi {
  static const String _baseUrl = 'http://api.alquran.cloud/v1';
  static const Duration _timeout = Duration(seconds: 30);

  /// Get list of all available tafsir editions
  ///
  /// Returns a list of tafsir editions with metadata
  /// API endpoint: GET /edition/type/tafsir
  Future<List<Map<String, dynamic>>> getAvailableTafsirs() async {
    try {
      final uri = Uri.parse('$_baseUrl/edition/type/tafsir');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          final allEditions = List<Map<String, dynamic>>.from(data['data']);

          // Filter to only include text format (not audio)
          return allEditions.where((edition) {
            return edition['format'] == 'text';
          }).toList();
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch available tafsirs: $e');
    }
  }

  /// Download complete Quran tafsir for a specific edition
  ///
  /// [editionIdentifier]: Edition identifier (e.g., 'ar.muyassar', 'ar.jalalayn')
  /// Returns complete Quran data with all surahs and ayahs
  /// API endpoint: GET /quran/{edition}
  Future<Map<String, dynamic>> downloadTafsir(String editionIdentifier) async {
    try {
      final uri = Uri.parse('$_baseUrl/quran/$editionIdentifier');
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
      throw Exception('Failed to download tafsir $editionIdentifier: $e');
    }
  }
}
