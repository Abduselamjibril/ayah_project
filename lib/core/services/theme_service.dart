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

  /// Get the page number background image path for the current theme
  String get pageBackgroundImagePath =>
      getPageBackgroundImagePath(_currentTheme);

  /// Get the page number background image path for a specific theme
  static String getPageBackgroundImagePath(AppTheme theme) {
    switch (theme) {
      case AppTheme.goldenParchment:
        return 'assets/images/Page.png';
      case AppTheme.midnightBlueprint:
        return 'assets/images/Page_dark.png';
      case AppTheme.mintGarden:
        return 'assets/images/Page_green.png';
      case AppTheme.ornateTwilight:
        return 'assets/images/Page_green_dark.png';
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
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightAccent,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAccent,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        surfaceVariant: AppColors.lightSurfaceVariant,
        primaryContainer: AppColors.lightAccentContainer,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.lightText,
        onPrimaryContainer: AppColors.lightOnAccentContainer,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.lightText),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.lightText),
        titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.lightText),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.lightText),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppColors.lightText),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.lightText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.lightAccent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Midnight Blueprint Theme (Dark)
  ThemeData get _midnightBlueprintTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.darkAccent,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkAccent,
        secondary: AppColors.darkAccent,
        surface: AppColors.darkSurface,
        surfaceVariant: AppColors.darkSurfaceVariant,
        primaryContainer: AppColors.darkAccentContainer,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.darkText,
        onPrimaryContainer: AppColors.darkOnAccentContainer,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText),
        titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.darkText),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.darkText),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppColors.darkText),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkAccent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.darkAccent),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.darkAccent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Mint Garden Theme (Green Light)
  ThemeData get _mintGardenTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.greenLightAccent,
      scaffoldBackgroundColor: AppColors.greenLightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.greenLightAccent,
        secondary: AppColors.greenLightAccent,
        surface: AppColors.greenLightSurface,
        surfaceVariant: AppColors.greenLightSurfaceVariant,
        primaryContainer: AppColors.greenLightAccentContainer,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.greenLightText,
        onPrimaryContainer: AppColors.greenLightOnAccentContainer,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.greenLightText),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.greenLightText),
        titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.greenLightText),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.greenLightText),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppColors.greenLightText),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.greenLightText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.greenLightAccent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      cardTheme: CardThemeData(
        color: AppColors.greenLightSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.greenLightAccent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.greenLightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.greenLightSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Ornate Twilight Theme (Green Dark)
  ThemeData get _ornateTwilightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.greenDarkAccent,
      scaffoldBackgroundColor: AppColors.greenDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.greenDarkAccent,
        secondary: AppColors.greenDarkAccent,
        surface: AppColors.greenDarkSurface,
        surfaceVariant: AppColors.greenDarkSurfaceVariant,
        primaryContainer: AppColors.greenDarkAccentContainer,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.greenDarkText,
        onPrimaryContainer: AppColors.greenDarkOnAccentContainer,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.greenDarkText),
        titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.greenDarkText),
        titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.greenDarkText),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: AppColors.greenDarkText),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppColors.greenDarkText),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.greenDarkText),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.greenDarkSurface,
        foregroundColor: AppColors.greenDarkAccent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.greenDarkAccent),
      ),
      cardTheme: CardThemeData(
        color: AppColors.greenDarkSurface,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.greenDarkAccent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.greenDarkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.greenDarkSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  // Legacy compatibility - for any code still using ThemeMode
  ThemeData get lightTheme => _goldenParchmentTheme;
  ThemeData get darkTheme => _midnightBlueprintTheme;
}
