import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/services/mushaf_settings_service.dart';

class MushafController extends ChangeNotifier {
  final MushafSettingsService _settings = MushafSettingsService();
  ScrollMode _scrollMode = ScrollMode.horizontal;
  int _currentPage = 1;
  int _currentSurah = 1;
  int? _highlightedSurah;
  int? _highlightedVerse;

  static const int _totalPages = 604;

  MushafController() {
    _scrollMode = _settings.scrollMode;
    _settings.addListener(_handleSettingsChanged);
  }

  ScrollMode get scrollMode => _scrollMode;
  int get currentPage => _currentPage;
  int get currentSurah => _currentSurah;
  int? get highlightedSurah => _highlightedSurah;
  int? get highlightedVerse => _highlightedVerse;

  void toggleScrollMode() {
    _settings.toggleScrollMode();
  }

  void setScrollMode(ScrollMode mode) {
    _settings.setScrollMode(mode);
  }

  void setPage(int page) {
    if (page != _currentPage && page >= 1 && page <= _totalPages) {
      _currentPage = page;
      notifyListeners();
    }
  }

  void setSurah(int surah) {
    if (surah != _currentSurah && surah >= 1 && surah <= 114) {
      _currentSurah = surah;
      notifyListeners();
    }
  }

  void setHighlightedVerse(int? surah, int? verse) {
    _highlightedSurah = surah;
    _highlightedVerse = verse;
    notifyListeners();
  }

  void clearHighlight() {
    _highlightedSurah = null;
    _highlightedVerse = null;
    notifyListeners();
  }

  void _handleSettingsChanged() {
    final nextMode = _settings.scrollMode;
    if (nextMode != _scrollMode) {
      _scrollMode = nextMode;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    super.dispose();
  }
}
