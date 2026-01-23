import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';

import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';

class ShareService {
  ShareService._();

  static final ShareService instance = ShareService._();

  static const String defaultAppName = 'Ayah App';
  static const String defaultAppIconAsset = 'assets/images/Icon.jpg';
  // TODO: Replace with the production app link once deployed.
  static const String defaultAppLink = 'https://app-link.example.com';

  Future<void> shareVerseText({
    required int surahNumber,
    required int ayahNumber,
    int? endAyahNumber,
    bool includeSurahName = true,
    bool includeReference = false,
    bool includeBadge = true,
    bool stripDiacritics = false,
    String? appLink,
  }) async {
    final surahName = getSurahName(surahNumber);

    // Resolve multiple verses if needed
    final lastAyah = endAyahNumber ?? ayahNumber;
    final buffer = StringBuffer();

    final reference =
        '$surahName ($surahNumber:$ayahNumber${lastAyah != ayahNumber ? '-$lastAyah' : ''})';
    if (includeSurahName || includeReference) {
      buffer.writeln(reference);
      buffer.writeln();
    }

    for (int i = ayahNumber; i <= lastAyah; i++) {
      var text = getVerse(surahNumber, i, verseEndSymbol: true);
      if (stripDiacritics) {
        text = removeDiacritics(text);
      }
      buffer.writeln(text);
    }

    if (includeBadge) {
      buffer.writeln('\nShared via Ayah App');
      buffer.writeln(appLink ?? defaultAppLink);
    }

    await Share.share(buffer.toString().trim());
  }

  Future<void> shareVerseImage({
    required int surahNumber,
    required int ayahNumber,
    int? endAyahNumber,
    required ShareCardBackground background,
    required double size,
    bool isDark = true,
    String? appName,
    String? appIconAsset,
    String? frameAsset,
    bool showSurahName = true,
    bool showPageNumber = false,
    bool showBadge = true,
    double pixelRatio = 2.0,
  }) async {
    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      ShareCard(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        endAyahNumber: endAyahNumber,
        isDark: isDark,
        background: background,
        appName: appName ?? defaultAppName,
        appIconAsset: appIconAsset ?? defaultAppIconAsset,
        size: size,
        frameAsset: frameAsset,
        showSurahName: showSurahName,
        showPageNumber: showPageNumber,
        showFooter: showBadge,
      ),
      pixelRatio: pixelRatio,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ayah_${surahNumber}_$ayahNumber.jpg');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text:
          '${getSurahName(surahNumber)} ($surahNumber:$ayahNumber${endAyahNumber != null ? '-$endAyahNumber' : ''})',
    );
  }
}
