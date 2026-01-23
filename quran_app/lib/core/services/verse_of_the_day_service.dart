import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../quran/qcf_quran.dart';
import 'notification_service.dart';

class VerseOfTheDayService {
  VerseOfTheDayService._();
  static final instance = VerseOfTheDayService._();

  static const String _keyDate = 'votd_date';
  static const String _keySurah = 'votd_surah';
  static const String _keyVerse = 'votd_verse';
  static const String _keyEnabled = 'votd_enabled';
  static const String _keyTimeHour = 'votd_time_hour';
  static const String _keyTimeMinute = 'votd_time_minute';

  int? _surahNumber;
  int? _verseNumber;
  bool _enabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);

  int? get surahNumber => _surahNumber;
  int? get verseNumber => _verseNumber;
  bool get enabled => _enabled;
  TimeOfDay get notificationTime => _notificationTime;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Load settings
    _enabled = prefs.getBool(_keyEnabled) ?? true;
    final hour = prefs.getInt(_keyTimeHour) ?? 8;
    final minute = prefs.getInt(_keyTimeMinute) ?? 0;
    _notificationTime = TimeOfDay(hour: hour, minute: minute);

    // Check availability
    final savedDate = prefs.getString(_keyDate);
    final today = _getTodayString();

    if (savedDate == today) {
      _surahNumber = prefs.getInt(_keySurah);
      _verseNumber = prefs.getInt(_keyVerse);
    }

    if (_surahNumber == null || _verseNumber == null) {
      await _generateNewVerse(prefs);
    }

    if (_enabled) {
      await scheduleNotification();
    }
  }

  Future<void> _generateNewVerse(SharedPreferences prefs) async {
    final random = Random();
    // Random surah (1-114)
    final surah = random.nextInt(114) + 1;
    // Random verse in that surah
    final verseCount = getVerseCount(surah);
    final verse = random.nextInt(verseCount) + 1;

    _surahNumber = surah;
    _verseNumber = verse;

    await prefs.setString(_keyDate, _getTodayString());
    await prefs.setInt(_keySurah, surah);
    await prefs.setInt(_keyVerse, verse);
  }

  String _getTodayString() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}";
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);

    if (enabled) {
      await scheduleNotification();
    } else {
      await AppNotificationService.instance.cancelDailyNotification();
    }
  }

  Future<void> setNotificationTime(TimeOfDay time) async {
    if (_notificationTime == time) return;
    _notificationTime = time;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTimeHour, time.hour);
    await prefs.setInt(_keyTimeMinute, time.minute);

    if (_enabled) {
      await scheduleNotification();
    }
  }

  Future<void> scheduleNotification() async {
    if (!_enabled) return;
    await AppNotificationService.instance.initialize();
    final granted =
        await AppNotificationService.instance.requestPermissionsIfNeeded();
    if (!granted) return;
    await AppNotificationService.instance
        .scheduleDailyNotification(_notificationTime);
  }
}
