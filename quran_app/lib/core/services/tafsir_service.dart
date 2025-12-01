// lib/core/services/tafsir_service.dart
import 'package:quran_library/quran_library.dart';
import 'package:quran_app/core/database/dao/tafsir_dao.dart';
import 'package:quran_app/core/database/app_database.dart';

class TafsirService {
  static final TafsirService instance = TafsirService._init();
  TafsirService._init();

  late TafsirDao _tafsirDao;
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

      // For now, return a placeholder since quran_library requires download
      return 'Tafsir not available offline. Please download tafsir from settings.';
    } catch (e) {
      print('Error getting tafsir: $e');
      return null;
    }
  }

  /// Get all tafsir for a specific verse
  Future<List<Map<String, dynamic>>> getAllTafsirs({
    required int surahNumber,
    required int ayahNumber,
  }) async {
    if (!_isInitialized) await initialize();
    return await _tafsirDao.getAllTafsirs(surahNumber, ayahNumber);
  }

  /// Get list of available scholars/tafsir sources
  List<String> getAvailableScholars() {
    return [
      'Ibn Kathir',
      'Al-Jalalayn',
      'Al-Tabari',
    ];
  }

  /// Get list of available languages for tafsir
  List<String> getAvailableLanguages() {
    return [
      'Arabic',
      'English',
    ];
  }

  /// Download a tafsir
  /// Note: This uses quran_library's tafsirDownload method
  Future<void> downloadTafsir(int tafsirIndex) async {
    if (!_isInitialized) await initialize();

    try {
      await QuranLibrary().tafsirDownload(tafsirIndex);
      print('Tafsir downloaded at index: $tafsirIndex');
    } catch (e) {
      print('Error downloading tafsir: $e');
    }
  }

  /// Get list of available tafsirs from quran_library
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

  /// Check if a tafsir is downloaded
  Future<bool> isTafsirDownloaded(int index) async {
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
