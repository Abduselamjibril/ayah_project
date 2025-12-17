// lib/core/services/notification_service.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AppNotificationService {
  AppNotificationService._();
  static final instance = AppNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _downloadChannel =
      AndroidNotificationChannel(
    'downloads_channel',
    'Downloads',
    description: 'Shows download progress and status',
    importance: Importance.low,
    showBadge: false,
  );

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _plugin.initialize(initSettings);

    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_downloadChannel);
    }

    _initialized = true;
  }

  Future<bool> requestPermissionsIfNeeded() async {
    if (kIsWeb) return false; // Web notifications not implemented here
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
              alert: true, badge: true, sound: true) ??
          false;
      return granted;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ??
          true; // Android pre-13 returns true
      return granted;
    }
    return true; // Other platforms
  }

  NotificationDetails _progressDetails() {
    final android = AndroidNotificationDetails(
      _downloadChannel.id,
      _downloadChannel.name,
      channelDescription: _downloadChannel.description,
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      ongoing: true,
      maxProgress: 100,
      playSound: false,
    );
    const ios = DarwinNotificationDetails(
        presentAlert: false, presentBadge: false, presentSound: false);
    return NotificationDetails(android: android, iOS: ios);
  }

  NotificationDetails _completeDetails() {
    final android = AndroidNotificationDetails(
      _downloadChannel.id,
      _downloadChannel.name,
      channelDescription: _downloadChannel.description,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const ios = DarwinNotificationDetails();
    return NotificationDetails(android: android, iOS: ios);
  }

  Future<void> showProgress(int id, String title, double progress01) async {
    final progress = (progress01 * 100).clamp(0, 100).round();
    await _plugin.show(
      id,
      title,
      'Downloading… $progress%',
      _progressDetails(),
      payload: 'download',
    );
  }

  Future<void> complete(int id, String title, {bool success = true}) async {
    await _plugin.show(
      id,
      title,
      success ? 'Download completed' : 'Download failed',
      _completeDetails(),
      payload: 'download_complete',
    );
    // Clear after short delay for progress notifications
    await Future.delayed(const Duration(seconds: 3));
    await _plugin.cancel(id);
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
