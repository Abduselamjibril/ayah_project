// lib/core/services/translation_service.dart
import 'package:quran_library/quran_library.dart';
import 'package:quran_app/core/database/dao/translation_dao.dart';
import 'package:quran_app/core/database/app_database.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._init();
  TranslationService._init();

  late TranslationDao _translationDao;
  bool _isInitialized = false;

  /// Initialize the translation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize QuranLibrary
      await QuranLibrary.init();

      // Initialize DAO
      final database = await AppDatabase.instance.database;
      _translationDao = TranslationDao(database);

      _isInitialized = true;
      print('TranslationService initialized successfully');
    } catch (e) {
      print('Error initializing TranslationService: $e');
      rethrow;
    }
  }

  /// Get translation for a specific verse
  /// Returns from database if exists, otherwise returns placeholder
  Future<String?> getTranslation({
    required int surahNumber,
    required int ayahNumber,
    required String language,
    String? translator,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // First, check database
      final cached = await _translationDao.getTranslation(
        surahNumber,
        ayahNumber,
        language,
        translator,
      );

      if (cached != null) {
        return cached['text'] as String?;
      }

      // For now, return a placeholder since quran_library requires download
      return 'Translation not available offline. Please download translations from settings.';
    } catch (e) {
      print('Error getting translation: $e');
      return null;
    }
  }

  /// Get all translations for a specific verse
  Future<List<Map<String, dynamic>>> getAllTranslations({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (!_isInitialized) await initialize();
    return await _translationDao.getAllTranslations(surahNumber, ayahNumber);
  }

  /// Get list of available languages
  List<String> getAvailableLanguages() {
    return [
      'English',
      'French',
      'Turkish',
      'Arabic',
    ];
  }

  /// Download a translation
  /// Note: This requires actual implementation with quran_library's fetchTranslation
  Future<void> downloadTranslation(int translationIndex) async {
    if (!_isInitialized) await initialize();

    try {
      // QuranLibrary().fetchTranslation() would be called here
      // This requires UI for user to select which translation to download
      print('Download translation at index: $translationIndex');
    } catch (e) {
      print('Error downloading translation: $e');
    }
  }

  /// Get list of available translations from quran_library
  Future<List<dynamic>> getAvailableTranslationsList() async {
    if (!_isInitialized) await initialize();

    try {
      return QuranLibrary().translationList ?? [];
    } catch (e) {
      print('Error getting translation list: $e');
      return [];
    }
  }
}
