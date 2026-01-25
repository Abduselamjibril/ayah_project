import 'package:flutter/material.dart';

import 'package:quran_app/core/services/theme_service.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  final VoidCallback? onLongPress;

  const HeaderWidget({
    super.key,
    required this.suraNumber,
    this.onLongPress,
  });

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

    return GestureDetector(
      onLongPress: onLongPress,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: const BoxDecoration(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: Image.asset(
                  frameAsset,
                  key: ValueKey<String>(frameAsset),
                  width: imageWidth,
                ),
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
      ),
    );
  }
}
