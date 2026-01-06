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
              width: 372, // Fixed reference width
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "$suraNumber",
                style: TextStyle(
                  fontFamily: "arsura",
                  fontSize: 29, // Fixed reference font size
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
