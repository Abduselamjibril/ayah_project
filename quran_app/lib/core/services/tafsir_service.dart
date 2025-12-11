// lib/core/services/tafsir_service.dart
import 'package:quran_library/quran_library.dart';
import 'package:quran_app/core/database/dao/tafsir_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/tafsir_api.dart';
import 'package:quran_app/data/sources/local/tafsir_local.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirService {
  static final TafsirService instance = TafsirService._init();
  TafsirService._init();

  late TafsirDao _tafsirDao;
  late TafsirLocal _tafsirLocal;
  final TafsirApi _api = TafsirApi();
  bool _isInitialized = false;

  static const String _bundledLoadedKey = 'bundled_tafsir_loaded';

  /// Initialize the tafsir service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize QuranLibrary
      await QuranLibrary.init();

      // Initialize DAO
      final database = await AppDatabase.instance.database;
      _tafsirDao = TafsirDao(database);
      _tafsirLocal = TafsirLocal(_tafsirDao);

      _isInitialized = true;
      print('TafsirService initialized successfully');

      // Load bundled tafsir on first run
      await _loadBundledTafsirIfNeeded();
    } catch (e) {
      print('Error initializing TafsirService: $e');
      rethrow;
    }
  }

  /// Load bundled tafsir if not already loaded
  Future<void> _loadBundledTafsirIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoaded = prefs.getBool(_bundledLoadedKey) ?? false;

      if (!isLoaded) {
        print('First run detected, loading bundled tafsir...');
        await _tafsirLocal.loadBundledTafsir();
        await prefs.setBool(_bundledLoadedKey, true);
        print('Bundled tafsir loaded and marked as complete');
      } else {
        print('Bundled tafsir already loaded, skipping');
      }
    } catch (e) {
      print('Error loading bundled tafsir: $e');
      // Don't rethrow, app can still function without bundled data
    }
  }

  /// Get list of available tafsir editions from API
  Future<List<TafsirEdition>> getAvailableTafsirs() async {
    if (!_isInitialized) await initialize();

    try {
      final tafsirs = await _api.getAvailableTafsirs();
      return tafsirs.map((t) => TafsirEdition.fromJson(t)).toList();
    } catch (e) {
      print('Error fetching available tafsirs: $e');
      return [];
    }
  }

  /// Download a complete tafsir edition and store it locally
  ///
  /// [edition]: Tafsir edition to download
  /// [onProgress]: Optional callback to report download progress (0.0 to 1.0)
  Future<bool> downloadTafsir(
    TafsirEdition edition, {
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('Downloading tafsir: ${edition.identifier}');
      onProgress?.call(0.0);

      // Download complete Quran data
      final data = await _api.downloadTafsir(edition.identifier);

      // Parse and prepare for database insertion
      final tafsirsToInsert = await _tafsirLocal.parseTafsirData(
        data,
        edition.language,
        edition.englishName,
        edition.identifier,
      );

      onProgress?.call(0.5);

      // Batch insert into database
      print('Inserting ${tafsirsToInsert.length} tafsir verses');
      await _tafsirDao.insertBatch(tafsirsToInsert);

      onProgress?.call(1.0);
      print('Tafsir download completed: ${edition.identifier}');
      return true;
    } catch (e) {
      print('Error downloading tafsir: $e');
      return false;
    }
  }

  /// Get tafsir for a specific verse by edition identifier
  Future<String?> getTafsirByEdition({
    required int surahNumber,
    required int ayahNumber,
    required String editionIdentifier,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Check if this edition is downloaded
      final isDownloaded =
          await _tafsirDao.isEditionDownloaded(editionIdentifier);

      if (isDownloaded) {
        // Get from database
        final results =
            await AppDatabase.instance.database.then((db) => db.query(
                  'tafsir',
                  where:
                      'surah_number = ? AND ayah_number = ? AND edition_identifier = ?',
                  whereArgs: [surahNumber, ayahNumber, editionIdentifier],
                  limit: 1,
                ));

        if (results.isNotEmpty) {
          return results.first['text'] as String?;
        }
      }

      return 'Tafsir not available. Please download from Downloads screen.';
    } catch (e) {
      print('Error getting tafsir by edition: $e');
      return null;
    }
  }

  /// Get all tafsirs for a specific verse
  Future<List<Map<String, dynamic>>> getAllTafsirs({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.getAllTafsirs(surahNumber, ayahNumber);
  }

  /// Check if a tafsir edition is downloaded
  Future<bool> isTafsirDownloaded(String editionIdentifier) async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.isEditionDownloaded(editionIdentifier);
  }

  /// Get list of all downloaded tafsir edition identifiers
  Future<List<String>> getDownloadedTafsirs() async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.getDownloadedEditions();
  }

  /// Delete a downloaded tafsir edition
  Future<bool> deleteTafsir(String editionIdentifier) async {
    if (!_isInitialized) await initialize();

    try {
      // Prevent deletion of bundled tafsir
      if (editionIdentifier == 'ar.muyassar') {
        print('Cannot delete bundled tafsir: $editionIdentifier');
        return false;
      }

      final count = await _tafsirDao.deleteByEdition(editionIdentifier);
      return count > 0;
    } catch (e) {
      print('Error deleting tafsir: $e');
      return false;
    }
  }

  /// Check if an edition is bundled with the app
  bool isBundledEdition(String editionIdentifier) {
    return editionIdentifier == 'ar.muyassar';
  }
}
