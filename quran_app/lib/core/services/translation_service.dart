// lib/core/services/translation_service.dart
import 'package:quran_app/core/database/dao/translation_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/translation_api.dart';

import 'package:quran_app/data/models/translation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TranslationService {
  static final TranslationService instance = TranslationService._init();
  TranslationService._init();

  late TranslationDao _translationDao;
  final TranslationApi _api = TranslationApi();
  bool _isInitialized = false;

  static const String _selectedTranslationKey = 'selected_translation_id';

  /// Initialize the translation service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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
      String languageName) async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getEditionsByLanguage(languageName);
    } catch (e) {
      print('Error fetching editions for language $languageName: $e');
      return [];
    }
  }

  /// Get all available translation editions across all languages
  Future<List<TranslationEdition>> getAllTranslationEditions() async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getAllTranslations();
    } catch (e) {
      print('Error fetching all translation editions: $e');
      return [];
    }
  }

  /// Provide a direct download URL if available for background downloads.
  /// Returns null if a single-file export is not available.
  String? getDownloadUrl(TranslationEdition edition) {
    return _api.buildDownloadUrlOrNull(edition.id);
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
      print('Downloading translation: ${edition.id} (${edition.name})');
      onProgress?.call(0.0);

      // Download complete Quran data
      // New API returns a list of TranslatedAyah directly
      final ayahs = await _api.downloadTranslation(
        edition.id,
        onProgress: (current, total) {
          // Calculate progress based on surahs downloaded
          // We allocate 90% of progress to downloading, 10% to inserting
          final downloadProgress = (current / total) * 0.9;
          onProgress?.call(downloadProgress);
        },
      );

      print('Converting ${ayahs.length} verses for database insertion');
      final translationsToInsert = ayahs.map((ayah) {
        return ayah.toDatabase(
          language: edition.languageName,
          translator: edition.name,
        );
      }).toList();

      onProgress?.call(0.95);

      // Batch insert into database
      print('Inserting ${translationsToInsert.length} translation verses');
      await _translationDao.insertBatch(translationsToInsert);

      // Set as selected if none is selected
      final currentSelected = await getSelectedTranslationId();
      if (currentSelected == null) {
        await setSelectedTranslationId(edition.id);
      }

      onProgress?.call(1.0);
      print('Translation download completed: ${edition.id}');
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
      final count = await _translationDao.deleteByEdition(editionIdentifier);

      // If deleted was selected, clear selection
      final selectedId = await getSelectedTranslationId();
      if (selectedId.toString() == editionIdentifier) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_selectedTranslationKey);
      }

      return count > 0;
    } catch (e) {
      print('Error deleting translation: $e');
      return false;
    }
  }

  /// Check if an edition is bundled with the app
  bool isBundledEdition(String editionIdentifier) {
    return false; // No bundled editions anymore
  }

  // User Selection Persistence

  /// Get the selected translation ID (returns int ID of the resource)
  Future<int?> getSelectedTranslationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedTranslationKey);
  }

  /// Set the selected translation ID
  Future<void> setSelectedTranslationId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTranslationKey, id);
    print('Selected translation set to: $id');
  }

  /// Get full details of the selected translation
  /// Returns null if no translation is selected or if metadata fetch fails
  Future<TranslationEdition?> getSelectedTranslation() async {
    final id = await getSelectedTranslationId();
    if (id == null) return null;

    // We need to find the edition in the available list to get its details (name, language, etc.)
    // We could cache this list, but for now we fetch it.
    // Optimization: Cache all translations in a map in memory.
    final allEditions = await getAllTranslationEditions();
    try {
      return allEditions.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
}
