// lib/core/constants/api_endpoints.dart

/// API endpoints for Quran.com API
class ApiEndpoints {
  // Base URL for Quran.com API
  static const String baseUrl = 'https://api.quran.com/api/v4';

  // Translation endpoints
  static const String translations = '/resources/translations';
  static String translationsBySurah(int translationId, int chapterNumber) =>
      '/quran/translations/$translationId?chapter_number=$chapterNumber';

  // Tafsir endpoints
  static const String tafsirs = '/resources/tafsirs';
  static String tafsirsBySurah(int tafsirId, int chapterNumber) =>
      '/quran/tafsirs/$tafsirId?chapter_number=$chapterNumber';

  // Languages endpoint
  static const String languages = '/resources/languages';

  // Chapter info
  static const String chapters = '/chapters';
}
