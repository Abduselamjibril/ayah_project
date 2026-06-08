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
      '/tafsirs/$tafsirId/by_chapter/$chapterNumber';

  // Languages endpoint
  static const String languages = '/resources/languages';

  // Chapter info
  static const String chapters = '/chapters';

  // Audio recitations endpoints
  static const String recitations = '/resources/recitations';
  // Changed to use the verse-by-verse endpoint
  static String recitationsBySurah(int recitationId, int chapterNumber) =>
      '/recitations/$recitationId/by_chapter/$chapterNumber';
  static String recitationsByAyah(int recitationId, int surah, int ayah) =>
      '/recitations/$recitationId/by_ayah/$surah:$ayah';
  // New: Chapter recitations with timestamp segments
  static String chapterRecitations(int reciterId, int chapterId) =>
      '/chapter_recitations/$reciterId/$chapterId';
}
