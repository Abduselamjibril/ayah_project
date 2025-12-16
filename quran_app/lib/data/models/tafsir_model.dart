// lib/data/models/tafsir_model.dart

/// Model for a tafsir edition
class TafsirEdition {
  final int id; // Changed from String identifier to int id
  final String languageName; // Changed from language code to full language name
  final String name;
  final String authorName; // Added author name field
  final String slug; // Added slug field
  final String? direction;

  TafsirEdition({
    required this.id,
    required this.languageName,
    required this.name,
    required this.authorName,
    required this.slug,
    this.direction,
  });

  /// Create from Quran.com API JSON response
  factory TafsirEdition.fromJson(Map<String, dynamic> json) {
    return TafsirEdition(
      id: json['id'] as int? ?? 0,
      languageName: json['language_name'] as String? ?? 'Unknown',
      name: json['name'] as String? ?? 'Unknown',
      authorName: json['author_name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      direction: json['direction'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'language_name': languageName,
      'name': name,
      'author_name': authorName,
      'slug': slug,
      'direction': direction,
    };
  }

  @override
  String toString() {
    return 'TafsirEdition(id: $id, name: $name, author: $authorName)';
  }
}

/// Model for a single tafsir ayah
class TafsirAyah {
  final int surahNumber;
  final int ayahNumber;
  final String text;
  final int resourceId; // Changed from editionIdentifier to resourceId (int)
  final String? resourceName;
  final String? languageName;

  TafsirAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
    required this.resourceId,
    this.resourceName,
    this.languageName,
  });

  /// Create from Quran.com API JSON response
  factory TafsirAyah.fromJson(Map<String, dynamic> json) {
    // Parse verse_key format "1:1" to extract surah and ayah numbers
    final verseKey = json['verse_key'] as String;
    final parts = verseKey.split(':');

    return TafsirAyah(
      surahNumber: int.parse(parts[0]),
      ayahNumber: int.parse(parts[1]),
      text: json['text'] as String,
      resourceId: json['resource_id'] as int,
      resourceName: json['resource_name'] as String?,
      languageName: json['language_name'] as String?,
    );
  }

  /// Convert to database format
  Map<String, dynamic> toDatabase({
    required String language,
    required String scholar,
  }) {
    return {
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
      'language': language,
      'scholar': scholar,
      'edition_identifier':
          resourceId.toString(), // Store as string for compatibility
      'text': text,
    };
  }
}
