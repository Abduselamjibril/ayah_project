import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../quran/qcf_quran.dart';
import '../quran/widgets/quran_pageview.dart';

/// Page layout for horizontal mode in landscape.
enum PageLayout { single, double }

class MushafSettingsService extends ChangeNotifier {
  static final MushafSettingsService _instance =
      MushafSettingsService._internal();
  static const String _scrollModeKey = 'mushaf_scroll_mode';
  static const String _pageLayoutKey = 'mushaf_page_layout';
  static const String _lastPageKey = 'mushaf_last_page';

  factory MushafSettingsService() {
    return _instance;
  }

  MushafSettingsService._internal();

  ScrollMode _scrollMode = ScrollMode.horizontal;
  PageLayout _pageLayout = PageLayout.single;
  int _lastPage = 1;

  ScrollMode get scrollMode => _scrollMode;
  PageLayout get pageLayout => _pageLayout;
  int get lastPage => _lastPage;

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
      }
    }

    final savedLayout = prefs.getString(_pageLayoutKey);
    if (savedLayout != null) {
      final loadedLayout = PageLayout.values.firstWhere(
        (l) => l.name == savedLayout,
        orElse: () => _pageLayout,
      );
      if (loadedLayout != _pageLayout) {
        _pageLayout = loadedLayout;
      }
    }

    final savedPage = prefs.getInt(_lastPageKey);
    if (savedPage != null && savedPage >= 1 && savedPage <= totalPagesCount) {
      _lastPage = savedPage;
    }

    notifyListeners();
  }

  Future<void> setScrollMode(ScrollMode mode) async {
    if (_scrollMode == mode) return;
    _scrollMode = mode;
    await _saveScrollMode();
    notifyListeners();
  }

  Future<void> setPageLayout(PageLayout layout) async {
    if (_pageLayout == layout) return;
    _pageLayout = layout;
    await _savePageLayout();
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

  Future<void> _savePageLayout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pageLayoutKey, _pageLayout.name);
  }

  Future<void> setLastPage(int page) async {
    if (page == _lastPage) return;
    if (page < 1 || page > totalPagesCount) return;
    _lastPage = page;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastPageKey, page);
  }
}
