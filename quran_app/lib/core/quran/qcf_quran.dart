/// qcf_quran — High-fidelity Quran Mushaf rendering using bundled QCF fonts.
///
/// Exposes widgets and helpers for rendering Quran pages locally without the
/// external `qcf_quran` package.
import 'data/page_data.dart';
import 'data/juzs.dart';
import 'data/suwar.dart';
import 'data/quran_text.dart';

import 'data/quarters.dart';

export 'widgets/qcf_verse.dart';
export 'widgets/quran_pageview.dart';
export 'widgets/header_widget.dart';
export 'data/page_font_size.dart';
export 'helpers/convert_to_arabic_number.dart';

List getPageData(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  return pageData[pageNumber - 1];
}

/// The most standard and common copy of Arabic-only Quran total pages count.
const int totalPagesCount = 604;

/// The constant total of makki surahs.
const int totalMakkiSurahs = 89;

/// The constant total of madani surahs.
const int totalMadaniSurahs = 25;

/// The constant total juz count.
const int totalJuzCount = 30;

/// The constant total surah count.
const int totalSurahCount = 114;

/// The constant total verse count.
const int totalVerseCount = 6236;

/// Takes [pageNumber] and returns total surahs count in that page.
int getSurahCountByPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  return pageData[pageNumber - 1].length;
}

/// Takes [pageNumber] and returns total verses count in that page.
int getVerseCountByPage(int pageNumber) {
  if (pageNumber < 1 || pageNumber > 604) {
    throw "Invalid page number. Page number must be between 1 and 604";
  }
  int totalVerseCount = 0;
  for (int i = 0; i < pageData[pageNumber - 1].length; i++) {
    totalVerseCount += int.parse(
      pageData[pageNumber - 1][i]!['end'].toString(),
    );
  }
  return totalVerseCount;
}

/// Takes [surahNumber] & [verseNumber] and returns Juz number.
int getJuzNumber(int surahNumber, int verseNumber) {
  for (var j in juz) {
    if (j['verses'].keys.contains(surahNumber)) {
      if (verseNumber >= j['verses'][surahNumber][0] &&
          verseNumber <= j['verses'][surahNumber][1]) {
        return int.parse(j['id'].toString());
      }
    }
  }
  return -1;
}

/// Takes [pageNumber] and returns the Hizb number if a Hizb starts on this page.
/// Returns -1 if no Hizb starts on this page.
int getHizbNumberForPage(int pageNumber) {
  for (int i = 0; i < quarters.length; i++) {
    // Check if this quarter is the start of a Hizb (every 4th quarter, 0-indexed)
    if (i % 4 == 0) {
      final q = quarters[i];
      final surah = int.parse(q['surah'].toString());
      final ayah = int.parse(q['ayah'].toString());

      try {
        final p = getPageNumber(surah, ayah);
        if (p == pageNumber) {
          // Hizb 1 starts at index 0. Hizb 2 starts at index 4.
          // Formula: (index / 4) + 1
          return (i ~/ 4) + 1;
        }
      } catch (_) {}
    }
  }
  return -1;
}

/// Takes [surahNumber] and returns the Surah name.
String getSurahName(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['name'].toString();
}

/// Takes [surahNumber] returns the Surah name in English.
String getSurahNameEnglish(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['english'].toString();
}

/// Takes [surahNumber] returns the Surah name in Arabic.
String getSurahNameArabic(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['arabic'].toString();
}

/// Takes [surahNumber], [verseNumber] and returns the page number of the Quran.
int getPageNumber(int surahNumber, int verseNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }

  for (int pageIndex = 0; pageIndex < pageData.length; pageIndex++) {
    for (int surahIndexInPage = 0;
        surahIndexInPage < pageData[pageIndex].length;
        surahIndexInPage++) {
      final e = pageData[pageIndex][surahIndexInPage];
      if (e['surah'] == surahNumber &&
          e['start'] <= verseNumber &&
          e['end'] >= verseNumber) {
        return pageIndex + 1;
      }
    }
  }

  throw "Invalid verse number.";
}

/// Takes [surahNumber] and returns the place of revelation (Makkah / Madinah) of the surah.
String getPlaceOfRevelation(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No Surah found with given surahNumber";
  }
  return surah[surahNumber - 1]['place'].toString();
}

/// Takes [surahNumber] and returns the count of total verses in the Surah.
int getVerseCount(int surahNumber) {
  if (surahNumber > 114 || surahNumber <= 0) {
    throw "No verse found with given surahNumber";
  }
  return int.parse(surah[surahNumber - 1]['aya'].toString());
}

/// Takes [surahNumber], [verseNumber] & [verseEndSymbol] (optional) and returns the verse in Arabic.
String getVerse(
  int surahNumber,
  int verseNumber, {
  bool verseEndSymbol = false,
}) {
  String verse = '';
  for (var i in quranText) {
    if (i['surah_number'] == surahNumber && i['verse_number'] == verseNumber) {
      verse = i['content'].toString();
      break;
    }
  }

  if (verse == '') {
    throw "No verse found with given surahNumber and verseNumber.";
  }

  return verse + (verseEndSymbol ? getVerseEndSymbol(verseNumber) : '');
}

/// Takes [verseNumber], [arabicNumeral] (optional) and returns '۝' symbol with verse number.
String getVerseEndSymbol(int verseNumber, {bool arabicNumeral = true}) {
  var arabicNumeric = '';
  var digits = verseNumber.toString().split('').toList();

  if (!arabicNumeral) return '\u06dd${verseNumber.toString()}';

  const Map arabicNumbers = {
    '0': '٠',
    '1': '۱',
    '2': '۲',
    '3': '۳',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '۷',
    '8': '۸',
    '9': '۹',
  };

  for (var e in digits) {
    arabicNumeric += arabicNumbers[e];
  }

  return '\u06dd$arabicNumeric';
}

Map<String, dynamic>? _quranTextIndex;

void _initQuranTextIndex() {
  if (_quranTextIndex != null) return;
  _quranTextIndex = {
    for (var item in quranText)
      "${item['surah_number']}:${item['verse_number']}": item
  };
}

String getVerseQCF(
  int surahNumber,
  int verseNumber, {
  bool verseEndSymbol = true,
}) {
  _initQuranTextIndex();
  final key = "$surahNumber:$verseNumber";
  final item = _quranTextIndex![key];

  if (item == null) {
    throw "No verse found with given surahNumber and verseNumber.";
  }

  final qcfData = item['qcfData'].toString();
  return verseEndSymbol ? qcfData : qcfData.substring(0, qcfData.length - 1);
}

String getVerseNumberQCF(
  int surahNumber,
  int verseNumber, {
  bool verseEndSymbol = true,
}) {
  _initQuranTextIndex();
  final key = "$surahNumber:$verseNumber";
  final item = _quranTextIndex![key];

  if (item == null) {
    throw "No verse found with given surahNumber and verseNumber.";
  }

  final qcfData = item['qcfData'].toString();
  return qcfData.substring(qcfData.length - 1);
}

Map searchWords(String words) {
  List<Map> result = [];
  for (var i in quranText) {
    if (i['text_normal'].toString().toLowerCase().contains(
          words.toLowerCase(),
        )) {
      if (result.length < 50) {
        result.add({
          'suraNumber': i['surah_number'],
          'verseNumber': i['verse_number'],
        });
      }
    }
  }
  if (result.isEmpty) {
    for (var i in quranText) {
      if (i['content'].toString().toLowerCase().contains(words.toLowerCase())) {
        if (result.length < 50) {
          result.add({
            'suraNumber': i['surah_number'],
            'verseNumber': i['verse_number'],
          });
        }
      }
    }
  }

  return {'occurences': result.length, 'result': result};
}

/// Converts Quran text to a normalized form suitable for search/comparison.
String normalise(String input) => input
    .replaceAll('\u0610', '')
    .replaceAll('\u0611', '')
    .replaceAll('\u0612', '')
    .replaceAll('\u0613', '')
    .replaceAll('\u0614', '')
    .replaceAll('\u0615', '')
    .replaceAll('\u0616', '')
    .replaceAll('\u0617', '')
    .replaceAll('\u0618', '')
    .replaceAll('\u0619', '')
    .replaceAll('\u061A', '')
    .replaceAll('\u06D6', '')
    .replaceAll('\u06D7', '')
    .replaceAll('\u06D8', '')
    .replaceAll('\u06D9', '')
    .replaceAll('\u06DA', '')
    .replaceAll('\u06DB', '')
    .replaceAll('\u06DC', '')
    .replaceAll('\u06DD', '')
    .replaceAll('\u06DE', '')
    .replaceAll('\u06DF', '')
    .replaceAll('\u06E0', '')
    .replaceAll('\u06E1', '')
    .replaceAll('\u06E2', '')
    .replaceAll('\u06E3', '')
    .replaceAll('\u06E4', '')
    .replaceAll('\u06E5', '')
    .replaceAll('\u06E6', '')
    .replaceAll('\u06E7', '')
    .replaceAll('\u06E8', '')
    .replaceAll('\u06E9', '')
    .replaceAll('\u06EA', '')
    .replaceAll('\u06EB', '')
    .replaceAll('\u06EC', '')
    .replaceAll('\u06ED', '')
    .replaceAll('\u0640', '')
    .replaceAll('\u064B', '')
    .replaceAll('\u064C', '')
    .replaceAll('\u064D', '')
    .replaceAll('\u064E', '')
    .replaceAll('\u064F', '')
    .replaceAll('\u0650', '')
    .replaceAll('\u0651', '')
    .replaceAll('\u0652', '')
    .replaceAll('\u0653', '')
    .replaceAll('\u0654', '')
    .replaceAll('\u0655', '')
    .replaceAll('\u0656', '')
    .replaceAll('\u0657', '')
    .replaceAll('\u0658', '')
    .replaceAll('\u0659', '')
    .replaceAll('\u065A', '')
    .replaceAll('\u065B', '')
    .replaceAll('\u065C', '')
    .replaceAll('\u065D', '')
    .replaceAll('\u065E', '')
    .replaceAll('\u065F', '')
    .replaceAll('\u0670', '')
    .replaceAll('\u0624', '\u0648')
    .replaceAll('\u0629', '\u0647')
    .replaceAll('\u064A', '\u0649')
    .replaceAll('\u0626', '\u0649')
    .replaceAll('\u0622', '\u0627')
    .replaceAll('\u0623', '\u0627')
    .replaceAll('\u0625', '\u0627');

/// Removes Arabic diacritics (tashkeel) from the input text.
String removeDiacritics(String input) {
  Map<String, String> diacriticsMap = {
    'َ': '',
    'ُ': '',
    'ِ': '',
    'ّ': '',
    'ً': '',
    'ٌ': '',
    'ٍ': '',
  };

  String diacriticsPattern =
      diacriticsMap.keys.map((e) => RegExp.escape(e)).join('|');
  RegExp exp = RegExp('[$diacriticsPattern]');

  String textWithoutDiacritics = input.replaceAll(exp, '');

  return textWithoutDiacritics;
}
