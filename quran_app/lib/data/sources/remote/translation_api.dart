// lib/data/sources/remote/translation_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../local/translation_cache.dart';

/// API client for fetching Quran translations from AlQuran.cloud
class TranslationApi {
  static const String _baseUrl = 'http://api.alquran.cloud/v1';
  static const Duration _timeout = Duration(seconds: 30);
  final TranslationCache _cache = TranslationCache();

  /// Get list of all available languages for translations
  ///
  /// Returns a list of language codes (e.g., ['ar', 'en', 'fr', ...])
  /// API endpoint: GET /edition/language
  /// Uses cache to reduce network calls
  Future<List<String>> getLanguages() async {
    try {
      // Try to get from cache first
      final cachedLanguages = await _cache.getCachedLanguages();
      if (cachedLanguages != null) {
        print('Using cached languages (${cachedLanguages.length} languages)');
        return cachedLanguages;
      }

      // Cache miss or expired - fetch from API
      print('Fetching languages from API');
      final uri = Uri.parse('$_baseUrl/edition/language');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          final languages = List<String>.from(data['data']);

          // Cache the result
          await _cache.cacheLanguages(languages);

          return languages;
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // If network fails, try to return cached data even if expired
      final cachedLanguages = await _cache.getCachedLanguages();
      if (cachedLanguages != null) {
        print('Network error, using expired cache');
        return cachedLanguages;
      }
      throw Exception('Failed to fetch languages: $e');
    }
  }

  /// Get all translation editions for a specific language
  ///
  /// [languageCode]: 2-digit language code (e.g., 'en', 'ar', 'fr')
  /// Returns a list of translation editions with metadata
  /// API endpoint: GET /edition/language/{lang}
  /// Uses cache to reduce network calls
  Future<List<Map<String, dynamic>>> getEditionsByLanguage(
      String languageCode) async {
    try {
      // Try to get from cache first
      final cachedEditions = await _cache.getCachedEditions(languageCode);
      if (cachedEditions != null) {
        print(
            'Using cached editions for $languageCode (${cachedEditions.length} editions)');
        return cachedEditions;
      }

      // Cache miss or expired - fetch from API
      print('Fetching editions for $languageCode from API');
      final uri = Uri.parse('$_baseUrl/edition/language/$languageCode');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['code'] == 200 && data['status'] == 'OK') {
          final allEditions = List<Map<String, dynamic>>.from(data['data']);

          // Filter to only include translation editions (type: translation)
          // and text format (not audio)
          final filteredEditions = allEditions.where((edition) {
            return edition['type'] == 'translation' &&
                edition['format'] == 'text';
          }).toList();

          // Cache the result
          await _cache.cacheEditions(languageCode, filteredEditions);

          return filteredEditions;
        }
        throw Exception('API returned error: ${data['status']}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      // If network fails, try to return cached data even if expired
      final cachedEditions = await _cache.getCachedEditions(languageCode);
      if (cachedEditions != null) {
        print('Network error, using expired cache for $languageCode');
        return cachedEditions;
      }
      throw Exception(
          'Failed to fetch editions for language $languageCode: $e');
    }
  }

  /// Download complete Quran translation for a specific edition
  ///
  /// [editionIdentifier]: Edition identifier (e.g., 'en.asad', 'ar.muyassar')
  /// Returns complete Quran data with all surahs and ayahs
  /// API endpoint: GET /quran/{edition}
  Future<Map<String, dynamic>> downloadTranslation(
      String editionIdentifier) async {
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
      throw Exception('Failed to download translation $editionIdentifier: $e');
    }
  }

  /// Get human-readable language names map
  ///
  /// Returns a map of language codes to full language names
  /// Example: {'en': 'English', 'ar': 'Arabic', 'fr': 'French'}
  static const Map<String, String> languageNames = {
    'ar': 'Arabic',
    'am': 'Amharic',
    'az': 'Azerbaijani',
    'ber': 'Berber',
    'bn': 'Bengali',
    'cs': 'Czech',
    'ce': 'Chechen',
    'de': 'German',
    'dv': 'Dhivehi',
    'en': 'English',
    'es': 'Spanish',
    'fa': 'Persian (Farsi)',
    'fr': 'French',
    'ha': 'Hausa',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ku': 'Kurdish',
    'ml': 'Malayalam',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'ps': 'Pashto',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sd': 'Sindhi',
    'so': 'Somali',
    'sq': 'Albanian',
    'sv': 'Swedish',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'tg': 'Tajik',
    'th': 'Thai',
    'tr': 'Turkish',
    'tt': 'Tatar',
    'ug': 'Uyghur',
    'ur': 'Urdu',
    'uz': 'Uzbek',
  };

  /// Get human-readable name for a language code
  static String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode.toUpperCase();
  }
}
