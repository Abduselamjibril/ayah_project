// lib/data/sources/local/translation_local.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../core/database/dao/translation_dao.dart';

/// Local data source for translations (handles bundled assets)
class TranslationLocal {
  final TranslationDao _translationDao;

  TranslationLocal(this._translationDao);

  /// Load and import bundled English translation (en.asad.json)
  Future<void> loadBundledTranslation() async {
    try {
      print('Loading bundled translation: en.asad.json');

      // Load JSON from assets
      final jsonString =
          await rootBundle.loadString('assets/Data/en.asad.json');
      final jsonData = json.decode(jsonString);

      // Parse the data structure
      final data = jsonData['data'];
      final surahs = data['surahs'] as List;

      // Prepare batch data for database insertion
      final List<Map<String, dynamic>> translationsToInsert = [];

      for (final surah in surahs) {
        final surahNumber = surah['number'] as int;
        final ayahs = surah['ayahs'] as List;

        for (final ayah in ayahs) {
          final ayahNumber = ayah['numberInSurah'] as int;
          final text = ayah['text'] as String;

          translationsToInsert.add({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'language': 'en',
            'translator': 'Muhammad Asad',
            'edition_identifier': 'en.asad',
            'text': text,
          });
        }
      }

      // Batch insert into database
      print(
          'Inserting ${translationsToInsert.length} translation verses into database');
      await _translationDao.insertBatch(translationsToInsert);
      print('Bundled translation loaded successfully');
    } catch (e) {
      print('Error loading bundled translation: $e');
      rethrow;
    }
  }

  /// Check if bundled translation is already loaded
  Future<bool> isBundledTranslationLoaded() async {
    return await _translationDao.isEditionDownloaded('en.asad');
  }

  /// Parse downloaded translation data and prepare for database insertion
  Future<List<Map<String, dynamic>>> parseTranslationData(
    Map<String, dynamic> data,
    String language,
    String translator,
    String editionIdentifier,
  ) async {
    try {
      final surahs = data['surahs'] as List;
      final List<Map<String, dynamic>> translationsToInsert = [];

      for (final surah in surahs) {
        final surahNumber = surah['number'] as int;
        final ayahs = surah['ayahs'] as List;

        for (final ayah in ayahs) {
          final ayahNumber = ayah['numberInSurah'] as int;
          final text = ayah['text'] as String;

          translationsToInsert.add({
            'surah_number': surahNumber,
            'ayah_number': ayahNumber,
            'language': language,
            'translator': translator,
            'edition_identifier': editionIdentifier,
            'text': text,
          });
        }
      }

      return translationsToInsert;
    } catch (e) {
      print('Error parsing translation data: $e');
      rethrow;
    }
  }
}
