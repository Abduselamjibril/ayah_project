import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Custom theme enum for the app
/// Style for the Surah name holder
enum SurahHeaderStyle {
  golden, // mainframe.png
  green, // green_mainframe.png
}

class ThemeService extends ChangeNotifier {
  static final ThemeService _instance = ThemeService._internal();
  static const String _themeModeKey = 'app_theme_mode';
  static const String _surahStyleKey = 'surah_header_style';
  static const String _pureBlackBackgroundKey = 'pure_black_background';

  factory ThemeService() {
    return _instance;
  }

  ThemeService._internal();

  ThemeMode _themeMode = ThemeMode.light;
  SurahHeaderStyle _surahHeaderStyle = SurahHeaderStyle.golden;
  bool _pureBlackBackground = false;

  ThemeMode get themeMode => _themeMode;
  SurahHeaderStyle get surahHeaderStyle => _surahHeaderStyle;
  bool get pureBlackBackground => _pureBlackBackground;

  /// Get the effective Mushaf background color
  Color getMushafBackgroundColor(Brightness brightness) {
    if (brightness == Brightness.dark && _pureBlackBackground) {
      return Colors.black;
    }
    return brightness == Brightness.dark
        ? AppColors.greenDarkBackground
        : AppColors.lightBackground;
  }

  /// Get the mainframe image path based on current theme mode and style
  String get mainframeImagePath {
    // In Dark mode, always use the Dark Green mainframe
    if (_themeMode == ThemeMode.dark) {
      return 'assets/images/green_mainframe_dark.png';
    }

    // In Light mode, check preference
    return _surahHeaderStyle == SurahHeaderStyle.green
        ? 'assets/images/green_mainframe.png'
        : 'assets/images/mainframe.png';
  }

  /// Helper to get correct mainframe path given the actual brightness
  String getResponsiveMainframePath(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return 'assets/images/green_mainframe_dark.png';
    } else {
      return _surahHeaderStyle == SurahHeaderStyle.green
          ? 'assets/images/green_mainframe.png'
          : 'assets/images/mainframe.png';
    }
  }

  /// Get the page number background image path
  String get pageBackgroundImagePath {
    if (_themeMode == ThemeMode.dark) {
      return 'assets/images/Page_green_dark.png';
    }
    // Light mode
    return _surahHeaderStyle == SurahHeaderStyle.green
        ? 'assets/images/Page_green.png' // New requirement: Green style in Light mode uses green page
        : 'assets/images/Page.png';
  }

  /// Get the page number background image path for a specific brightness
  /// Note: This static method can't access instances, so consumers should prefer the instance getter
  /// or pass the style explicitly if needed. Kept for compatibility but might need refactoring if used statically.
  static String getPageBackgroundImagePath(bool isDark) {
    return isDark
        ? 'assets/images/Page_green_dark.png'
        : 'assets/images/Page.png';
  }

  /// Initialize and load saved prefs
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    // Load Theme Mode
    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.toString() == savedMode,
        orElse: () => ThemeMode.light,
      );
      // If we accidentally loaded 'system' from old prefs, force Light
      if (_themeMode == ThemeMode.system) {
        _themeMode = ThemeMode.light;
      }
    }

    // Load Surah Style
    final savedStyle = prefs.getString(_surahStyleKey);
    if (savedStyle != null) {
      _surahHeaderStyle = SurahHeaderStyle.values.firstWhere(
        (e) => e.toString() == savedStyle,
        orElse: () => SurahHeaderStyle.golden,
      );
    }

    // Load Pure Black Background preference
    _pureBlackBackground = prefs.getBool(_pureBlackBackgroundKey) ?? false;

    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (mode == ThemeMode.system) return; // Prevent setting system
    _themeMode = mode;
    _saveThemeMode();
    notifyListeners();
  }

  void setSurahHeaderStyle(SurahHeaderStyle style) {
    _surahHeaderStyle = style;
    _saveSurahStyle();
    notifyListeners();
  }

  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.toString());
  }

  Future<void> _saveSurahStyle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_surahStyleKey, _surahHeaderStyle.toString());
  }

  void setPureBlackBackground(bool value) {
    _pureBlackBackground = value;
    _savePureBlackBackground();
    notifyListeners();
  }

  Future<void> _savePureBlackBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pureBlackBackgroundKey, _pureBlackBackground);
  }

  /// Light Theme (Golden Parchment)
  ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.lightAccent,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.lightAccent,
        secondary: AppColors.lightAccent,
        surface: AppColors.lightSurface,
        surfaceContainerHighest: AppColors.lightSurfaceVariant,
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

  /// Dark Theme (Ornate Twilight)
  ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.greenDarkAccent,
      scaffoldBackgroundColor: AppColors.greenDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.greenDarkAccent,
        secondary: AppColors.greenDarkAccent,
        surface: AppColors.greenDarkSurface,
        surfaceContainerHighest: AppColors.greenDarkSurfaceVariant,
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
}
