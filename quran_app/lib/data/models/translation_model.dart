// lib/data/models/translation_model.dart

/// Model for a translation edition
class TranslationEdition {
  final String identifier;
  final String language;
  final String name;
  final String englishName;
  final String direction;
  final String format;
  final String type;

  TranslationEdition({
    required this.identifier,
    required this.language,
    required this.name,
    required this.englishName,
    required this.direction,
    required this.format,
    required this.type,
  });

  /// Create from API JSON response
  factory TranslationEdition.fromJson(Map<String, dynamic> json) {
    return TranslationEdition(
      identifier: json['identifier'] as String,
      language: json['language'] as String,
      name: json['name'] as String,
      englishName: json['englishName'] as String,
      direction: json['direction'] as String? ?? 'ltr',
      format: json['format'] as String? ?? 'text',
      type: json['type'] as String? ?? 'translation',
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'identifier': identifier,
      'language': language,
      'name': name,
      'englishName': englishName,
      'direction': direction,
      'format': format,
      'type': type,
    };
  }

  @override
  String toString() {
    return 'TranslationEdition(identifier: $identifier, englishName: $englishName)';
  }
}

/// Model for a single translated ayah
class TranslatedAyah {
  final int surahNumber;
  final int ayahNumber;
  final String text;
  final String editionIdentifier;

  TranslatedAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
    required this.editionIdentifier,
  });

  /// Convert to database format
  Map<String, dynamic> toDatabase({
    required String language,
    required String translator,
  }) {
    return {
      'surah_number': surahNumber,
      'ayah_number': ayahNumber,
      'language': language,
      'translator': translator,
      'edition_identifier': editionIdentifier,
      'text': text,
    };
  }
}
