import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Custom theme enum for the app
enum AppTheme {
  goldenParchment, // mainframe.png
  midnightBlueprint, // mainframe_dark.png
  mintGarden, // green_mainframe.png
  ornateTwilight, // green_mainframe_dark.png
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  static const String _themeKey = 'app_theme';

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  AppTheme _currentTheme = AppTheme.goldenParchment;

  AppTheme get currentTheme => _currentTheme;

  /// Get the mainframe image path for the current theme
  String get mainframeImagePath => getMainframeImagePath(_currentTheme);

  /// Get the mainframe image path for a specific theme
  static String getMainframeImagePath(AppTheme theme) {
    switch (theme) {
      case AppTheme.goldenParchment:
        return 'assets/images/mainframe.png';
      case AppTheme.midnightBlueprint:
        return 'assets/images/mainframe_dark.png';
      case AppTheme.mintGarden:
        return 'assets/images/green_mainframe.png';
      case AppTheme.ornateTwilight:
        return 'assets/images/green_mainframe_dark.png';
    }
  }

  /// Get the display name for a theme
  static String getThemeName(AppTheme theme) {
    switch (theme) {
      case AppTheme.goldenParchment:
        return 'Golden Parchment';
      case AppTheme.midnightBlueprint:
        return 'Midnight Blueprint';
      case AppTheme.mintGarden:
        return 'Mint Garden';
      case AppTheme.ornateTwilight:
        return 'Ornate Twilight';
    }
  }

  /// Initialize and load saved theme preference
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);

    if (savedTheme != null) {
      _currentTheme = AppTheme.values.firstWhere(
        (theme) => theme.toString() == savedTheme,
        orElse: () => AppTheme.goldenParchment,
      );
      notifyListeners();
    }
  }

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    _saveTheme();
    notifyListeners();
  }

  /// Save theme preference to persistent storage
  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _currentTheme.toString());
  }

  /// Get ThemeData for the current theme
  ThemeData get themeData => getThemeData(_currentTheme);

  /// Get ThemeData for a specific theme
  ThemeData getThemeData(AppTheme theme) {
    switch (theme) {
      case AppTheme.goldenParchment:
        return _goldenParchmentTheme;
      case AppTheme.midnightBlueprint:
        return _midnightBlueprintTheme;
      case AppTheme.mintGarden:
        return _mintGardenTheme;
      case AppTheme.ornateTwilight:
        return _ornateTwilightTheme;
    }
  }

  /// Golden Parchment Theme (Light)
  ThemeData get _goldenParchmentTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      primaryColor: AppColors.lightAccent,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAccent,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lightAccent,
      ),
    );
  }

  /// Midnight Blueprint Theme (Dark)
  ThemeData get _midnightBlueprintTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      primaryColor: AppColors.darkAccent,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkAccent,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        onPrimary: Colors.black87,
        onSecondary: Colors.black87,
        onSurface: AppColors.darkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkAccent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.darkAccent,
      ),
    );
  }

  /// Mint Garden Theme (Green Light)
  ThemeData get _mintGardenTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.light,
      primaryColor: AppColors.greenLightAccent,
      scaffoldBackgroundColor: AppColors.greenLightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.greenLightAccent,
        secondary: AppColors.greenLightAccent,
        surface: AppColors.greenLightSurface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.greenLightText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.greenLightAccent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.greenLightSurface,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.greenLightAccent,
      ),
    );
  }

  /// Ornate Twilight Theme (Green Dark)
  ThemeData get _ornateTwilightTheme {
    return ThemeData(
      useMaterial3: false,
      brightness: Brightness.dark,
      primaryColor: AppColors.greenDarkAccent,
      scaffoldBackgroundColor: AppColors.greenDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.greenDarkAccent,
        secondary: AppColors.greenDarkAccent,
        surface: AppColors.greenDarkSurface,
        onPrimary: Colors.black87,
        onSecondary: Colors.black87,
        onSurface: AppColors.greenDarkText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.greenDarkSurface,
        foregroundColor: AppColors.greenDarkAccent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: AppColors.greenDarkSurface,
        elevation: 1,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.greenDarkAccent,
      ),
    );
  }

  // Legacy compatibility - for any code still using ThemeMode
  ThemeData get lightTheme => _goldenParchmentTheme;
  ThemeData get darkTheme => _midnightBlueprintTheme;
}
