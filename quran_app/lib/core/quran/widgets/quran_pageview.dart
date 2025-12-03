import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import './../data/page_data.dart';
import './../data/quran_text.dart';
import './../data/page_font_size.dart';
import 'header_widget.dart';

enum ScrollMode { horizontal, vertical }

class PageviewQuran extends StatefulWidget {
  final int initialPageNumber;
  final int initialSurahNumber;
  final ScrollMode scrollMode;
  final PageController? controller;
  final ScrollController? verticalController;
  final double sp;
  final double h;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<int>? onSurahChanged;
  final double? fontSize;
  final Color textColor;
  final Color pageBackgroundColor;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;
  final void Function(int surahNumber, int verseNumber)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onLongPressUp;
  final void Function(int surahNumber, int verseNumber)? onLongPressCancel;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressStart;

  const PageviewQuran({
    super.key,
    this.initialPageNumber = 1,
    this.initialSurahNumber = 1,
    this.scrollMode = ScrollMode.horizontal,
    this.controller,
    this.verticalController,
    this.onPageChanged,
    this.onSurahChanged,
    this.fontSize,
    this.sp = 1,
    this.h = 1,
    this.textColor = const Color(0xFF000000),
    this.pageBackgroundColor = const Color(0xFFFFFFFF),
    this.verseBackgroundColor,
    this.onLongPress,
    this.onLongPressUp,
    this.onLongPressCancel,
    this.onLongPressStart,
  })  : assert(initialPageNumber >= 1 && initialPageNumber <= totalPagesCount),
        assert(initialSurahNumber >= 1 && initialSurahNumber <= 114);

  @override
  State<PageviewQuran> createState() => _PageviewQuranState();
}

class _PageviewQuranState extends State<PageviewQuran> {
  PageController? _internalController;
  ScrollController? _internalVerticalController;
  int _currentSurah = 1;

  PageController get _pageController =>
      widget.controller ?? _internalController!;

  ScrollController get _verticalController =>
      widget.verticalController ?? _internalVerticalController!;

  bool get _ownsController => widget.controller == null;
  bool get _ownsVerticalController => widget.verticalController == null;

  @override
  void initState() {
    super.initState();
    _currentSurah = widget.initialSurahNumber;

    if (_ownsController && widget.scrollMode == ScrollMode.horizontal) {
      _internalController = PageController(
        initialPage: widget.initialPageNumber - 1,
      );
    }

    if (_ownsVerticalController) {
      _internalVerticalController = ScrollController();
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController?.dispose();
    }
    if (_ownsVerticalController) {
      _internalVerticalController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: widget.pageBackgroundColor,
        child: widget.scrollMode == ScrollMode.horizontal
            ? _buildHorizontalView()
            : _buildVerticalView(),
      ),
    );
  }

  Widget _buildHorizontalView() {
    return PageView.builder(
      controller: _pageController,
      reverse: false,
      itemCount: totalPagesCount,
      onPageChanged: (index) => widget.onPageChanged?.call(index + 1),
      itemBuilder: (context, index) {
        return QuranPageContent(
          pageNumber: index + 1,
          fontSize: widget.fontSize,
          textColor: widget.textColor,
          verseBackgroundColor: widget.verseBackgroundColor,
          onLongPress: widget.onLongPress,
          onLongPressUp: widget.onLongPressUp,
          onLongPressCancel: widget.onLongPressCancel,
          onLongPressStart: widget.onLongPressStart,
          sp: widget.sp,
          h: widget.h,
          scrollMode: widget.scrollMode,
        );
      },
    );
  }

  Widget _buildVerticalView() {
    return ListView.builder(
      controller: _verticalController,
      physics: const ClampingScrollPhysics(),
      itemCount: totalPagesCount,
      itemBuilder: (context, index) {
        return SizedBox(
          height: MediaQuery.of(context).size.height,
          child: QuranPageContent(
            pageNumber: index + 1,
            fontSize: widget.fontSize,
            textColor: widget.textColor,
            verseBackgroundColor: widget.verseBackgroundColor,
            onLongPress: widget.onLongPress,
            onLongPressUp: widget.onLongPressUp,
            onLongPressCancel: widget.onLongPressCancel,
            onLongPressStart: widget.onLongPressStart,
            sp: widget.sp,
            h: widget.h,
            scrollMode: widget.scrollMode,
          ),
        );
      },
    );
  }
}

class QuranPageContent extends StatelessWidget {
  final int pageNumber;
  final double? fontSize;
  final Color textColor;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;
  final void Function(int surahNumber, int verseNumber)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onLongPressUp;
  final void Function(int surahNumber, int verseNumber)? onLongPressCancel;
  final double sp;
  final double h;
  final ScrollMode scrollMode;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressStart;

  const QuranPageContent({
    super.key,
    required this.pageNumber,
    required this.fontSize,
    required this.textColor,
    this.verseBackgroundColor,
    required this.onLongPress,
    required this.onLongPressUp,
    required this.onLongPressCancel,
    required this.onLongPressStart,
    required this.sp,
    required this.h,
    required this.scrollMode,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = getPageData(pageNumber);
    final padding = _calculatePadding(context);

    return Container(
      padding: padding,
      child: _buildPageText(context, ranges),
    );
  }

  EdgeInsets _calculatePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    double horizontalPadding;
    double verticalPadding;

    if (isTablet) {
      horizontalPadding = isLandscape ? 40.0 : 28.0;
      verticalPadding = isLandscape ? 16.0 : 12.0;
    } else {
      horizontalPadding = isLandscape ? 18.0 : 10.0;
      verticalPadding = 12.0;
    }

    return EdgeInsets.symmetric(
      horizontal: horizontalPadding,
      vertical: verticalPadding,
    );
  }

  Widget _buildPageText(
      BuildContext context, List<Map<String, dynamic>> ranges) {
    final pageFont = "QCF_P${pageNumber.toString().padLeft(3, '0')}";
    final baseFontSize = getFontSize(pageNumber, context) / sp;
    final verseSpans = _buildVerseSpans(context, ranges, pageFont);

    return Text.rich(
      TextSpan(children: verseSpans),
      locale: const Locale("ar"),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: pageFont,
        fontSize: fontSize ?? baseFontSize,
        color: textColor,
        height: _calculateLineHeight(context),
      ),
    );
  }

  List<InlineSpan> _buildVerseSpans(
    BuildContext context,
    List<Map<String, dynamic>> ranges,
    String pageFont,
  ) {
    final spans = <InlineSpan>[];

    // Add top spacing for first two pages
    if (pageNumber == 1 || pageNumber == 2) {
      spans.add(_buildTopSpacing(context));
    }

    for (final r in ranges) {
      final surah = int.parse(r['surah'].toString());
      final start = int.parse(r['start'].toString());
      final end = int.parse(r['end'].toString());

      for (int verse = start; verse <= end; verse++) {
        // Add header for first verse of surah
        if (verse == start && verse == 1) {
          spans.addAll(_buildSurahHeader(context, surah, pageNumber));
        }

        spans.add(_buildVerseSpan(
          context,
          surah,
          verse,
          pageFont,
          verse == start,
        ));
      }
    }

    return spans;
  }

  WidgetSpan _buildTopSpacing(BuildContext context) {
    final height = scrollMode == ScrollMode.horizontal
        ? MediaQuery.of(context).size.height * .175
        : MediaQuery.of(context).size.height * .1;

    return WidgetSpan(child: SizedBox(height: height));
  }

  List<InlineSpan> _buildSurahHeader(
      BuildContext context, int surah, int pageNumber) {
    final spans = <InlineSpan>[
      WidgetSpan(child: HeaderWidget(suraNumber: surah)),
    ];

    // Add basmalah if needed
    if (pageNumber != 1 && pageNumber != 187 && surah != 97) {
      spans.add(_buildBasmalah(context));
    } else if (surah == 97) {
      spans.add(_buildSurah97Basmalah(context));
    }

    return spans;
  }

  TextSpan _buildBasmalah(BuildContext context) {
    final isLarge = getScreenType(context) == ScreenType.large;
    return TextSpan(
      text: " ﱁ  ﱂﱃﱄ\n",
      style: TextStyle(
        fontFamily: "QCF_P001",
        fontSize: isLarge ? 13.2 / sp : 24 / sp,
        color: textColor,
      ),
    );
  }

  TextSpan _buildSurah97Basmalah(BuildContext context) {
    final isLarge = getScreenType(context) == ScreenType.large;
    return TextSpan(
      text: "齃𧻓𥳐龎\n",
      style: TextStyle(
        fontFamily: "QCF_BSML",
        fontSize: isLarge ? 13.2 / sp : 18 / sp,
        color: textColor,
      ),
    );
  }

  TextSpan _buildVerseSpan(
    BuildContext context,
    int surah,
    int verse,
    String pageFont,
    bool isFirstVerseOfPage,
  ) {
    final verseText = getVerseQCF(surah, verse, verseEndSymbol: false);
    final verseNumberText = getVerseNumberQCF(surah, verse);
    final verseBgColor = verseBackgroundColor?.call(surah, verse);

    final processedText = isFirstVerseOfPage && verse != 1
        ? "${verseText.substring(0, 1)}\u200A${verseText.substring(1)}"
        : verseText;

    return TextSpan(
      text: processedText,
      recognizer: _buildVerseRecognizer(surah, verse),
      style: verseBgColor != null
          ? TextStyle(backgroundColor: verseBgColor)
          : null,
      children: [
        TextSpan(
          text: verseNumberText,
          style: TextStyle(
            fontFamily: pageFont,
            color: textColor.withOpacity(0.7),
            height: 1.35 / h,
            backgroundColor: verseBgColor,
          ),
        ),
      ],
    );
  }

  LongPressGestureRecognizer _buildVerseRecognizer(int surah, int verse) {
    final recognizer = LongPressGestureRecognizer();

    recognizer.onLongPress = () => onLongPress?.call(surah, verse);
    recognizer.onLongPressStart =
        (details) => onLongPressStart?.call(surah, verse, details);
    recognizer.onLongPressUp = () => onLongPressUp?.call(surah, verse);
    recognizer.onLongPressCancel = () => onLongPressCancel?.call(surah, verse);

    return recognizer;
  }

  double _calculateLineHeight(BuildContext context) {
    // Use consistent line height for better rendering
    return 2.2;
  }
}
