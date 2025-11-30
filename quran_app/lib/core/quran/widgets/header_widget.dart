import 'package:flutter/material.dart';
import './../data/page_font_size.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  const HeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),

      child: Container(
        decoration: const BoxDecoration(),
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image(
              image: const AssetImage("assets/images/mainframe.png"),
              width: getScreenType(context) == ScreenType.large ? 250 : 372,
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: "$suraNumber",
                style: TextStyle(
                  fontFamily: "arsura",
                  fontSize: getScreenType(context) == ScreenType.large
                      ? 16
                      : 29,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
