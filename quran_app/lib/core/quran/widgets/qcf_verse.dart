import 'package:flutter/widgets.dart';
import 'package:flutter/gestures.dart';
import './../data/quran_text.dart';
import './../data/page_font_size.dart';
import './../data/page_data.dart';

class QcfVerse extends StatelessWidget {
  final int surahNumber;
  final int verseNumber;
  final double? fontSize;
  final Color textColor;
  final Color backgroundColor;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressUp;
  final VoidCallback? onLongPressCancel;
  final Function(LongPressStartDetails)? onLongPressStart;
  final double sp;
  final double h;

  const QcfVerse({
    super.key,
    required this.surahNumber,
    required this.verseNumber,
    this.fontSize,
    this.textColor = const Color(0xFF000000),
    this.backgroundColor = const Color(0x00000000),
    this.onLongPress,
    this.onLongPressUp,
    this.onLongPressCancel,
    this.onLongPressStart,
    this.sp = 1,
    this.h = 1,
  });

  @override
  Widget build(BuildContext context) {
    final pageNumber = getPageNumber(surahNumber, verseNumber);
    final pageFontSize = getFontSize(pageNumber, context);
    final fontFamily = "QCF_P${pageNumber.toString().padLeft(3, '0')}";

    return _buildRichText(
      pageNumber: pageNumber,
      fontFamily: fontFamily,
      fontSize: fontSize ?? pageFontSize / sp,
    );
  }

  Widget _buildRichText({
    required int pageNumber,
    required String fontFamily,
    required double fontSize,
  }) {
    return RichText(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
      text: TextSpan(
        recognizer: _buildGestureRecognizer(),
        text: getVerseQCF(surahNumber, verseNumber, verseEndSymbol: false),
        locale: const Locale("ar"),
        children: [
          TextSpan(
            text: getVerseNumberQCF(surahNumber, verseNumber),
            style: TextStyle(
              fontFamily: fontFamily,
              height: 1.35 / h,
            ),
          ),
        ],
        style: TextStyle(
          color: textColor,
          height: 2.0 / h,
          letterSpacing: 0,
          wordSpacing: 0,
          fontFamily: fontFamily,
          fontSize: fontSize,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }

  LongPressGestureRecognizer _buildGestureRecognizer() {
    return LongPressGestureRecognizer()
      ..onLongPress = onLongPress
      ..onLongPressStart = onLongPressStart
      ..onLongPressUp = onLongPressUp
      ..onLongPressCancel = onLongPressCancel;
  }
}
