// lib/data/models/tafsir_model.dart

/// Model for a tafsir edition
class TafsirEdition {
  final String identifier;
  final String language;
  final String name;
  final String englishName;
  final String direction;
  final String format;
  final String type;

  TafsirEdition({
    required this.identifier,
    required this.language,
    required this.name,
    required this.englishName,
    required this.direction,
    required this.format,
    required this.type,
  });

  /// Create from API JSON response
  factory TafsirEdition.fromJson(Map<String, dynamic> json) {
    return TafsirEdition(
      identifier: json['identifier'] as String,
      language: json['language'] as String,
      name: json['name'] as String,
      englishName: json['englishName'] as String,
      direction: json['direction'] as String? ?? 'rtl',
      format: json['format'] as String? ?? 'text',
      type: json['type'] as String? ?? 'tafsir',
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
    return 'TafsirEdition(identifier: $identifier, englishName: $englishName)';
  }
}

/// Model for a single tafsir ayah
class TafsirAyah {
  final int surahNumber;
  final int ayahNumber;
  final String text;
  final String editionIdentifier;

  TafsirAyah({
    required this.surahNumber,
    required this.ayahNumber,
    required this.text,
    required this.editionIdentifier,
  });

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
      'edition_identifier': editionIdentifier,
      'text': text,
    };
  }
}
