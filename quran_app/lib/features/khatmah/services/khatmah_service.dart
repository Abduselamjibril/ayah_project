import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/khatmah.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class KhatmahService {
  static const String _khatmahsKey = 'khatmahs_list';
  static const String _khatmahKey =
      'current_khatmah'; // Legacy key for migration
  static const String _notifEnabledKey = 'khatmah_notif_enabled';
  static const String _notifHourKey = 'khatmah_notif_hour';
  static const String _notifMinuteKey = 'khatmah_notif_minute';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const AndroidNotificationChannel _khatmahChannel =
      AndroidNotificationChannel(
    'khatmah_channel',
    'Khatmah Reminders',
    description: 'Daily reminders for Quran Khatmah',
    importance: Importance.max,
  );

  Future<void> init() async {
    if (_initialized) return;
    // Android init
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS init
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    tz.initializeTimeZones();
    await _configureLocalTimeZone();

    if (Platform.isAndroid) {
      final android =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_khatmahChannel);
    }

    // Migrate legacy single khatmah to list
    await _migrateLegacyData();

    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// Configure local timezone for cross-platform notification scheduling
  Future<void> _configureLocalTimeZone() async {
    if (kIsWeb) return;
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  Future<bool> requestPermissions() async {
    await _ensureInitialized();
    if (Platform.isIOS) {
      final granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? true; // Android pre-13 doesn't require permission
    }
    return true; // Other platforms
  }

  Future<void> _migrateLegacyData() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_khatmahKey)) {
      final String? jsonString = prefs.getString(_khatmahKey);
      if (jsonString != null) {
        final legacyKhatmah = Khatmah.fromJson(jsonDecode(jsonString));
        await saveKhatmah(legacyKhatmah); // Add to list
        await prefs.remove(_khatmahKey); // Remove legacy
      }
    }
  }

  Future<List<Khatmah>> getAllKhatmahs() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? jsonList = prefs.getStringList(_khatmahsKey);
    if (jsonList == null) return [];
    return jsonList.map((json) => Khatmah.fromJson(jsonDecode(json))).toList();
  }

  Future<void> addKhatmah(int durationDays) async {
    final khatmah = Khatmah(
      id: DateTime.now().toIso8601String(),
      startDate: DateTime.now(),
      durationDays: durationDays,
    );
    await saveKhatmah(khatmah);

    // Enable notifications by default when starting first khatmah
    final all = await getAllKhatmahs();
    if (all.length == 1) {
      await setNotificationSettings(true, const TimeOfDay(hour: 20, minute: 0));
    }
  }

  Future<void> updateKhatmahProgress(String id, int page) async {
    final khatmahs = await getAllKhatmahs();
    final index = khatmahs.indexWhere((k) => k.id == id);
    if (index != -1) {
      final khatmah = khatmahs[index];
      int newPage = page;
      if (page > khatmah.lastReadPage) {
        newPage = page;
      } else {
        newPage = khatmah.lastReadPage;
      }

      final updated = khatmah.copyWith(lastReadPage: newPage);
      khatmahs[index] = updated;
      await _saveAllKhatmahs(khatmahs);
    }
  }

  Future<void> deleteKhatmah(String id) async {
    final khatmahs = await getAllKhatmahs();
    khatmahs.removeWhere((k) => k.id == id);
    await _saveAllKhatmahs(khatmahs);

    if (khatmahs.isEmpty) {
      await _notificationsPlugin.cancelAll();
    }
  }

  Future<void> saveKhatmah(Khatmah khatmah) async {
    final khatmahs = await getAllKhatmahs();
    final index = khatmahs.indexWhere((k) => k.id == khatmah.id);
    if (index != -1) {
      khatmahs[index] = khatmah;
    } else {
      khatmahs.add(khatmah);
    }
    await _saveAllKhatmahs(khatmahs);
  }

  Future<void> _saveAllKhatmahs(List<Khatmah> khatmahs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = khatmahs.map((k) => jsonEncode(k.toJson())).toList();
    await prefs.setStringList(_khatmahsKey, jsonList);
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
    await _ensureInitialized();
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
    await _ensureInitialized();
    await _notificationsPlugin
        .cancelAll(); // Cancel existing before scheduling new

    // Determine schedule mode based on platform capabilities
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (Platform.isAndroid) {
      final android =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        // Fallback for Android versions without exact alarm permission
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

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
      androidScheduleMode: scheduleMode,
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
