// lib/core/services/translation_service.dart
import 'package:quran_library/quran_library.dart';
import 'package:quran_app/core/database/dao/translation_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/alquran_api.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._init();
  TranslationService._init();

  late TranslationDao _translationDao;
  final AlQuranApi _api = AlQuranApi();
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

  /// Get available editions (translations) from AlQuran.cloud API
  Future<List<Map<String, dynamic>>> getAvailableTranslations({
    String? language,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getEditions(
        format: 'text',
        language: language,
        type: 'translation',
      );
    } catch (e) {
      print('Error fetching available translations: $e');
      return [];
    }
  }

  /// Download a complete translation edition and store it locally
  ///
  /// [editionIdentifier]: e.g., 'en.asad', 'ar.muyassar', 'fr.hamidullah'
  /// [onProgress]: Optional callback to report download progress (current surah / 114)
  Future<bool> downloadTranslation(
    String editionIdentifier, {
    Function(int currentSurah, int totalSurahs)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('Downloading translation: $editionIdentifier');

      // Download all 114 surahs
      for (int surahNumber = 1; surahNumber <= 114; surahNumber++) {
        onProgress?.call(surahNumber, 114);

        final surahData = await _api.getSurah(surahNumber, editionIdentifier);
        final ayahs = surahData['ayahs'] as List<dynamic>;

        // Prepare batch data
        final translations = <Map<String, dynamic>>[];
        for (final ayah in ayahs) {
          translations.add({
            'surah_number':
                surahNumber, // Fixed: use actual surah number from loop
            'ayah_number': ayah['numberInSurah'], // verse number within surah
            'language': surahData['edition']['language'] ?? 'unknown',
            'translator': surahData['edition']['englishName'] ?? '',
            'edition_identifier': editionIdentifier,
            'text': ayah['text'],
          });
        }

        // Insert batch for this surah
        await _translationDao.insertBatch(translations);
      }

      print('Translation download completed: $editionIdentifier');
      return true;
    } catch (e) {
      print('Error downloading translation: $e');
      return false;
    }
  }

  /// Get translation for a specific verse
  /// Returns from database if exists, otherwise fetches from API
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

      // If not in database, return message to download
      return 'Translation not available offline. Please download from Downloads screen.';
    } catch (e) {
      print('Error getting translation: $e');
      return null;
    }
  }

  /// Get translation for a specific verse by edition identifier
  Future<String?> getTranslationByEdition({
    required int surahNumber,
    required int ayahNumber,
    required String editionIdentifier,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if this edition is downloaded
      final isDownloaded =
          await _translationDao.isEditionDownloaded(editionIdentifier);

      if (isDownloaded) {
        // Get from database - we need to query by edition_identifier
        final results =
            await AppDatabase.instance.database.then((db) => db.query(
                  'translations',
                  where:
                      'surah_number = ? AND ayah_number = ? AND edition_identifier = ?',
                  whereArgs: [surahNumber, ayahNumber, editionIdentifier],
                  limit: 1,
                ));

        if (results.isNotEmpty) {
          return results.first['text'] as String?;
        }
      }

      // Not in database, fetch from API directly
      try {
        final ayahData = await _api.getAyah(
          AlQuranApi.formatAyahReference(surahNumber, ayahNumber),
          editionIdentifier,
        );
        return ayahData['text'] as String?;
      } catch (e) {
        return 'Translation not available. Please download from Downloads screen.';
      }
    } catch (e) {
      print('Error getting translation by edition: $e');
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

  /// Check if a translation edition is downloaded
  Future<bool> isTranslationDownloaded(String editionIdentifier) async {
    if (!_isInitialized) await initialize();
    return await _translationDao.isEditionDownloaded(editionIdentifier);
  }

  /// Get list of all downloaded translation editions
  Future<List<String>> getDownloadedTranslations() async {
    if (!_isInitialized) await initialize();
    return await _translationDao.getDownloadedEditions();
  }

  /// Delete a downloaded translation edition
  Future<bool> deleteTranslation(String editionIdentifier) async {
    if (!_isInitialized) await initialize();

    try {
      final count = await _translationDao.deleteByEdition(editionIdentifier);
      return count > 0;
    } catch (e) {
      print('Error deleting translation: $e');
      return false;
    }
  }

  /// Get list of available languages
  List<String> getAvailableLanguages() {
    return [
      'English',
      'French',
      'Turkish',
      'Arabic',
      'Urdu',
      'Indonesian',
      'Spanish',
    ];
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
