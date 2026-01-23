import 'package:flutter/material.dart';

import 'package:quran_app/core/services/theme_service.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  const HeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    final frameAsset = ThemeService().mainframeImagePath;

    // logic must match _PageWithNumber in quran_pageview.dart
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;
    final isWideMode = isLandscape || isTablet;

    final referenceWidth = isWideMode ? 600.0 : 430.0;

    final imageWidth = referenceWidth * 0.85;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: const BoxDecoration(),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              frameAsset,
              width: imageWidth,
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "$suraNumber",
                style: TextStyle(
                  fontFamily: "arsura",
                  fontSize:
                      29, // Fixed reference font size (scales with fittedbox)
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
