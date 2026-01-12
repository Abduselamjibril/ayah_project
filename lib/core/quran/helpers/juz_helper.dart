import '../data/juzs.dart';

/// Helper class to work with Juz data
class JuzHelper {
  /// Get the Juz number for a specific Surah and Ayah
  /// Returns the Juz number (1-30) or 1 if not found
  static int getJuzNumber(int surahNumber, int ayahNumber) {
    for (final juzData in juz) {
      final verses = juzData['verses'] as Map<dynamic, dynamic>;

      // Check if this Juz contains the given Surah
      if (verses.containsKey(surahNumber)) {
        final verseRange = verses[surahNumber] as List<dynamic>;
        final startVerse = verseRange[0] as int;
        final endVerse = verseRange[1] as int;

        // Check if the ayah falls within this Juz's range for the Surah
        if (ayahNumber >= startVerse && ayahNumber <= endVerse) {
          return juzData['id'] as int;
        }
      }
    }

    // Default to Juz 1 if not found
    return 1;
  }

  /// Get Juz information by Juz number
  /// Returns a map containing id, surahs, and verses or null if not found
  static Map<String, dynamic>? getJuzInfo(int juzNumber) {
    try {
      return juz.firstWhere(
        (j) => j['id'] == juzNumber,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get the starting Surah for a Juz
  static int? getJuzStartingSurah(int juzNumber) {
    final juzInfo = getJuzInfo(juzNumber);
    if (juzInfo == null) return null;

    final surahs = juzInfo['surahs'] as List<dynamic>;
    return surahs.isNotEmpty ? surahs.first as int : null;
  }

  /// Get all Surahs in a Juz
  static List<int> getJuzSurahs(int juzNumber) {
    final juzInfo = getJuzInfo(juzNumber);
    if (juzInfo == null) return [];

    final surahs = juzInfo['surahs'] as List<dynamic>;
    return surahs.cast<int>();
  }
}
