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
    String? appLink,
  }) async {
    final surahName = getSurahName(surahNumber);
    final verseText =
        getVerseQCF(surahNumber, ayahNumber, verseEndSymbol: true);
    final link = appLink ?? defaultAppLink;
    final text = [
      '$surahName ($surahNumber:$ayahNumber)',
      verseText,
      link,
    ].join('\n\n');

    await Share.share(text);
  }

  Future<void> shareVerseImage({
    required int surahNumber,
    required int ayahNumber,
    required ShareCardBackground background,
    bool isDark = true,
    String? appName,
    String? appIconAsset,
    double pixelRatio = 2.0,
  }) async {
    final controller = ScreenshotController();
    final bytes = await controller.captureFromWidget(
      ShareCard(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        isDark: isDark,
        background: background,
        appName: appName ?? defaultAppName,
        appIconAsset: appIconAsset ?? defaultAppIconAsset,
        size: 2000,
      ),
      pixelRatio: pixelRatio,
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/ayah_${surahNumber}_$ayahNumber.png');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: '${getSurahName(surahNumber)} ($surahNumber:$ayahNumber)',
    );
  }
}
