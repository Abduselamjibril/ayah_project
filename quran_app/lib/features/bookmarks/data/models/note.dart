class NoteModel {
  final int? id;
  final int surahId;
  final int ayahId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NoteModel({
    this.id,
    required this.surahId,
    required this.ayahId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  NoteModel copyWith({
    int? id,
    int? surahId,
    int? ayahId,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      surahId: surahId ?? this.surahId,
      ayahId: ayahId ?? this.ayahId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NoteModel.fromMap(Map<String, Object?> map) {
    final created = _parseDate(map['created_at']);
    final updated = _parseDate(map['updated_at']);
    return NoteModel(
      id: map['id'] as int?,
      surahId: (map['surah_id'] as num).toInt(),
      ayahId: (map['ayah_id'] as num).toInt(),
      content: map['content'] as String? ?? '',
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
