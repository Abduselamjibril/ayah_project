import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../quran/widgets/quran_pageview.dart';

class MushafSettingsService extends ChangeNotifier {
  static final MushafSettingsService _instance =
      MushafSettingsService._internal();
  static const String _scrollModeKey = 'mushaf_scroll_mode';

  factory MushafSettingsService() {
    return _instance;
  }

  MushafSettingsService._internal();

  ScrollMode _scrollMode = ScrollMode.horizontal;

  ScrollMode get scrollMode => _scrollMode;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_scrollModeKey);

    if (saved != null) {
      final loadedMode = ScrollMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => _scrollMode,
      );

      if (loadedMode != _scrollMode) {
        _scrollMode = loadedMode;
        notifyListeners();
      }
    }
  }

  Future<void> setScrollMode(ScrollMode mode) async {
    if (_scrollMode == mode) return;
    _scrollMode = mode;
    await _saveScrollMode();
    notifyListeners();
  }

  Future<void> toggleScrollMode() async {
    final nextMode = _scrollMode == ScrollMode.horizontal
        ? ScrollMode.vertical
        : ScrollMode.horizontal;
    await setScrollMode(nextMode);
  }

  Future<void> _saveScrollMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scrollModeKey, _scrollMode.name);
  }
}
