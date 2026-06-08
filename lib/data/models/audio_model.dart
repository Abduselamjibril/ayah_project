// lib/data/models/audio_model.dart

class AudioRecitation {
  final int id;
  final String reciterName;
  final String? style;
  final String? format; // e.g., mp3
  final String? relativePath; // some APIs provide a base path

  AudioRecitation({
    required this.id,
    required this.reciterName,
    this.style,
    this.format,
    this.relativePath,
  });

  factory AudioRecitation.fromJson(Map<String, dynamic> json) {
    return AudioRecitation(
      id: json['id'] as int? ?? 0,
      reciterName: (json['reciter_name'] ??
              json['translated_name'] ??
              json['name'] ??
              'Unknown')
          .toString(),
      style: json['style'] as String?,
      format: json['format'] as String?,
      relativePath: json['relative_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'reciter_name': reciterName,
        'style': style,
        'format': format,
        'relative_path': relativePath,
      };
}

class AudioVerseFile {
  final int surahNumber;
  final int ayahNumber;
  final String url;
  final String verseKey; // e.g., "1:1"
  final int? chapterId;
  final String? format;

  AudioVerseFile({
    required this.surahNumber,
    required this.ayahNumber,
    required this.url,
    required this.verseKey,
    this.chapterId,
    this.format,
  });

  factory AudioVerseFile.fromJson(Map<String, dynamic> json) {
    final verseKey =
        json['verse_key'] as String? ?? json['verseKey'] as String? ?? '';
    final parts = verseKey.split(':');
    // For chapter-level files, verse_key may be missing
    final surah = (json['chapter_id'] as int?) ??
        (parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0);
    final ayah = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

    // Url field can be 'url' or nested inside 'audio_url'
    final url = (json['url'] ??
            json['audio_url'] ??
            json['audioUrl'] ??
            json['file_url'] ??
            '')
        .toString();

    return AudioVerseFile(
      surahNumber: surah,
      ayahNumber: ayah,
      url: url,
      verseKey: verseKey,
      chapterId: json['chapter_id'] as int?,
      format: json['format'] as String?,
    );
  }
}
