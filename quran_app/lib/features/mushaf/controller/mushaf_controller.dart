// features/mushaf/controller/mushaf_controller.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';

class MushafController extends ChangeNotifier {
  ScrollMode _scrollMode = ScrollMode.horizontal;
  int _currentPage = 1;
  int _currentSurah = 1;
  final Set<String> _bookmarkedVerses = {};
  int? _highlightedSurah;
  int? _highlightedVerse;

  ScrollMode get scrollMode => _scrollMode;
  int get currentPage => _currentPage;
  int get currentSurah => _currentSurah;
  Set<String> get bookmarkedVerses => _bookmarkedVerses;
  int? get highlightedSurah => _highlightedSurah;
  int? get highlightedVerse => _highlightedVerse;

  void toggleScrollMode() {
    _scrollMode = _scrollMode == ScrollMode.horizontal
        ? ScrollMode.vertical
        : ScrollMode.horizontal;
    notifyListeners();
  }

  void setPage(int page) {
    _currentPage = page;
    notifyListeners();
  }

  void setSurah(int surah) {
    _currentSurah = surah;
    notifyListeners();
  }

  void toggleBookmark(int surah, int verse) {
    final verseKey = '$surah:$verse';
    if (_bookmarkedVerses.contains(verseKey)) {
      _bookmarkedVerses.remove(verseKey);
    } else {
      _bookmarkedVerses.add(verseKey);
    }
    notifyListeners();
  }

  bool isBookmarked(int surah, int verse) {
    return _bookmarkedVerses.contains('$surah:$verse');
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

  @override
  void dispose() {
    _bookmarkedVerses.clear();
    super.dispose();
  }
}
