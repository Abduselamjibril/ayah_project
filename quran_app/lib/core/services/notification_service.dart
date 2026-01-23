// lib/core/services/notification_service.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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

    tz.initializeTimeZones();
    await _configureLocalTimeZone();

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
      await android?.createNotificationChannel(_dailyChannel);
    }

    _initialized = true;
  }

  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  static const AndroidNotificationChannel _dailyChannel =
      AndroidNotificationChannel(
    'daily_verse_channel',
    'Daily Verse',
    description: 'Daily verse of the day notifications',
    importance: Importance.defaultImportance,
    playSound: true,
  );

  Future<void> scheduleDailyNotification(TimeOfDay time) async {
    await cancelDailyNotification();

    const androidDetails = AndroidNotificationDetails(
      'daily_verse_channel',
      'Daily Verse',
      channelDescription: 'Daily verse of the day notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    await _plugin.zonedSchedule(
      888, // ID for daily notification
      'Verse of the Day',
      'Tap to read today\'s verse',
      scheduledDate,
      details,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyNotification() async {
    await _plugin.cancel(888);
  }

  Future<bool> canScheduleExactAlarms() async {
    if (kIsWeb) return false;
    if (!Platform.isAndroid) return true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? true;
  }

  Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    const intent = AndroidIntent(
      action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
    );
    await intent.launch();
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
