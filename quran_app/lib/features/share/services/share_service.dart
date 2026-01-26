import 'dart:io';
import 'package:flutter/material.dart';

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

    final calculatedHeight = _calculateContentHeight(
      surahNumber,
      ayahNumber,
      endAyahNumber,
      size,
      showSurahName,
      showPageNumber,
      showBadge,
    );

    print('ShareVerseImage: Size=$size, ContentHeight=$calculatedHeight');

    final bytes = await controller.captureFromWidget(
      Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SizedBox(
            width: size,
            height: calculatedHeight,
            child: ShareCard(
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
          ),
        ),
      ),
      pixelRatio: pixelRatio,
      targetSize: Size(size, calculatedHeight),
      delay: const Duration(milliseconds: 100), // Slight delay for fonts/assets
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

  double _calculateContentHeight(
    int surahNumber,
    int ayahNumber,
    int? endAyahNumber,
    double width,
    bool showSurahName,
    bool showPageNumber,
    bool showFooter,
  ) {
    final safePadding = width * 0.025;
    final contentWidth = width - (safePadding * 2);
    double totalHeight = safePadding * 1.6; // Top + Bottom padding (0.8 * 2)

    // Scale factor matching ShareCardDesign
    final double scaleFactor = width / 430;
    final double verseFontSize = 23 * scaleFactor;
    final double verseNumberFontSize = 23 * scaleFactor;

    // Surah Header
    if (showSurahName) {
      totalHeight += contentWidth * 0.22;
    }

    // Spacing
    // totalHeight += 0; // SizedBox(height: 0)

    // Ayah Body
    final lastAyah = endAyahNumber ?? ayahNumber;
    final spans = <InlineSpan>[];
    for (int i = ayahNumber; i <= lastAyah; i++) {
      final pageNumber = getPageNumber(surahNumber, i);
      final fontFamily = "QCF_P${pageNumber.toString().padLeft(3, '0')}";

      spans.add(TextSpan(
        text: getVerseQCF(surahNumber, i, verseEndSymbol: false),
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: verseFontSize,
          height: 1.7,
        ),
      ));
      spans.add(TextSpan(
        text: ' ${getVerseNumberQCF(surahNumber, i)} ',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: verseNumberFontSize,
          height: 1.7,
        ),
      ));
    }

    final textPainter = TextPainter(
      text: TextSpan(
          children: spans,
          style: TextStyle(fontSize: verseFontSize, height: 1.7)),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    textPainter.layout(maxWidth: contentWidth);
    totalHeight += textPainter.height;

    // Translation (Assumed null as per current impl)

    // Reference (Assumed false/null as per current impl)
    // _AyahBody: showReference: false (line 97)

    // Footer
    if (showFooter) {
      totalHeight += 18; // SizedBox(height: 18)
      // _ShareFooter estimate
      // Icon (30) + Spacing (4) + AppName (14 approx)
      double footerH = 30 + 4 + 14;
      if (showPageNumber) {
        footerH += 4 + 14;
      }
      totalHeight += footerH;
    }

    // Adjust for translation offset in ShareCardDesign (-size * 0.03)
    // This shifts body UP, so it overlaps header?
    // Effectively the visual height is reduced by this amount?
    // Or does it stick out?
    // Transform.translate affects painting, not layout.
    // But Column lays out assuming original size.
    // So the total height required by Column is the sum.
    // The Image needs to contain the Column.
    // We should be strictly summing layout heights.

    // Add a buffer just in case
    totalHeight += 50;

    return totalHeight;
  }
}
