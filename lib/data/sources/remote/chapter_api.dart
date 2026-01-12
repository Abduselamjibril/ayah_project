// lib/data/sources/remote/chapter_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/chapter_model.dart';
import '../../../core/constants/api_endpoints.dart';

class ChapterApi {
  static const Duration _timeout = Duration(seconds: 30);

  Future<List<Chapter>> getChapters({String language = 'en'}) async {
    try {
      final uri = Uri.parse(
          '${ApiEndpoints.baseUrl}${ApiEndpoints.chapters}?language=$language');
      final response = await http.get(uri).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = (data['chapters'] ?? []) as List;
        return list.map((e) => Chapter.fromJson(e)).toList();
      }
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    } catch (e) {
      throw Exception('Failed to fetch chapters: $e');
    }
  }
}
