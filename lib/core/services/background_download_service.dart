// lib/core/services/background_download_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

typedef ProgressCallback = void Function(double progress);

class BackgroundDownloadService {
  BackgroundDownloadService._();
  static final instance = BackgroundDownloadService._();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true; // flutter_downloader not supported on web
      return;
    }
    await FlutterDownloader.initialize(debug: false, ignoreSsl: true);
    _initialized = true;
  }

  Future<bool> isBackgroundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('download_background') ?? true;
  }

  Future<String?> enqueue({
    required String url,
    required String fileName,
  }) async {
    if (kIsWeb) return null;
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    // Enqueue with notification on Android; iOS requires foreground for reliability
    final taskId = await FlutterDownloader.enqueue(
      url: url,
      fileName: fileName,
      savedDir: await _defaultSaveDir(),
      showNotification: true,
      openFileFromNotification: true,
    );
    return taskId;
  }

  Future<String> _defaultSaveDir() async {
    try {
      final dir = Platform.isAndroid || Platform.isIOS
          ? await getApplicationSupportDirectory()
          : await getDownloadsDirectory() ??
              await getApplicationSupportDirectory();
      final downloadsDir =
          Directory('${dir.path}${Platform.pathSeparator}downloads');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      return downloadsDir.path;
    } catch (_) {
      return '';
    }
  }

  static void registerCallback() {
    if (kIsWeb) return;
    FlutterDownloader.registerCallback(_callback);
  }

  // flutter_downloader (newer versions) uses ints for status
  // Status values: 1 enqueued, 2 running, 3 complete, 4 failed, 5 canceled, 6 paused
  @pragma('vm:entry-point')
  static void _callback(String id, int status, int progress) async {
    // Ensure notifications are initialized in isolate
    await AppNotificationService.instance.initialize();
    await AppNotificationService.instance.requestPermissionsIfNeeded();
    const title = 'Download';
    if (status == 3) {
      await AppNotificationService.instance
          .complete(id.hashCode & 0x7fffffff, title, success: true);
    } else if (status == 4) {
      await AppNotificationService.instance
          .complete(id.hashCode & 0x7fffffff, title, success: false);
    }
  }
}
