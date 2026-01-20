// lib/data/models/chapter_model.dart
class Chapter {
  final int id;
  final String nameSimple;
  final String nameArabic;
  final int versesCount;

  Chapter({
    required this.id,
    required this.nameSimple,
    required this.nameArabic,
    required this.versesCount,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'] as int? ?? 0,
      nameSimple: json['name_simple'] as String? ?? 'Surah',
      nameArabic: json['name_arabic'] as String? ?? '',
      versesCount: json['verses_count'] as int? ?? 0,
    );
  }
}
