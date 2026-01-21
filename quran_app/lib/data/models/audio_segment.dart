// lib/data/models/audio_segment.dart

/// Represents timestamp information for a single ayah within a chapter audio file
class AudioSegment {
  final String verseKey; // e.g., "1:1"
  final int timestampFrom; // Start time in milliseconds
  final int timestampTo; // End time in milliseconds
  final int duration; // Duration in milliseconds

  AudioSegment({
    required this.verseKey,
    required this.timestampFrom,
    required this.timestampTo,
    required this.duration,
  });

  /// Parse verse key to get surah and ayah numbers
  (int surah, int ayah) get verseNumbers {
    final parts = verseKey.split(':');
    if (parts.length == 2) {
      return (int.parse(parts[0]), int.parse(parts[1]));
    }
    return (0, 0);
  }

  /// Get ayah number from verse key
  int get ayahNumber {
    final parts = verseKey.split(':');
    return parts.length == 2 ? int.parse(parts[1]) : 0;
  }

  /// Get surah number from verse key
  int get surahNumber {
    final parts = verseKey.split(':');
    return parts.length == 2 ? int.parse(parts[0]) : 0;
  }

  /// Convert timestamp from milliseconds to seconds
  double get timestampFromSeconds => timestampFrom / 1000.0;

  /// Convert timestamp to milliseconds to seconds
  double get timestampToSeconds => timestampTo / 1000.0;

  /// Convert duration from milliseconds to seconds
  double get durationSeconds => duration / 1000.0;

  /// Check if a given position (in milliseconds) falls within this segment
  bool containsPosition(int positionMs) {
    return positionMs >= timestampFrom && positionMs < timestampTo;
  }

  factory AudioSegment.fromJson(Map<String, dynamic> json) {
    return AudioSegment(
      verseKey: json['verse_key'] as String? ?? '',
      timestampFrom: json['timestamp_from'] as int? ?? 0,
      timestampTo: json['timestamp_to'] as int? ?? 0,
      duration: json['duration'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'verse_key': verseKey,
        'timestamp_from': timestampFrom,
        'timestamp_to': timestampTo,
        'duration': duration,
      };

  @override
  String toString() =>
      'AudioSegment(verseKey: $verseKey, from: ${timestampFromSeconds}s, to: ${timestampToSeconds}s)';
}
