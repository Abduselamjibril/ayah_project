import 'package:flutter/material.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card_design.dart';

class ShareCardBackground {
  final Color? color;
  final Gradient? gradient;
  final String? imageAsset;
  final double overlayOpacity;

  const ShareCardBackground({
    this.color,
    this.gradient,
    this.imageAsset,
    this.overlayOpacity = 0,
  });

  factory ShareCardBackground.solid(Color color) =>
      ShareCardBackground(color: color);

  factory ShareCardBackground.gradient(Gradient gradient) =>
      ShareCardBackground(gradient: gradient);

  factory ShareCardBackground.image(
    String asset, {
    double overlayOpacity = 0.45,
  }) =>
      ShareCardBackground(
        imageAsset: asset,
        overlayOpacity: overlayOpacity,
      );
}

class ShareCard extends StatelessWidget {
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
  final String? frameAsset;

  const ShareCard({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.isDark,
    required this.background,
    this.appName = 'Ayah App',
    this.appIconAsset = 'assets/images/Icon.jpg',
    this.translationText,
    this.referenceText,
    this.showReference = true,
    this.size = 1080,
    this.frameAsset,
  });

  @override
  Widget build(BuildContext context) {
    return ShareCardDesign(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
      isDark: isDark,
      background: background,
      appName: appName,
      appIconAsset: appIconAsset,
      translationText: translationText,
      referenceText: referenceText,
      showReference: showReference,
      size: size,
      frameAsset: frameAsset,
    );
  }
}
