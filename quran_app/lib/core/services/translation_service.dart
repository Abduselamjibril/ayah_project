// lib/core/services/translation_service.dart
import 'package:quran_app/core/database/dao/translation_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/translation_api.dart';
import 'package:quran_app/data/sources/local/translation_local.dart';
import 'package:quran_app/data/models/translation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._init();
  TranslationService._init();

  late TranslationDao _translationDao;
  late TranslationLocal _translationLocal;
  final TranslationApi _api = TranslationApi();
  bool _isInitialized = false;

  static const String _bundledLoadedKey = 'bundled_translation_loaded';

  /// Initialize the translation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize DAO
      final database = await AppDatabase.instance.database;
      _translationDao = TranslationDao(database);
      _translationLocal = TranslationLocal(_translationDao);

      _isInitialized = true;
      print('TranslationService initialized successfully');

      // Load bundled translation on first run
      await _loadBundledTranslationIfNeeded();
    } catch (e) {
      print('Error initializing TranslationService: $e');
      rethrow;
    }
  }

  /// Load bundled translation if not already loaded
  Future<void> _loadBundledTranslationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoaded = prefs.getBool(_bundledLoadedKey) ?? false;

      if (!isLoaded) {
        print('First run detected, loading bundled translation...');
        await _translationLocal.loadBundledTranslation();
        await prefs.setBool(_bundledLoadedKey, true);
        print('Bundled translation loaded and marked as complete');
      } else {
        print('Bundled translation already loaded, skipping');
      }
    } catch (e) {
      print('Error loading bundled translation: $e');
      // Don't rethrow, app can still function without bundled data
    }
  }

  /// Get list of available languages from API
  Future<List<String>> getAvailableLanguages() async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getLanguages();
    } catch (e) {
      print('Error fetching available languages: $e');
      return [];
    }
  }

  /// Get available translation editions for a specific language
  Future<List<TranslationEdition>> getEditionsByLanguage(
      String languageCode) async {
    if (!_isInitialized) await initialize();

    try {
      final editions = await _api.getEditionsByLanguage(languageCode);
      return editions.map((e) => TranslationEdition.fromJson(e)).toList();
    } catch (e) {
      print('Error fetching editions for language $languageCode: $e');
      return [];
    }
  }

  /// Get all available translation editions across all languages
  Future<List<TranslationEdition>> getAllTranslationEditions() async {
    if (!_isInitialized) await initialize();

    try {
      // Get all available languages
      final languages = await getAvailableLanguages();

      // Fetch editions for all languages
      final allEditions = <TranslationEdition>[];
      for (final language in languages) {
        final editions = await getEditionsByLanguage(language);
        allEditions.addAll(editions);
      }

      return allEditions;
    } catch (e) {
      print('Error fetching all translation editions: $e');
      return [];
    }
  }

  /// Download a complete translation edition and store it locally
  ///
  /// [edition]: Translation edition to download
  /// [onProgress]: Optional callback to report download progress (0.0 to 1.0)
  Future<bool> downloadTranslation(
    TranslationEdition edition, {
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('Downloading translation: ${edition.identifier}');
      onProgress?.call(0.0);

      // Download complete Quran data
      final data = await _api.downloadTranslation(edition.identifier);

      // Parse and prepare for database insertion
      final translationsToInsert = await _translationLocal.parseTranslationData(
        data,
        edition.language,
        edition.englishName,
        edition.identifier,
      );

      onProgress?.call(0.5);

      // Batch insert into database
      print('Inserting ${translationsToInsert.length} translation verses');
      await _translationDao.insertBatch(translationsToInsert);

      onProgress?.call(1.0);
      print('Translation download completed: ${edition.identifier}');
      return true;
    } catch (e) {
      print('Error downloading translation: $e');
      return false;
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
        // Get from database
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

      return 'Translation not available. Please download from Downloads screen.';
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

  /// Get list of all downloaded translation edition identifiers
  Future<List<String>> getDownloadedTranslations() async {
    if (!_isInitialized) await initialize();
    return await _translationDao.getDownloadedEditions();
  }

  /// Delete a downloaded translation edition
  Future<bool> deleteTranslation(String editionIdentifier) async {
    if (!_isInitialized) await initialize();

    try {
      // Prevent deletion of bundled translation
      if (editionIdentifier == 'en.asad') {
        print('Cannot delete bundled translation: $editionIdentifier');
        return false;
      }

      final count = await _translationDao.deleteByEdition(editionIdentifier);
      return count > 0;
    } catch (e) {
      print('Error deleting translation: $e');
      return false;
    }
  }

  /// Check if an edition is bundled with the app
  bool isBundledEdition(String editionIdentifier) {
    return editionIdentifier == 'en.asad';
  }
}
