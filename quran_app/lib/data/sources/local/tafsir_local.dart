// lib/data/sources/local/tafsir_local.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/database/dao/tafsir_dao.dart';

/// Local data source for tafsir (handles bundled assets)
class TafsirLocal {
  final TafsirDao _tafsirDao;

  TafsirLocal(this._tafsirDao);

  /// Load and import bundled Arabic tafsir (ar.muyassar.json)
  Future<void> loadBundledTafsir() async {
    try {
      print('Loading bundled tafsir: ar.muyassar.json');

      // Load JSON from assets
      final jsonString =
          await rootBundle.loadString('assets/Data/ar.muyassar.json');
      final jsonData = json.decode(jsonString);

      // Parse the data structure
      final data = jsonData['data'];
      final surahs = data['surahs'] as List;

      // Prepare batch data for database insertion
      final List<Map<String, dynamic>> tafsirsToInsert = [];

      for (final surah in surahs) {
        final surahNumber = surah['number'] as int;
        final ayahs = surah['ayahs'] as List;

        for (final ayah in ayahs) {
          final ayahNumber = ayah['numberInSurah'] as int;
          final text = ayah['text'] as String;

          tafsirsToInsert.add({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'language': 'ar',
            'scholar': 'King Fahad Quran Complex',
            'edition_identifier': 'ar.muyassar',
            'text': text,
          });
        }
      }

      // Batch insert into database
      print('Inserting ${tafsirsToInsert.length} tafsir verses into database');
      await _tafsirDao.insertBatch(tafsirsToInsert);
      print('Bundled tafsir loaded successfully');
    } catch (e) {
      print('Error loading bundled tafsir: $e');
      rethrow;
    }
  }

  /// Check if bundled tafsir is already loaded
  Future<bool> isBundledTafsirLoaded() async {
    return await _tafsirDao.isEditionDownloaded('ar.muyassar');
  }

  /// Parse downloaded tafsir data and prepare for database insertion
  Future<List<Map<String, dynamic>>> parseTafsirData(
    Map<String, dynamic> data,
    String language,
    String scholar,
    String editionIdentifier,
  ) async {
    try {
      final surahs = data['surahs'] as List;
      final List<Map<String, dynamic>> tafsirsToInsert = [];

      for (final surah in surahs) {
        final surahNumber = surah['number'] as int;
        final ayahs = surah['ayahs'] as List;

        for (final ayah in ayahs) {
          final ayahNumber = ayah['numberInSurah'] as int;
          final text = ayah['text'] as String;

          tafsirsToInsert.add({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'language': language,
            'scholar': scholar,
            'edition_identifier': editionIdentifier,
            'text': text,
          });
        }
      }

      return tafsirsToInsert;
    } catch (e) {
      print('Error parsing tafsir data: $e');
      rethrow;
    }
  }
}
