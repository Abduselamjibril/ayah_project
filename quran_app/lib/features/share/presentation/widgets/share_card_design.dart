import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/quran/widgets/qcf_verse.dart';

import 'share_card.dart';

class ShareCardDesign extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final bool isDark;
  final ShareCardBackground background;
  final String appName;
  final String appIconAsset;
  final String? translationText;
  final String? referenceText;
  final bool showReference;
  final double size;

  const ShareCardDesign({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isDark,
    required this.background,
    required this.appName,
    required this.appIconAsset,
    required this.translationText,
    required this.referenceText,
    required this.showReference,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final frameAsset = isDark
        ? 'assets/images/mainframe_dark.png'
        : 'assets/images/mainframe.png';
    final safePadding = size * 0.06;

    return SizedBox(
      width: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background.color ?? (isDark ? const Color(0xFF101417) : null),
          gradient: background.gradient,
        ),
        child: Stack(
          children: [
            if (background.imageAsset != null)
              Positioned.fill(
                child: Image.asset(
                  background.imageAsset!,
                  fit: BoxFit.cover,
                ),
              ),
            if (background.overlayOpacity > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(background.overlayOpacity),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: safePadding, vertical: safePadding * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SurahHeader(
                    frameAsset: frameAsset,
                    surahNumber: surahNumber,
                    size: size,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 8),
                  _AyahBody(
                    surahNumber: surahNumber,
                    ayahNumber: ayahNumber,
                    translationText: translationText,
                    textColor: textColor,
                    isDark: isDark,
                    showReference: false,
                    referenceText: '',
                  ),
                  const SizedBox(height: 18),
                  _ShareFooter(
                    appName: appName,
                    appIconAsset: appIconAsset,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SurahHeader extends StatelessWidget {
  final String frameAsset;
  final int surahNumber;
  final double size;
  final Color textColor;

  const _SurahHeader({
    required this.frameAsset,
    required this.surahNumber,
    required this.size,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageWidth = constraints.maxWidth;
        final fontSize = 35 * (imageWidth / 430);

        return SizedBox(
          height: imageWidth * 0.22,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                frameAsset,
                width: imageWidth,
                fit: BoxFit.contain,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    text: '$surahNumber',
                    style: TextStyle(
                      fontFamily: 'arsura',
                      fontSize: fontSize,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AyahBody extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final String? translationText;
  final Color textColor;
  final bool isDark;
  final String referenceText;
  final bool showReference;

  const _AyahBody({
    required this.surahNumber,
    required this.ayahNumber,
    required this.translationText,
    required this.textColor,
    required this.isDark,
    required this.referenceText,
    required this.showReference,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        QcfVerse(
          surahNumber: surahNumber,
          verseNumber: ayahNumber,
          textColor: textColor,
          fontSize: 76.5,
        ),
        if (translationText != null) ...[
          const SizedBox(height: 12),
          Text(
            translationText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              height: 1.5,
              color: textColor.withOpacity(0.7),
            ),
          ),
        ],
        if (showReference) ...[
          const SizedBox(height: 12),
          Text(
            referenceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 50,
              letterSpacing: 0.6,
              color: textColor.withOpacity(0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _ShareFooter extends StatelessWidget {
  final String appName;
  final String appIconAsset;
  final Color textColor;

  const _ShareFooter({
    required this.appName,
    required this.appIconAsset,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            appIconAsset,
            width: 95,
            height: 95,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          appName,
          style: TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.bold,
            color: textColor.withOpacity(0.3),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
