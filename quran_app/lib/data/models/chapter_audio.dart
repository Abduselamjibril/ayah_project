// lib/data/models/chapter_audio.dart

import 'audio_segment.dart';

/// Represents a complete chapter (Surah) audio file with timestamp segments for each ayah
class ChapterAudio {
  final int id; // Audio file ID
  final int chapterId; // Surah number
  final int fileSize; // File size in bytes
  final String format; // Audio format (e.g., "mp3")
  final String audioUrl; // URL to the complete Surah audio file
  final List<AudioSegment> segments; // Timestamp data for each ayah

  ChapterAudio({
    required this.id,
    required this.chapterId,
    required this.fileSize,
    required this.format,
    required this.audioUrl,
    required this.segments,
  });

  /// Find the segment for a specific ayah number
  AudioSegment? getSegmentByAyah(int ayahNumber) {
    try {
      return segments.firstWhere((seg) => seg.ayahNumber == ayahNumber);
    } catch (_) {
      return null;
    }
  }

  /// Find which ayah is playing at a given position (in milliseconds)
  int? getAyahAtPosition(int positionMs) {
    for (final segment in segments) {
      if (segment.containsPosition(positionMs)) {
        return segment.ayahNumber;
      }
    }
    return null;
  }

  /// Get total duration in milliseconds (from the last segment)
  int get totalDuration {
    if (segments.isEmpty) return 0;
    return segments.last.timestampTo;
  }

  /// Get total duration in seconds
  double get totalDurationSeconds => totalDuration / 1000.0;

  factory ChapterAudio.fromJson(Map<String, dynamic> json) {
    final audioFile = json['audio_file'] as Map<String, dynamic>? ?? json;

    final segmentsList =
        (audioFile['timestamps'] ?? audioFile['segments'] ?? []) as List;
    final segments = segmentsList
        .map((seg) => AudioSegment.fromJson(seg as Map<String, dynamic>))
        .toList();

    // Handle file_size as either int or double (API returns 839808.0 as double)
    final fileSizeValue = audioFile['file_size'];
    final fileSize = fileSizeValue is double
        ? fileSizeValue.toInt()
        : (fileSizeValue as int? ?? 0);

    return ChapterAudio(
      id: audioFile['id'] as int? ?? 0,
      chapterId: audioFile['chapter_id'] as int? ?? 0,
      fileSize: fileSize,
      format: audioFile['format'] as String? ?? 'mp3',
      audioUrl: audioFile['audio_url'] as String? ?? '',
      segments: segments,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter_id': chapterId,
        'file_size': fileSize,
        'format': format,
        'audio_url': audioUrl,
        'timestamps': segments.map((seg) => seg.toJson()).toList(),
      };

  @override
  String toString() =>
      'ChapterAudio(id: $id, chapter: $chapterId, segments: ${segments.length}, size: ${fileSize}b)';
}
