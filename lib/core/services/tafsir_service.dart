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

  Future<bool> downloadTafsir(
    TafsirEdition edition, {
    Function(double progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      print('=== DOWNLOAD START: Tafsir ${edition.id} (${edition.name}) ===');
      print(
          'Edition details: ID=${edition.id}, Language=${edition.languageName}, Author=${edition.authorName}');
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

      print('Downloaded ${ayahs.length} verses from API');

      // Sample first ayah to check resourceId
      if (ayahs.isNotEmpty) {
        print(
            'Sample ayah: ${ayahs.first.surahNumber}:${ayahs.first.ayahNumber}, resourceId=${ayahs.first.resourceId}');
      }

      final tafsirsToInsert = ayahs.map((ayah) {
        return ayah.toDatabase(
          language: edition.languageName,
          scholar: edition.authorName, // Using authorName as scholar
        );
      }).toList();

      // Sample first database entry
      if (tafsirsToInsert.isNotEmpty) {
        print(
            'Sample database entry: edition_identifier="${tafsirsToInsert.first['edition_identifier']}"');
        print(
            '  surah=${tafsirsToInsert.first['surah_number']}, ayah=${tafsirsToInsert.first['ayah_number']}');
        print(
            '  language="${tafsirsToInsert.first['language']}", scholar="${tafsirsToInsert.first['scholar']}"');
      }

      onProgress?.call(0.95);

      // Batch insert into database
      print(
          'Inserting ${tafsirsToInsert.length} tafsir verses into database...');
      await _tafsirDao.insertBatch(tafsirsToInsert);
      print('Database insertion complete');

      // Verify insertion
      final isDownloaded =
          await _tafsirDao.isEditionDownloaded(edition.id.toString());
      print(
          'Verification: isEditionDownloaded("${edition.id}") = $isDownloaded');

      // Set as selected if none is selected
      final currentSelected = await getSelectedTafsirId();
      print('Current selected tafsir ID: $currentSelected');
      if (currentSelected == null) {
        await setSelectedTafsirId(edition.id);
        print('Auto-selected tafsir ID: ${edition.id}');
      }

      onProgress?.call(1.0);
      print('=== DOWNLOAD COMPLETE: Tafsir ${edition.id} ===');
      return true;
    } catch (e) {
      print('ERROR downloading tafsir: $e');
      print('Stack trace: ${StackTrace.current}');
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
      print(
          'TafsirService: Getting tafsir for $surahNumber:$ayahNumber, edition: $editionIdentifier');

      // Check if this edition is downloaded
      final isDownloaded =
          await _tafsirDao.isEditionDownloaded(editionIdentifier);
      print('TafsirService: Edition downloaded status: $isDownloaded');

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

        print('TafsirService: Query results count: ${results.length}');
        if (results.isNotEmpty) {
          print(
              'TafsirService: Found tafsir text (${results.first['text'].toString().length} chars)');
          return results.first['text'] as String?;
        } else {
          print('TafsirService: No tafsir found for this ayah in database');
        }
      }

      print('TafsirService: Returning not available message');
      return 'Tafsir not available. Please download from Downloads screen.';
    } catch (e) {
      print('TafsirService ERROR getting tafsir by edition: $e');
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

  /// Get approximate size in bytes for a downloaded tafsir edition.
  Future<int> getTafsirSizeBytes(String editionIdentifier) async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.getEditionTextBytes(editionIdentifier);
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

  /// Provide a direct download URL for background downloads.
  /// Returns null if a single-file export is not available.
  String? getDownloadUrl(TafsirEdition edition) {
    return _api.buildDownloadUrlOrNull(edition.id);
  }
}
