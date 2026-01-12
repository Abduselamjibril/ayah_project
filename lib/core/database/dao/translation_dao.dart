// lib/core/database/dao/translation_dao.dart
import 'package:sqflite/sqflite.dart';

class TranslationDao {
  final Database database;

  TranslationDao(this.database);

  /// Insert a translation into the database
  Future<int> insertTranslation(Map<String, dynamic> translation) async {
    try {
      return await database.insert(
        'translations',
        translation,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting translation: $e');
      rethrow;
    }
  }

  /// Get translation for a specific verse
  Future<Map<String, dynamic>?> getTranslation(
    int surahNumber,
    int ayahNumber,
    String language, [
    String? translator,
  ]) async {
    try {
      final List<Map<String, dynamic>> results;

      if (translator != null) {
        results = await database.query(
          'translations',
          where:
              'surah_number = ? AND ayah_number = ? AND language = ? AND translator = ?',
          whereArgs: [surahNumber, ayahNumber, language, translator],
          limit: 1,
        );
      } else {
        results = await database.query(
          'translations',
          where: 'surah_number = ? AND ayah_number = ? AND language = ?',
          whereArgs: [surahNumber, ayahNumber, language],
          limit: 1,
        );
      }

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting translation: $e');
      return null;
    }
  }

  /// Get all translations for a specific verse
  Future<List<Map<String, dynamic>>> getAllTranslations(
    int surahNumber,
    int ayahNumber,
  ) async {
    try {
      return await database.query(
        'translations',
        where: 'surah_number = ? AND ayah_number = ?',
        whereArgs: [surahNumber, ayahNumber],
      );
    } catch (e) {
      print('Error getting all translations: $e');
      return [];
    }
  }

  /// Delete a translation
  Future<int> deleteTranslation(int id) async {
    try {
      return await database.delete(
        'translations',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting translation: $e');
      return 0;
    }
  }

  /// Check if a translation exists
  Future<bool> translationExists(
    int surahNumber,
    int ayahNumber,
    String language, [
    String? translator,
  ]) async {
    try {
      final result = await getTranslation(
        surahNumber,
        ayahNumber,
        language,
        translator,
      );
      return result != null;
    } catch (e) {
      print('Error checking translation existence: $e');
      return false;
    }
  }

  /// Get all available languages for translations
  Future<List<String>> getAvailableLanguages() async {
    try {
      final results = await database.rawQuery(
        'SELECT DISTINCT language FROM translations ORDER BY language',
      );
      return results.map((row) => row['language'] as String).toList();
    } catch (e) {
      print('Error getting available languages: $e');
      return [];
    }
  }

  /// Get all translators for a specific language
  Future<List<String>> getTranslatorsForLanguage(String language) async {
    try {
      final results = await database.rawQuery(
        'SELECT DISTINCT translator FROM translations WHERE language = ? ORDER BY translator',
        [language],
      );
      return results.map((row) => row['translator'] as String).toList();
    } catch (e) {
      print('Error getting translators: $e');
      return [];
    }
  }

  /// Clear all translations
  Future<int> clearAllTranslations() async {
    try {
      return await database.delete('translations');
    } catch (e) {
      print('Error clearing translations: $e');
      return 0;
    }
  }

  /// Insert multiple translations in a batch (efficient for downloads)
  Future<void> insertBatch(List<Map<String, dynamic>> translations) async {
    try {
      final batch = database.batch();
      for (final translation in translations) {
        batch.insert(
          'translations',
          translation,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Error batch inserting translations: $e');
      rethrow;
    }
  }

  /// Delete all translations for a specific edition (identifier)
  /// This is useful when user wants to remove a downloaded translation
  Future<int> deleteByEdition(String editionIdentifier) async {
    try {
      return await database.delete(
        'translations',
        where: 'edition_identifier = ?',
        whereArgs: [editionIdentifier],
      );
    } catch (e) {
      print('Error deleting translations by edition: $e');
      return 0;
    }
  }

  /// Check if a specific edition is downloaded (has any translations)
  Future<bool> isEditionDownloaded(String editionIdentifier) async {
    try {
      final results = await database.query(
        'translations',
        where: 'edition_identifier = ?',
        whereArgs: [editionIdentifier],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      print('Error checking edition download status: $e');
      return false;
    }
  }

  /// Get list of all downloaded edition identifiers
  Future<List<String>> getDownloadedEditions() async {
    try {
      final results = await database.rawQuery(
        'SELECT DISTINCT edition_identifier FROM translations WHERE edition_identifier IS NOT NULL ORDER BY edition_identifier',
      );
      final editions = results
          .map((row) => row['edition_identifier'] as String)
          .where((id) => id.isNotEmpty) // Also filter out empty strings
          .toList();
      print(
          'TranslationDao.getDownloadedEditions: Found ${editions.length} editions: $editions');
      return editions;
    } catch (e) {
      print('Error getting downloaded editions: $e');
      return [];
    }
  }
}
