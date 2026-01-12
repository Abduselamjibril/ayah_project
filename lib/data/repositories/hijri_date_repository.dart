import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/hijri_date_model.dart';

class HijriDateRepository {
  Future<HijriDateResponse?> getHijriDate(DateTime date) async {
    try {
      final formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final url = Uri.parse(
          'https://www.ummahapi.com/api/hijri-date?date=$formattedDate');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return HijriDateResponse.fromJson(json);
      } else {
        debugPrint('Failed to load Hijri date: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching Hijri date: $e');
      return null;
    }
  }
}
