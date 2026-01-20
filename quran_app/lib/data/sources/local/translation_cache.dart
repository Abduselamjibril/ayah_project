// lib/data/sources/local/translation_cache.dart
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache manager for translation API responses
/// Caches languages list and editions to reduce network calls
class TranslationCache {
  static const String _languagesCacheKey = 'cached_languages';
  static const String _languagesTimestampKey = 'cached_languages_timestamp';
  static const String _editionsPrefix = 'cached_editions_';
  static const String _timestampPrefix = 'cached_timestamp_';

  // Cache duration: 7 days
  static const Duration _cacheDuration = Duration(days: 7);

  /// Get cache directory path
  Future<String> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/translation_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  /// Check if cache is valid (not expired)
  Future<bool> _isCacheValid(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(timestampKey);

      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) < _cacheDuration;
    } catch (e) {
      print('Error checking cache validity: $e');
      return false;
    }
  }

  /// Save timestamp for cache entry
  Future<void> _saveTimestamp(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error saving cache timestamp: $e');
    }
  }

  /// Get cached languages list
  /// Returns null if cache doesn't exist or is expired
  Future<List<String>?> getCachedLanguages() async {
    try {
      // Check if cache is valid
      if (!await _isCacheValid(_languagesTimestampKey)) {
        print('Languages cache expired or not found');
        return null;
      }

      final dir = await _cacheDir;
      final file = File('$dir/languages.json');

      if (!await file.exists()) {
        print('Languages cache file not found');
        return null;
      }

      final json = await file.readAsString();
      final data = jsonDecode(json) as List;
      print('Loaded ${data.length} languages from cache');
      return List<String>.from(data);
    } catch (e) {
      print('Error reading cached languages: $e');
      return null;
    }
  }

  /// Cache languages list
  Future<void> cacheLanguages(List<String> languages) async {
    try {
      final dir = await _cacheDir;
      final file = File('$dir/languages.json');

      await file.writeAsString(jsonEncode(languages));
      await _saveTimestamp(_languagesTimestampKey);

      print('Cached ${languages.length} languages');
    } catch (e) {
      print('Error caching languages: $e');
    }
  }

  /// Get cached editions for a specific language
  /// Returns null if cache doesn't exist or is expired
  Future<List<Map<String, dynamic>>?> getCachedEditions(
      String languageCode) async {
    try {
      final timestampKey = '$_timestampPrefix$languageCode';

      // Check if cache is valid
      if (!await _isCacheValid(timestampKey)) {
        print('Editions cache for $languageCode expired or not found');
        return null;
      }

      final dir = await _cacheDir;
      final file = File('$dir/editions_$languageCode.json');

      if (!await file.exists()) {
        print('Editions cache file for $languageCode not found');
        return null;
      }

      final json = await file.readAsString();
      final data = jsonDecode(json) as List;
      print('Loaded ${data.length} editions for $languageCode from cache');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('Error reading cached editions for $languageCode: $e');
      return null;
    }
  }

  /// Cache editions for a specific language
  Future<void> cacheEditions(
    String languageCode,
    List<Map<String, dynamic>> editions,
  ) async {
    try {
      final dir = await _cacheDir;
      final file = File('$dir/editions_$languageCode.json');

      await file.writeAsString(jsonEncode(editions));
      await _saveTimestamp('$_timestampPrefix$languageCode');

      print('Cached ${editions.length} editions for $languageCode');
    } catch (e) {
      print('Error caching editions for $languageCode: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final dir = await _cacheDir;
      final cacheDir = Directory(dir);

      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('Cleared translation cache');
      }

      // Clear timestamps from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_languagesTimestampKey);

      // Clear all edition timestamps (we don't know all language codes, so this is best effort)
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_timestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get cache size in bytes
  Future<int> getCacheSize() async {
    try {
      final dir = await _cacheDir;
      final cacheDir = Directory(dir);

      if (!await cacheDir.exists()) return 0;

      int totalSize = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating cache size: $e');
      return 0;
    }
  }
}
