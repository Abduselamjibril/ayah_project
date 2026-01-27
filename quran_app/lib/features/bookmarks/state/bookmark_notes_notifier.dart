import 'package:flutter/foundation.dart';
import '../data/models/bookmark.dart';
import '../data/models/note.dart';
import '../data/repositories/bookmark_notes_repository.dart';
import '../../../core/services/home_widget_service.dart';

class BookmarkNotesNotifier extends ChangeNotifier {
  BookmarkNotesNotifier({BookmarkNotesRepository? repository})
      : _repository = repository ?? BookmarkNotesRepository();

  final BookmarkNotesRepository _repository;

  final Map<String, Bookmark> _bookmarksByKey = {};
  final Map<String, NoteModel> _notesByKey = {};
  
  // Custom names for the four categories shown in the UI
  final Map<String, String> _categoryNames = {
    '#EF5350': 'Red',
    '#FFB300': 'Yellow',
    '#66BB6A': 'Green',
    '#42A5F5': 'Blue',
  };

  Bookmark? _khatmahPin;
  bool _initialized = false;
  bool _loading = false;

  bool get isInitialized => _initialized;
  bool get isLoading => _loading;
  Bookmark? get khatmahPin => _khatmahPin;
  Map<String, String> get categoryNames => _categoryNames;

  List<Bookmark> get bookmarks {
    final list = _bookmarksByKey.values.toList();
    // Sort by newest first so we can easily find the 'latest' for the category subtitle
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<NoteModel> get notes {
    final list = _notesByKey.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();
    await _loadBookmarks();
    await _loadNotes();
    await _loadKhatmahPin();
    _initialized = true;
    _loading = false;
    notifyListeners();
  }

  // Method called when 'Done' is pressed in the UI
  void updateCategoryName(String colorHex, String newName) {
    if (_categoryNames.containsKey(colorHex)) {
      _categoryNames[colorHex] = newName;
      notifyListeners();
    }
  }

  bool isBookmarked(int surahId, int ayahId) {
    return _bookmarksByKey.containsKey(_verseKey(surahId, ayahId));
  }

  Bookmark? bookmarkForVerse(int surahId, int ayahId) {
    return _bookmarksByKey[_verseKey(surahId, ayahId)];
  }

  bool hasNote(int surahId, int ayahId) {
    return _notesByKey.containsKey(_verseKey(surahId, ayahId));
  }

  NoteModel? noteForVerse(int surahId, int ayahId) {
    return _notesByKey[_verseKey(surahId, ayahId)];
  }

  Future<void> deleteBookmark(int surahId, int ayahId) async {
    final key = _verseKey(surahId, ayahId);
    if (_bookmarksByKey.containsKey(key)) {
      await _repository.deleteBookmarkForVerse(surahId, ayahId);
      _bookmarksByKey.remove(key);
      notifyListeners();
    }
  }

  Future<void> toggleBookmark({
    required int surahId,
    required int ayahId,
    String colorHex = '#FFD54F',
    String? category,
  }) async {
    final key = _verseKey(surahId, ayahId);
    if (_bookmarksByKey.containsKey(key)) {
      await _repository.deleteBookmarkForVerse(surahId, ayahId);
      _bookmarksByKey.remove(key);
    } else {
      final saved = await _repository.upsertBookmark(
        surahId: surahId,
        ayahId: ayahId,
        colorHex: colorHex,
        categoryName: category,
      );
      _bookmarksByKey[key] = saved;
    }
    notifyListeners();
  }

  Future<Bookmark> saveBookmark({
    required int surahId,
    required int ayahId,
    String colorHex = '#FFD54F',
    String? category,
  }) async {
    final saved = await _repository.upsertBookmark(
      surahId: surahId,
      ayahId: ayahId,
      colorHex: colorHex,
      categoryName: category,
    );
    _bookmarksByKey[_verseKey(surahId, ayahId)] = saved;
    notifyListeners();
    return saved;
  }

  Future<void> setKhatmahPin({
    required int surahId,
    required int ayahId,
    String colorHex = '#4DB6AC',
    String? category,
  }) async {
    final previousPin = _khatmahPin;
    final saved = await _repository.upsertBookmark(
      surahId: surahId,
      ayahId: ayahId,
      colorHex: colorHex,
      categoryName: category,
      isKhatmahPin: true,
    );
    if (previousPin != null) {
      _bookmarksByKey.remove(previousPin.verseKey);
    }
    _khatmahPin = saved;
    _bookmarksByKey[_verseKey(surahId, ayahId)] = saved;
    await HomeWidgetService.instance
        .updateLastRead(surahId: surahId, ayahId: ayahId);
    notifyListeners();
  }

  Future<void> clearKhatmahPin() async {
    final prev = _khatmahPin;
    await _repository.clearKhatmahPin();
    if (prev != null) {
      _bookmarksByKey.remove(prev.verseKey);
    }
    _khatmahPin = null;
    notifyListeners();
  }

  Future<NoteModel> upsertNote({
    required int surahId,
    required int ayahId,
    required String content,
  }) async {
    final saved = await _repository.upsertNote(
      surahId: surahId,
      ayahId: ayahId,
      content: content,
    );
    _notesByKey[_verseKey(surahId, ayahId)] = saved;
    notifyListeners();
    return saved;
  }

  Future<void> deleteNoteForVerse(int surahId, int ayahId) async {
    await _repository.deleteNotesForVerse(surahId, ayahId);
    _notesByKey.remove(_verseKey(surahId, ayahId));
    notifyListeners();
  }

  Future<List<NoteModel>> searchNotes(String query) {
    return _repository.searchNotes(query);
  }

  Future<List<Bookmark>> bookmarksByColor(String colorHex) async {
    return _repository.getAllBookmarks(colorHex: colorHex);
  }

  Future<void> refresh() async {
    await _loadBookmarks();
    await _loadNotes();
    await _loadKhatmahPin();
    notifyListeners();
  }

  Future<void> _loadBookmarks() async {
    final rows = await _repository.getAllBookmarks();
    _bookmarksByKey
      ..clear()
      ..addEntries(rows.map((b) => MapEntry(b.verseKey, b)));
  }

  Future<void> _loadKhatmahPin() async {
    _khatmahPin = await _repository.getKhatmahPin();
    final pin = _khatmahPin;
    if (pin != null) {
      _bookmarksByKey[pin.verseKey] = pin;
    }
  }

  Future<void> _loadNotes() async {
    final rows = await _repository.getAllNotes();
    _notesByKey
      ..clear()
      ..addEntries(rows.map((n) => MapEntry(n.verseKey, n)));
  }

  String _verseKey(int surahId, int ayahId) => '$surahId:$ayahId';
}