import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';

import 'share_card.dart';

class ShareCardDesign extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final int? endAyahNumber;
  final bool isDark;
  final ShareCardBackground background;
  final String appName;
  final String appIconAsset;
  final String? frameAsset;
  final String? translationText;
  final String? referenceText;
  final bool showReference;
  final bool showSurahName;
  final bool showPageNumber;
  final double size;
  final bool showFooter;

  const ShareCardDesign({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    this.endAyahNumber,
    required this.isDark,
    required this.background,
    required this.appName,
    required this.appIconAsset,
    required this.translationText,
    required this.referenceText,
    required this.showReference,
    required this.showSurahName,
    required this.showPageNumber,
    required this.size,
    required this.showFooter,
    this.frameAsset,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final effectiveFrameAsset = frameAsset ??
        (isDark
            ? 'assets/images/mainframe_dark.png'
            : 'assets/images/mainframe.png');
    final safePadding = size * 0.025;

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
                  color:
                      Colors.black.withValues(alpha: background.overlayOpacity),
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: safePadding, vertical: safePadding * 0.8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showSurahName)
                    _SurahHeader(
                      frameAsset: effectiveFrameAsset,
                      surahNumber: surahNumber,
                      size: size,
                      textColor: textColor,
                    ),
                  const SizedBox(height: 0),
                  Transform.translate(
                    offset: Offset(0, -size * 0.03),
                    child: _AyahBody(
                      surahNumber: surahNumber,
                      ayahNumber: ayahNumber,
                      endAyahNumber: endAyahNumber,
                      translationText: translationText,
                      textColor: textColor,
                      isDark: isDark,
                      showReference: false,
                      referenceText: '',
                      size: size,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (showFooter)
                    _ShareFooter(
                      appName: appName,
                      appIconAsset: appIconAsset,
                      textColor: textColor,
                      showPageNumber: showPageNumber,
                      surahNumber: surahNumber,
                      ayahNumber: ayahNumber,
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
        final fontSize = 37 * (imageWidth / 430);

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
                padding: const EdgeInsets.only(top: 0),
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
  final int? endAyahNumber;
  final String? translationText;
  final Color textColor;
  final bool isDark;
  final String referenceText;
  final bool showReference;
  final double size;

  const _AyahBody({
    required this.surahNumber,
    required this.ayahNumber,
    this.endAyahNumber,
    required this.translationText,
    required this.textColor,
    required this.isDark,
    required this.referenceText,
    required this.showReference,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    // Scale font size based on width, assuming base width of ~430 (like header)
    final double scaleFactor = size / 430;
    final double verseFontSize = 23 * scaleFactor;
    final double verseNumberFontSize = 23 * scaleFactor;
    final double translationFontSize = 15 * scaleFactor;
    final double referenceFontSize = 18 * scaleFactor;

    final spans = <InlineSpan>[];
    final lastAyah = endAyahNumber ?? ayahNumber;

    for (int i = ayahNumber; i <= lastAyah; i++) {
      final pageNumber = getPageNumber(surahNumber, i);
      final fontFamily = "QCF_P${pageNumber.toString().padLeft(3, '0')}";

      spans.add(
        TextSpan(
          text: getVerseQCF(
            surahNumber,
            i,
            verseEndSymbol: false,
          ),
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: verseFontSize,
            color: textColor,
            height: 1.7, // Add height
          ),
        ),
      );

      // Add verse number symbol
      spans.add(
        TextSpan(
          text: ' ${getVerseNumberQCF(surahNumber, i)} ',
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: verseNumberFontSize,
            color: textColor, // Use accent color if desired, currently plain
            height: 1.7, // Add height
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(children: spans),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
        if (translationText != null) ...[
          SizedBox(height: 8 * scaleFactor),
          Text(
            translationText!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: translationFontSize,
              height: 1.4,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
        if (showReference) ...[
          SizedBox(height: 8 * scaleFactor),
          Text(
            referenceText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: referenceFontSize,
              letterSpacing: 0.4,
              color: textColor.withValues(alpha: 0.75),
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
  final bool showPageNumber;
  final int surahNumber;
  final int ayahNumber;

  const _ShareFooter({
    required this.appName,
    required this.appIconAsset,
    required this.textColor,
    this.showPageNumber = false,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            appIconAsset,
            width: 30,
            height: 30,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          appName,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: textColor.withValues(alpha: 0.3),
            letterSpacing: 0.8,
          ),
        ),
        if (showPageNumber) ...[
          const SizedBox(height: 4),
          Text(
            'Page ${getPageNumber(surahNumber, ayahNumber)}',
            style: TextStyle(
              fontSize: 10,
              color: textColor.withValues(alpha: 0.4),
            ),
          ),
        ],
      ],
    );
  }
}
