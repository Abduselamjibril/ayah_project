import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';

void main() {
  group('Quran Core', () {
    test('Core constants are sane', () {
      expect(totalSurahCount, 114);
      expect(totalPagesCount, 604);
      expect(totalVerseCount, 6236);
      expect(totalJuzCount, 30);
    });

    test('Verse and page lookup returns values', () {
      // Basic invariants (these are stable for the bundled Mushaf data).
      expect(getPageNumber(1, 1), 1);
      expect(getPageNumber(2, 1), 2);

      final verse = getVerse(1, 1, verseEndSymbol: false);
      expect(verse.trim(), isNotEmpty);

      final endSymbol = getVerseEndSymbol(1);
      expect(endSymbol.startsWith('\u06dd'), isTrue);
    });
  });
}
