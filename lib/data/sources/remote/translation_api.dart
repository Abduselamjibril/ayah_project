// lib/data/sources/remote/translation_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/translation_model.dart';
import '../../../core/constants/api_endpoints.dart';
import '../local/translation_cache.dart';

/// API client for fetching Quran translations from Quran.com
class TranslationApi {
  static const Duration _timeout = Duration(seconds: 30);
  final TranslationCache _cache = TranslationCache();

  /// Get list of all available translations
  ///
  /// Returns a list of TranslationEdition objects
  /// API endpoint: GET /resources/translations
  /// Uses cache to reduce network calls
  Future<List<TranslationEdition>> getAllTranslations(
      {String? language}) async {
    try {
      // Try to get from cache first
      final cacheKey =
          'all_translations${language != null ? '_$language' : ''}';

      // Build API URL
      final uri = language != null
          ? Uri.parse(
              '${ApiEndpoints.baseUrl}${ApiEndpoints.translations}?language=$language')
          : Uri.parse('${ApiEndpoints.baseUrl}${ApiEndpoints.translations}');

      print('Fetching translations from API: $uri');
      final response = await http.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['translations'] != null) {
          final translations = (data['translations'] as List)
              .map((json) => TranslationEdition.fromJson(json))
              .toList();

          return translations;
        }
        throw Exception('API returned invalid data structure');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to fetch translations: $e');
    }
  }

  /// Return a direct single-file export URL if your backend supports it; else null
  String? buildDownloadUrlOrNull(int translationId) {
    // Quran.com API does not provide single-file exports; return null to fallback
    return null;
  }

  /// Get list of all available languages for translations
  ///
  /// Returns a list of language names (e.g., ['english', 'arabic', 'french', ...])
  /// Extracts unique languages from the translations list
  Future<List<String>> getLanguages() async {
    try {
      final translations = await getAllTranslations();
      final languages = translations.map((t) => t.languageName).toSet().toList()
        ..sort();

      return languages;
    } catch (e) {
      throw Exception('Failed to fetch languages: $e');
    }
  }

  /// Get all translation editions for a specific language
  ///
  /// [languageName]: Full language name (e.g., 'english', 'arabic', 'french')
  /// Returns a list of translation editions with metadata
  Future<List<TranslationEdition>> getEditionsByLanguage(
      String languageName) async {
    try {
      final allTranslations = await getAllTranslations();
      return allTranslations
          .where(
              (t) => t.languageName.toLowerCase() == languageName.toLowerCase())
          .toList();
    } catch (e) {
      throw Exception(
          'Failed to fetch editions for language $languageName: $e');
    }
  }

  /// Download complete Quran translation for a specific edition
  ///
  /// [translationId]: Translation resource ID (integer, e.g., 131)
  /// Returns complete Quran data with all surahs and ayahs
  /// Note: This requires 114 API calls (one per surah)
  Future<List<TranslatedAyah>> downloadTranslation(
    int translationId, {
    Function(int currentSurah, int totalSurahs)? onProgress,
  }) async {
    final List<TranslatedAyah> allAyahs = [];
    const totalSurahs = 114;

    try {
      // Download each surah
      for (int surahNumber = 1; surahNumber <= totalSurahs; surahNumber++) {
        if (onProgress != null) {
          onProgress(surahNumber, totalSurahs);
        }

        final uri = Uri.parse(
            '${ApiEndpoints.baseUrl}${ApiEndpoints.translationsBySurah(translationId, surahNumber)}&fields=verse_key');

        print('Downloading translation for surah $surahNumber/$totalSurahs');
        final response = await http.get(uri).timeout(_timeout);

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['translations'] != null) {
            final translations = (data['translations'] as List)
                .map((json) => TranslatedAyah.fromJson(json))
                .toList();
            allAyahs.addAll(translations);
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
      throw Exception('Failed to download translation $translationId: $e');
    }
  }

  /// Get human-readable language names map
  ///
  /// Returns a map of language codes to full language names
  /// Example: {'en': 'english', 'ar': 'arabic', 'fr': 'french'}
  static const Map<String, String> languageNames = {
    'ar': 'arabic',
    'am': 'amharic',
    'az': 'azerbaijani',
    'ber': 'berber',
    'bn': 'bengali',
    'cs': 'czech',
    'ce': 'chechen',
    'de': 'german',
    'dv': 'dhivehi',
    'en': 'english',
    'es': 'spanish',
    'fa': 'persian',
    'fr': 'french',
    'ha': 'hausa',
    'hi': 'hindi',
    'id': 'indonesian',
    'it': 'italian',
    'ja': 'japanese',
    'ko': 'korean',
    'ku': 'kurdish',
    'ml': 'malayalam',
    'nl': 'dutch',
    'no': 'norwegian',
    'pl': 'polish',
    'ps': 'pashto',
    'pt': 'portuguese',
    'ro': 'romanian',
    'ru': 'russian',
    'sd': 'sindhi',
    'so': 'somali',
    'sq': 'albanian',
    'sv': 'swedish',
    'sw': 'swahili',
    'ta': 'tamil',
    'tg': 'tajik',
    'th': 'thai',
    'tr': 'turkish',
    'tt': 'tatar',
    'ug': 'uyghur',
    'ur': 'urdu',
    'uz': 'uzbek',
    'zh': 'chinese',
  };

  /// Get human-readable name for a language code
  static String getLanguageName(String languageCode) {
    return languageNames[languageCode.toLowerCase()] ?? languageCode;
  }

  /// Get language code from full language name
  static String? getLanguageCode(String languageName) {
    final lowerName = languageName.toLowerCase();
    return languageNames.entries
        .firstWhere(
          (entry) => entry.value == lowerName,
          orElse: () => const MapEntry('', ''),
        )
        .key;
  }
}
