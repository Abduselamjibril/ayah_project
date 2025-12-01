import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatmah.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class KhatmahService {
  static const String _khatmahKey = 'current_khatmah';
  static const String _notifEnabledKey = 'khatmah_notif_enabled';
  static const String _notifHourKey = 'khatmah_notif_hour';
  static const String _notifMinuteKey = 'khatmah_notif_minute';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Android init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
  }

  Future<void> requestPermissions() async {
    if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
      // Exact alarms permission is usually handled by manifest, but good to check
    }
  }

  Future<Khatmah?> getCurrentKhatmah() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_khatmahKey);
    if (jsonString == null) return null;
    return Khatmah.fromJson(jsonDecode(jsonString));
  }

  Future<void> startKhatmah(int durationDays) async {
    final khatmah = Khatmah(
      id: DateTime.now().toIso8601String(),
      startDate: DateTime.now(),
      durationDays: durationDays,
    );
    await _saveKhatmah(khatmah);

    // Enable notifications by default when starting
    await setNotificationSettings(true, const TimeOfDay(hour: 20, minute: 0));
  }

  Future<void> updateProgress(int page) async {
    final khatmah = await getCurrentKhatmah();
    if (khatmah != null) {
      int newPage = page;
      if (page > khatmah.lastReadPage) {
        newPage = page;
      } else {
        newPage = khatmah.lastReadPage;
      }

      final updated = khatmah.copyWith(lastReadPage: newPage);
      await _saveKhatmah(updated);
    }
  }

  Future<void> deleteKhatmah() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_khatmahKey);
    await _notificationsPlugin.cancelAll();
  }

  Future<void> _saveKhatmah(Khatmah khatmah) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_khatmahKey, jsonEncode(khatmah.toJson()));
  }

  // Settings Methods

  Future<Map<String, dynamic>> getNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'enabled': prefs.getBool(_notifEnabledKey) ?? false,
      'hour': prefs.getInt(_notifHourKey) ?? 20,
      'minute': prefs.getInt(_notifMinuteKey) ?? 0,
    };
  }

  Future<void> setNotificationSettings(bool enabled, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifEnabledKey, enabled);
    await prefs.setInt(_notifHourKey, time.hour);
    await prefs.setInt(_notifMinuteKey, time.minute);

    if (enabled) {
      await requestPermissions();
      await _scheduleDailyNotification(time);
    } else {
      await _notificationsPlugin.cancelAll();
    }
  }

  Future<void> _scheduleDailyNotification(TimeOfDay time) async {
    await _notificationsPlugin
        .cancelAll(); // Cancel existing before scheduling new

    await _notificationsPlugin.zonedSchedule(
      0,
      'Read Quran',
      'Don\'t forget your daily Khatmah reading!',
      _nextInstanceOfTime(time),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'khatmah_channel',
          'Khatmah Reminders',
          channelDescription: 'Daily reminders for Quran Khatmah',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}
