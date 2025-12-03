import 'package:flutter/material.dart';
import './../data/page_font_size.dart';

class HeaderWidget extends StatelessWidget {
  final int suraNumber;
  static const _largeScreenWidth = 250.0;
  static const _smallScreenWidth = 372.0;
  static const _largeFontSize = 16.0;
  static const _smallFontSize = 29.0;

  const HeaderWidget({super.key, required this.suraNumber});

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = getScreenType(context) == ScreenType.large;
    final imagePath = _getImagePath(context);

    return Container(
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image(
            image: AssetImage(imagePath),
            width: isLargeScreen ? _largeScreenWidth : _smallScreenWidth,
            fit: BoxFit.contain,
          ),
          _buildSuraNumberText(context, isLargeScreen),
        ],
      ),
    );
  }

  String _getImagePath(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? "assets/images/mainframe_dark.png"
        : "assets/images/mainframe.png";
  }

  Widget _buildSuraNumberText(BuildContext context, bool isLargeScreen) {
    return Text(
      suraNumber.toString(),
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: "arsura",
        fontSize: isLargeScreen ? _largeFontSize : _smallFontSize,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}
