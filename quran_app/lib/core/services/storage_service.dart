import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'audio_service.dart';
import 'tafsir_service.dart';
import 'translation_service.dart';

class StorageUsage {
  final int cacheBytes;
  final int dataBytes;

  const StorageUsage({required this.cacheBytes, required this.dataBytes});

  int get totalBytes => cacheBytes + dataBytes;

  double get cacheFraction => totalBytes == 0 ? 0 : cacheBytes / totalBytes;

  double get dataFraction => totalBytes == 0 ? 0 : dataBytes / totalBytes;
}

class StorageService {
  static final StorageService instance = StorageService._();
  StorageService._();

  Future<StorageUsage> getUsage() async {
    final cacheDir = await getTemporaryDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final documentsDir = await getApplicationDocumentsDirectory();
    final dbPath = await sqflite.getDatabasesPath();

    final cacheBytes = await _dirSize(cacheDir);

    final supportBytes = await _dirSize(supportDir);
    final documentsBytes = await _dirSize(documentsDir);

    int dbBytes = 0;
    if (!_isSubPath(dbPath, supportDir.path) &&
        !_isSubPath(dbPath, documentsDir.path)) {
      dbBytes = await _dirSize(Directory(dbPath));
    }

    return StorageUsage(
      cacheBytes: cacheBytes,
      dataBytes: supportBytes + documentsBytes + dbBytes,
    );
  }

  Future<void> clearCache() async {
    final dir = await getTemporaryDirectory();
    if (!await dir.exists()) return;

    await for (final entity in dir.list(followLinks: false)) {
      try {
        await entity.delete(recursive: true);
      } catch (_) {
        // Best-effort cleanup.
      }
    }
  }

  Future<void> clearDownloadedData() async {
    final translationService = TranslationService.instance;
    final tafsirService = TafsirService.instance;
    final audioService = AudioService.instance;

    final translations = await translationService.getDownloadedTranslations();
    for (final id in translations) {
      await translationService.deleteTranslation(id);
    }
    translationService.clearMemoryCache();

    final tafsirs = await tafsirService.getDownloadedTafsirs();
    for (final id in tafsirs) {
      await tafsirService.deleteTafsir(id);
    }

    await audioService.initialize();
    final recitations = await audioService.getDownloadedRecitationIds();
    for (final id in recitations) {
      await audioService.deleteRecitation(id);
    }

    await _clearDownloadProgressPrefs();
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double value = bytes.toDouble();
    int unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex++;
    }
    final precision = value >= 10 || value == value.floorToDouble() ? 0 : 1;
    return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
  }

  Future<int> _dirSize(Directory dir) async {
    if (!await dir.exists()) return 0;

    int total = 0;
    final stack = <Directory>[dir];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final entries = await current.list(followLinks: false).toList();
      for (final entry in entries) {
        if (entry is File) {
          try {
            total += await entry.length();
          } catch (_) {
            // Skip files that cannot be read.
          }
        } else if (entry is Directory) {
          stack.add(entry);
        }
      }
    }
    return total;
  }

  bool _isSubPath(String path, String root) {
    if (path.isEmpty || root.isEmpty) return false;
    final normalizedPath = path.replaceAll('\\', '/');
    final normalizedRoot = root.replaceAll('\\', '/');
    return normalizedPath == normalizedRoot ||
        normalizedPath.startsWith('$normalizedRoot/');
  }

  Future<void> _clearDownloadProgressPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs
        .getKeys()
        .where((key) => key.startsWith('translation_download_progress_'))
        .toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}
