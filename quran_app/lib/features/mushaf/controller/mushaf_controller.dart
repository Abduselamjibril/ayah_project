import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';

class MushafController extends ChangeNotifier {
  final MushafSettingsService _settings = MushafSettingsService();
  ScrollMode _scrollMode = ScrollMode.horizontal;
  late final ValueNotifier<ScrollMode> scrollModeListenable;
  int _currentPage = 1;
  int _currentSurah = 1;
  int? _highlightedSurah;
  int? _highlightedVerse;

  static const int _totalPages = 604;

  // Stream for navigation events to decouple UI forcing.
  // Using broadcast stream so both views (if alive) can listen.
  final StreamController<int> _navigationController =
      StreamController<int>.broadcast();
  Stream<int> get navigationStream => _navigationController.stream;

  MushafController() {
    _scrollMode = _settings.scrollMode;
    scrollModeListenable = ValueNotifier(_scrollMode);
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
    if (_highlightedSurah != surah || _highlightedVerse != verse) {
      _highlightedSurah = surah;
      _highlightedVerse = verse;
      notifyListeners();
    }
  }

  void clearHighlight() {
    _highlightedSurah = null;
    _highlightedVerse = null;
    notifyListeners();
  }

  /// Optimized consolidated navigation method.
  /// All navigation requests should route through here.
  void navigateToPage(int page) {
    if (page < 1 || page > _totalPages) return;

    // Update internal state
    _currentPage = page;

    // Notify views to physically scroll/jump
    _navigationController.add(page);

    // Notify listeners of state change (UI update)
    notifyListeners();
  }

  void navigateToSurah(int surah) {
    final page = getPageNumber(surah, 1);
    setSurah(surah);
    navigateToPage(page);
  }

  void navigateToVerse(int surah, int verse) {
    final page = getPageNumber(surah, verse);
    setHighlightedVerse(surah, verse);
    navigateToPage(page);
  }

  void _handleSettingsChanged() {
    final nextMode = _settings.scrollMode;
    if (nextMode != _scrollMode) {
      _scrollMode = nextMode;
      scrollModeListenable.value = _scrollMode;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _settings.removeListener(_handleSettingsChanged);
    scrollModeListenable.dispose();
    _navigationController.close();
    super.dispose();
  }
}
