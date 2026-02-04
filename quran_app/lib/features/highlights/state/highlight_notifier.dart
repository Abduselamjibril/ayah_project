import 'package:flutter/foundation.dart';
import '../data/models/highlight.dart';
import '../data/repositories/highlight_repository.dart';

class HighlightNotifier extends ChangeNotifier {
  final HighlightRepository _repository = HighlightRepository();
  List<Highlight> _highlights = [];

  List<Highlight> get highlights => List.unmodifiable(_highlights);

  Future<void> initialize() async {
    _highlights = await _repository.getAllHighlights();
    notifyListeners();
  }

  Future<void> addHighlight(Highlight highlight) async {
    _highlights.removeWhere(
        (h) => h.surahId == highlight.surahId && h.ayahId == highlight.ayahId);
    _highlights.add(highlight);
    await _repository.saveHighlights(_highlights);
    notifyListeners();
  }

  Future<void> removeHighlight(int surahId, int ayahId) async {
    _highlights.removeWhere((h) => h.surahId == surahId && h.ayahId == ayahId);
    await _repository.saveHighlights(_highlights);
    notifyListeners();
  }

  Highlight? getHighlight(int surahId, int ayahId) {
    try {
      return _highlights
          .firstWhere((h) => h.surahId == surahId && h.ayahId == ayahId);
    } catch (_) {
      return null;
    }
  }

  List<Highlight> highlightsByColor(String colorHex) {
    return _highlights.where((h) => h.colorHex == colorHex).toList();
  }

  List<Highlight> highlightsBySurah(int surahId) {
    return _highlights.where((h) => h.surahId == surahId).toList();
  }
}
