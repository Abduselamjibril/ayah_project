// lib/core/database/dao/tafsir_dao.dart
import 'package:sqflite/sqflite.dart';

class TafsirDao {
  final Database database;

  TafsirDao(this.database);

  /// Insert a tafsir into the database
  Future<int> insertTafsir(Map<String, dynamic> tafsir) async {
    try {
      return await database.insert(
        'tafsir',
        tafsir,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting tafsir: $e');
      rethrow;
    }
  }

  /// Get tafsir for a specific verse
  Future<Map<String, dynamic>?> getTafsir(
    int surahNumber,
    int ayahNumber,
    String language, [
    String? scholar,
  ]) async {
    try {
      final List<Map<String, dynamic>> results;

      if (scholar != null) {
        results = await database.query(
          'tafsir',
          where:
              'surah_number = ? AND ayah_number = ? AND language = ? AND scholar = ?',
          whereArgs: [surahNumber, ayahNumber, language, scholar],
          limit: 1,
        );
      } else {
        results = await database.query(
          'tafsir',
          where: 'surah_number = ? AND ayah_number = ? AND language = ?',
          whereArgs: [surahNumber, ayahNumber, language],
          limit: 1,
        );
      }

      return results.isNotEmpty ? results.first : null;
    } catch (e) {
      print('Error getting tafsir: $e');
      return null;
    }
  }

  /// Get all tafsirs for a specific verse
  Future<List<Map<String, dynamic>>> getAllTafsirs(
    int surahNumber,
    int ayahNumber,
  ) async {
    try {
      return await database.query(
        'tafsir',
        where: 'surah_number = ? AND ayah_number = ?',
        whereArgs: [surahNumber, ayahNumber],
      );
    } catch (e) {
      print('Error getting all tafsirs: $e');
      return [];
    }
  }

  /// Delete a tafsir
  Future<int> deleteTafsir(int id) async {
    try {
      return await database.delete(
        'tafsir',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('Error deleting tafsir: $e');
      return 0;
    }
  }

  /// Check if a tafsir exists
  Future<bool> tafsirExists(
    int surahNumber,
    int ayahNumber,
    String language, [
    String? scholar,
  ]) async {
    try {
      final result = await getTafsir(
        surahNumber,
        ayahNumber,
        language,
        scholar,
      );
      return result != null;
    } catch (e) {
      print('Error checking tafsir existence: $e');
      return false;
    }
  }

  /// Get all available languages for tafsir
  Future<List<String>> getAvailableLanguages() async {
    try {
      final results = await database.rawQuery(
        'SELECT DISTINCT language FROM tafsir ORDER BY language',
      );
      return results.map((row) => row['language'] as String).toList();
    } catch (e) {
      print('Error getting available languages: $e');
      return [];
    }
  }

  /// Get all scholars for a specific language
  Future<List<String>> getScholarsForLanguage(String language) async {
    try {
      final results = await database.rawQuery(
        'SELECT DISTINCT scholar FROM tafsir WHERE language = ? ORDER BY scholar',
        [language],
      );
      return results.map((row) => row['scholar'] as String).toList();
    } catch (e) {
      print('Error getting scholars: $e');
      return [];
    }
  }

  /// Clear all tafsirs
  Future<int> clearAllTafsirs() async {
    try {
      return await database.delete('tafsir');
    } catch (e) {
      print('Error clearing tafsirs: $e');
      return 0;
    }
  }

  /// Insert multiple tafsirs in a batch (efficient for downloads)
  Future<void> insertBatch(List<Map<String, dynamic>> tafsirs) async {
    try {
      final batch = database.batch();
      for (final tafsir in tafsirs) {
        batch.insert(
          'tafsir',
          tafsir,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('Error batch inserting tafsirs: $e');
      rethrow;
    }
  }

  /// Delete all tafsirs for a specific edition (identifier)
  Future<int> deleteByEdition(String editionIdentifier) async {
    try {
      return await database.delete(
        'tafsir',
        where: 'edition_identifier = ?',
        whereArgs: [editionIdentifier],
      );
    } catch (e) {
      print('Error deleting tafsirs by edition: $e');
      return 0;
    }
  }

  /// Check if a specific edition is downloaded
  Future<bool> isEditionDownloaded(String editionIdentifier) async {
    try {
      final results = await database.query(
        'tafsir',
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
        'SELECT DISTINCT edition_identifier FROM tafsir ORDER BY edition_identifier',
      );
      return results.map((row) => row['edition_identifier'] as String).toList();
    } catch (e) {
      print('Error getting downloaded editions: $e');
      return [];
    }
  }
}
