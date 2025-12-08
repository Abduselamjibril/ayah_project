import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  const HeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final frameAsset = isDark
        ? "assets/images/mainframe_dark.png"
        : "assets/images/mainframe.png";

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
              width: getScreenType(context) == ScreenType.large ? 250 : 372,
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "$suraNumber",
                style: TextStyle(
                  fontFamily: "arsura",
                  fontSize:
                      getScreenType(context) == ScreenType.large ? 16 : 29,
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
