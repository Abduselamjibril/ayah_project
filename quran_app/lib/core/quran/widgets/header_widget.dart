import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/theme_service.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  const HeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    final frameAsset = ThemeService().mainframeImagePath;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: const BoxDecoration(),
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              frameAsset,
              width: MediaQuery.of(context).orientation == Orientation.landscape
                  ? getScreenType(context) == ScreenType.large
                      ? MediaQuery.of(context).size.width *
                          0.7 // Tablet landscape
                      : 600 // Phone landscape
                  : getScreenType(context) == ScreenType.large
                      ? 250
                      : 372,
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "$suraNumber",
                style: TextStyle(
                  fontFamily: "arsura",
                  fontSize: MediaQuery.of(context).orientation ==
                          Orientation.landscape
                      ? getScreenType(context) == ScreenType.large
                          ? 60 // Tablet landscape
                          : 45 // Phone landscape
                      : getScreenType(context) == ScreenType.large
                          ? 16
                          : 29,
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
