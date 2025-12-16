// lib/core/services/tafsir_service.dart
import 'package:quran_app/core/database/dao/tafsir_dao.dart';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/data/sources/remote/tafsir_api.dart';

import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirService {
  static final TafsirService instance = TafsirService._init();
  TafsirService._init();

  late TafsirDao _tafsirDao;
  final TafsirApi _api = TafsirApi();
  bool _isInitialized = false;

  static const String _selectedTafsirKey = 'selected_tafsir_id';

  /// Initialize the tafsir service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
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

  /// Get list of available tafsir editions from API
  Future<List<TafsirEdition>> getAvailableTafsirs() async {
    if (!_isInitialized) await initialize();

    try {
      return await _api.getAvailableTafsirs();
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
      print('Downloading tafsir: ${edition.id} (${edition.name})');
      onProgress?.call(0.0);

      // Download complete Quran data
      // New API returns a list of TafsirAyah directly
      final ayahs = await _api.downloadTafsir(
        edition.id,
        onProgress: (current, total) {
          // Calculate progress based on surahs downloaded
          // We allocate 90% of progress to downloading, 10% to inserting
          final downloadProgress = (current / total) * 0.9;
          onProgress?.call(downloadProgress);
        },
      );

      print('Converting ${ayahs.length} verses for database insertion');
      final tafsirsToInsert = ayahs.map((ayah) {
        return ayah.toDatabase(
          language: edition.languageName,
          scholar: edition.authorName, // Using authorName as scholar
        );
      }).toList();

      onProgress?.call(0.95);

      // Batch insert into database
      print('Inserting ${tafsirsToInsert.length} tafsir verses');
      await _tafsirDao.insertBatch(tafsirsToInsert);

      // Set as selected if none is selected
      final currentSelected = await getSelectedTafsirId();
      if (currentSelected == null) {
        await setSelectedTafsirId(edition.id);
      }

      onProgress?.call(1.0);
      print('Tafsir download completed: ${edition.id}');
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
      final count = await _tafsirDao.deleteByEdition(editionIdentifier);

      // If deleted was selected, clear selection
      final selectedId = await getSelectedTafsirId();
      if (selectedId.toString() == editionIdentifier) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_selectedTafsirKey);
      }

      return count > 0;
    } catch (e) {
      print('Error deleting tafsir: $e');
      return false;
    }
  }

  /// Check if an edition is bundled with the app
  bool isBundledEdition(String editionIdentifier) {
    return false; // No bundled editions anymore
  }

  // User Selection Persistence

  /// Get the selected tafsir ID (returns int ID of the resource)
  Future<int?> getSelectedTafsirId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_selectedTafsirKey);
  }

  /// Set the selected tafsir ID
  Future<void> setSelectedTafsirId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_selectedTafsirKey, id);
    print('Selected tafsir set to: $id');
  }

  /// Get full details of the selected tafsir
  /// Returns null if no tafsir is selected or if metadata fetch fails
  Future<TafsirEdition?> getSelectedTafsir() async {
    final id = await getSelectedTafsirId();
    if (id == null) return null;

    // Fetch all tafsirs to find the selected one
    final allTafsirs = await getAvailableTafsirs();
    try {
      return allTafsirs.firstWhere((e) => e.id == id);
    } catch (e) {
      return null;
    }
  }
}
