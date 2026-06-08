import 'package:shared_preferences/shared_preferences.dart';
import '../models/highlight.dart';
import 'dart:convert';

class HighlightRepository {
  static const String _storageKey = 'highlights';

  Future<List<Highlight>> getAllHighlights() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => Highlight.fromJson(e)).toList();
  }

  Future<void> saveHighlights(List<Highlight> highlights) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = json.encode(highlights.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
