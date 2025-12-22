class Bookmark {
  final int? id;
  final int surahId;
  final int ayahId;
  final String colorHex;
  final String? categoryName;
  final bool isKhatmahPin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Bookmark({
    this.id,
    required this.surahId,
    required this.ayahId,
    required this.colorHex,
    this.categoryName,
    this.isKhatmahPin = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Bookmark copyWith({
    int? id,
    int? surahId,
    int? ayahId,
    String? colorHex,
    String? categoryName,
    bool? isKhatmahPin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      surahId: surahId ?? this.surahId,
      ayahId: ayahId ?? this.ayahId,
      colorHex: colorHex ?? this.colorHex,
      categoryName: categoryName ?? this.categoryName,
      isKhatmahPin: isKhatmahPin ?? this.isKhatmahPin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'color_hex': colorHex,
      'category_name': categoryName,
      'is_khatmah_pin': isKhatmahPin ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Bookmark.fromMap(Map<String, Object?> map) {
    final created = _parseDate(map['created_at']);
    final updated = _parseDate(map['updated_at']);

    return Bookmark(
      id: map['id'] as int?,
      surahId: (map['surah_id'] as num).toInt(),
      ayahId: (map['ayah_id'] as num).toInt(),
      colorHex: (map['color_hex'] ?? '#FFD54F') as String,
      categoryName: map['category_name'] as String?,
      isKhatmahPin: (map['is_khatmah_pin'] ?? 0) == 1,
      createdAt: created,
      updatedAt: updated,
    );
  }

  static DateTime _parseDate(Object? value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) {
      return DateTime.now();
    }
    return DateTime.tryParse(text) ?? DateTime.now();
  }

  String get verseKey => '$surahId:$ayahId';
}
