import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  static const String _languageKey = 'app_language';

  factory LanguageService() {
    return _instance;
  }

  LanguageService._internal();

  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('ar'), // Arabic
  ];

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguageCode = prefs.getString(_languageKey);

    if (savedLanguageCode != null) {
      final savedLocale = Locale(savedLanguageCode);
      if (_isLanguageSupported(savedLocale)) {
        // User has manually selected a supported language
        _currentLocale = savedLocale;
      } else {
        // Saved language is no longer supported; fallback to device/English
        _currentLocale = _resolveFallbackLocale();
        await _saveLocale();
      }
    } else {
      // User hasn't selected a language, check device locale
      _currentLocale = _resolveFallbackLocale();
    }
    notifyListeners();
  }

  Locale _resolveFallbackLocale() {
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    if (_isLanguageSupported(deviceLocale)) {
      return Locale(deviceLocale.languageCode);
    }
    return const Locale('en');
  }

  bool _isLanguageSupported(Locale locale) {
    for (var supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return true;
      }
    }
    return false;
  }

  Future<void> setLocale(Locale locale) async {
    if (!_isLanguageSupported(locale)) return;

    _currentLocale = locale;
    await _saveLocale();
    notifyListeners();
  }

  Future<void> _saveLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _currentLocale.languageCode);
  }
}
