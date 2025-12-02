// lib/core/services/tafsir_service.dart
import 'package:quran_library/quran_library.dart';
import 'package:quran_app/core/database/dao/tafsir_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/alquran_api.dart';

class TafsirService {
  static final TafsirService instance = TafsirService._init();
  TafsirService._init();

  late TafsirDao _tafsirDao;
  final AlQuranApi _api = AlQuranApi();
  bool _isInitialized = false;

  /// Initialize the tafsir service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize QuranLibrary
      await QuranLibrary.init();

      // Initialize DAO
      final database = await AppDatabase.instance.database;
      _tafsirDao = TafsirDao(database);

      _isInitialized = true;
      print('TafsirService initialized successfully');
    } catch (e) {
      print('Error initializing TafsirService: $e');
      rethrow;
    }
  }

  /// Get available tafsir editions from AlQuran.cloud API
  Future<List<Map<String, dynamic>>> getAvailableTafsirs({
    String? language,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getEditions(
        format: 'text',
        language: language,
        type: 'tafsir',
      );
    } catch (e) {
      print('Error fetching available tafsirs: $e');
      return [];
    }
  }

  /// Download a complete tafsir edition and store it locally
  ///
  /// [editionIdentifier]: e.g., 'ar.muyassar', 'en.ahmedali'
  /// [onProgress]: Optional callback to report download progress
  Future<bool> downloadTafsir(
    String editionIdentifier, {
    Function(int currentSurah, int totalSurahs)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('Downloading tafsir: $editionIdentifier');

      // Download all 114 surahs
      for (int surahNumber = 1; surahNumber <= 114; surahNumber++) {
        onProgress?.call(surahNumber, 114);

        final surahData = await _api.getSurah(surahNumber, editionIdentifier);
        final ayahs = surahData['ayahs'] as List<dynamic>;

        // Prepare batch data
        final tafsirs = <Map<String, dynamic>>[];
        for (final ayah in ayahs) {
          tafsirs.add({
            'surah_number': surahNumber,
            'ayah_number': ayah['numberInSurah'],
            'language': surahData['edition']['language'] ?? 'unknown',
            'scholar': surahData['edition']['englishName'] ?? '',
            'edition_identifier': editionIdentifier,
            'text': ayah['text'],
          });
        }

        // Insert batch for this surah
        await _tafsirDao.insertBatch(tafsirs);
      }

      print('Tafsir download completed: $editionIdentifier');
      return true;
    } catch (e) {
      print('Error downloading tafsir: $e');
      return false;
    }
  }

  /// Get tafsir for a specific verse
  /// Returns from database if exists, otherwise returns placeholder
  Future<String?> getTafsir({
    required int surahNumber,
    required int ayahNumber,
    required String language,
    String? scholar,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // First, check database
      final cached = await _tafsirDao.getTafsir(
        surahNumber,
        ayahNumber,
        language,
        scholar,
      );

      if (cached != null) {
        return cached['text'] as String?;
      }

      // For now, return a placeholder since we need to download
      return 'Tafsir not available offline. Please download from Downloads screen.';
    } catch (e) {
      print('Error getting tafsir: $e');
      return null;
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

      // Not in database, fetch from API directly
      try {
        final ayahData = await _api.getAyah(
          AlQuranApi.formatAyahReference(surahNumber, ayahNumber),
          editionIdentifier,
        );
        return ayahData['text'] as String?;
      } catch (e) {
        return 'Tafsir not available. Please download from Downloads screen.';
      }
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

  /// Get list of all downloaded tafsir editions
  Future<List<String>> getDownloadedTafsirs() async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.getDownloadedEditions();
  }

  /// Delete a downloaded tafsir edition
  Future<bool> deleteTafsir(String editionIdentifier) async {
    if (!_isInitialized) await initialize();

    try {
      final count = await _tafsirDao.deleteByEdition(editionIdentifier);
      return count > 0;
    } catch (e) {
      print('Error deleting tafsir: $e');
      return false;
    }
  }

  /// Get list of available scholars/tafsir sources
  List<String> getAvailableScholars() {
    return [
      'Ibn Kathir',
      'Al-Jalalayn',
      'Al-Tabari',
      'Al-Muyassar',
    ];
  }

  /// Get list of available languages for tafsir
  List<String> getAvailableLanguages() {
    return [
      'Arabic',
      'English',
      'Indonesian',
      'Urdu',
    ];
  }

  /// Get list of available tafsirs from quran_library (if any)
  Future<List<dynamic>> getAvailableTafsirList() async {
    if (!_isInitialized) await initialize();

    try {
      final list = QuranLibrary().tafsirList;
      return list ?? [];
    } catch (e) {
      print('Error getting tafsir list: $e');
      return [];
    }
  }

  /// Download a tafsir using quran_library (legacy support)
  Future<void> downloadTafsirLegacy(int tafsirIndex) async {
    if (!_isInitialized) await initialize();

    try {
      await QuranLibrary().tafsirDownload(tafsirIndex);
      print('Tafsir downloaded at index: $tafsirIndex');
    } catch (e) {
      print('Error downloading tafsir: $e');
    }
  }

  /// Check if a tafsir is downloaded using quran_library (legacy support)
  Future<bool> isTafsirDownloadedLegacy(int index) async {
    if (!_isInitialized) await initialize();

    try {
      final downloaded = QuranLibrary().getTafsirDownloaded(index);
      return downloaded ?? false;
    } catch (e) {
      print('Error checking tafsir download status: $e');
      return false;
    }
  }
}
