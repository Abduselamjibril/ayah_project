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
    String? appLink,
  }) async {
    final surahName = getSurahName(surahNumber);

    // Resolve multiple verses if needed
    final lastAyah = endAyahNumber ?? ayahNumber;
    final buffer = StringBuffer();

    for (int i = ayahNumber; i <= lastAyah; i++) {
      buffer.writeln(getVerse(surahNumber, i, verseEndSymbol: true));
    }
    final verseText = buffer.toString().trim();

    final link = appLink ?? defaultAppLink;
    final text = [
      '$surahName ($surahNumber:$ayahNumber${endAyahNumber != null ? '-$endAyahNumber' : ''})',
      verseText,
      'Shared via Ayah App',
      link,
    ].join('\n\n');

    await Share.share(text);
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
