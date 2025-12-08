import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:qcf_quran/qcf_quran.dart';

/// Scrolling direction for the mushaf widget.
enum ScrollMode { horizontal, vertical }

/// A horizontally swipeable Quran mushaf using internal QCF fonts.
///
/// - Uses `pageData` to determine surah/verse ranges for each page.
/// - Renders each verse with `QcfVerse`, which applies the correct per-page font.
/// - Supports RTL page order via `reverse: true` and `Directionality.rtl`.
class PageviewQuran extends StatefulWidget {
  /// 1-based initial page number (1..604)
  final int initialPageNumber;

  /// Choose horizontal paging (default) or vertically stacked pages.
  final ScrollMode scrollMode;

  /// Optional external controller. If not provided, an internal one is created.
  final PageController? controller;

  /// Scroll controller used when [scrollMode] is [ScrollMode.vertical].
  final ScrollController? verticalController;

  //sp (adding 1.sp to get the ratio of screen size for responsive font design)
  final double sp;

  //h (adding 1.h to get the ratio of screen size for responsive font design)
  final double h;

  /// Optional callback when page changes. Provides 1-based page number.
  final ValueChanged<int>? onPageChanged;

  /// Optional override font size passed to each `QcfVerse`.
  final double? fontSize;

  /// Verse text color.
  final Color textColor;

  /// Background color for the whole page container.
  final Color pageBackgroundColor;

  /// Optional callback to get background color for individual verses.
  /// Returns a Color for the verse, or null for no background color.
  /// Useful for highlighting selected verses.
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;

  /// Long-press callbacks that include the pressed verse info.
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
    this.scrollMode = ScrollMode.horizontal,
    this.controller,
    this.verticalController,
    this.onPageChanged,
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
  }) : assert(initialPageNumber >= 1 && initialPageNumber <= totalPagesCount);

  @override
  State<PageviewQuran> createState() => _PageviewQuranState();
}

class _PageviewQuranState extends State<PageviewQuran> {
  PageController? _internalController;
  ScrollController? _internalScrollController;
  int _lastReportedPage = 1;
  bool _initialVerticalPositionApplied = false;

  PageController get _controller => widget.controller ?? _internalController!;
  ScrollController get _verticalController =>
      widget.verticalController ?? _internalScrollController!;

  bool get _ownsController => widget.controller == null;
  bool get _ownsVerticalController => widget.verticalController == null;
  bool get _isVertical => widget.scrollMode == ScrollMode.vertical;

  @override
  void initState() {
    super.initState();
    _lastReportedPage = widget.initialPageNumber;

    if (!_isVertical && _ownsController) {
      _internalController = PageController(
        initialPage: widget.initialPageNumber - 1,
      );
    }

    if (_isVertical && _ownsVerticalController) {
      _internalScrollController = ScrollController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isVertical) {
        _ensureInitialVerticalOffset();
      }
    });
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController?.dispose();
    }
    if (_ownsVerticalController) {
      _internalScrollController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: _isVertical
          ? _buildVerticalList(context)
          : _buildHorizontalPager(context),
    );
  }

  Widget _buildHorizontalPager(BuildContext context) {
    return Container(
      color: widget.pageBackgroundColor,
      child: PageView.builder(
        controller: _controller,
        reverse: false, // right-to-left paging order
        itemCount: totalPagesCount,
        onPageChanged: (index) => widget.onPageChanged?.call(index + 1),
        itemBuilder: (context, index) {
          final pageNumber = index + 1; // 1-based page
          return QuranPageContent(
            pageNumber: pageNumber,
            fontSize: widget.fontSize,
            textColor: widget.textColor,
            verseBackgroundColor: widget.verseBackgroundColor,
            onLongPress: widget.onLongPress,
            onLongPressUp: widget.onLongPressUp,
            onLongPressCancel: widget.onLongPressCancel,
            onLongPressStart: widget.onLongPressStart,
            sp: widget.sp,
            h: widget.h,
          );
        },
      ),
    );
  }

  Widget _buildVerticalList(BuildContext context) {
    final pageHeight = MediaQuery.of(context).size.height;

    return Container(
      color: widget.pageBackgroundColor,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleVerticalScrollNotification,
        child: ListView.builder(
          controller: _verticalController,
          padding: EdgeInsets.zero,
          physics: const PageScrollPhysics(),
          itemCount: totalPagesCount,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return SizedBox(
              height: pageHeight,
              child: QuranPageContent(
                pageNumber: pageNumber,
                fontSize: widget.fontSize,
                textColor: widget.textColor,
                verseBackgroundColor: widget.verseBackgroundColor,
                onLongPress: widget.onLongPress,
                onLongPressUp: widget.onLongPressUp,
                onLongPressCancel: widget.onLongPressCancel,
                onLongPressStart: widget.onLongPressStart,
                sp: widget.sp,
                h: widget.h,
              ),
            );
          },
        ),
      ),
    );
  }

  void _ensureInitialVerticalOffset() {
    if (!_isVertical || _initialVerticalPositionApplied) return;

    if (!_verticalController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _ensureInitialVerticalOffset()); // wait for the controller to attach
      return;
    }

    final viewport = _verticalController.position.viewportDimension;
    if (viewport == 0) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureInitialVerticalOffset());
      return;
    }

    final targetOffset = (widget.initialPageNumber - 1) * viewport;
    final maxOffset = _verticalController.position.maxScrollExtent;

    _verticalController.jumpTo(targetOffset.clamp(0.0, maxOffset));
    _initialVerticalPositionApplied = true;
  }

  bool _handleVerticalScrollNotification(ScrollNotification notification) {
    if (!_isVertical || notification.metrics.viewportDimension == 0) {
      return false;
    }

    final page =
        (notification.metrics.pixels / notification.metrics.viewportDimension)
                .round() +
            1;
    final clampedPage = page.clamp(1, totalPagesCount);

    if (clampedPage != _lastReportedPage) {
      _lastReportedPage = clampedPage;
      widget.onPageChanged?.call(clampedPage);
    }

    return false;
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

  //sp (adding 1.sp to get the ratio of screen size for responsive font design)
  final double sp;

  //h (adding 1.h to get the ratio of screen size for responsive font design)
  final double h;

  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressStart;

  const QuranPageContent({
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ranges = getPageData(pageNumber);
    final pageFont = "QCF_P${pageNumber.toString().padLeft(3, '0')}";
    final baseFontSize = getFontSize(pageNumber, context) / sp;

    final verseSpans = <InlineSpan>[];
    if (pageNumber == 2 || pageNumber == 1) {
      verseSpans.add(
        WidgetSpan(
          child: SizedBox(height: MediaQuery.of(context).size.height * .175),
        ),
      );
    }
    for (final r in ranges) {
      final surah = int.parse(r['surah'].toString());
      final start = int.parse(r['start'].toString());
      final end = int.parse(r['end'].toString());

      for (int v = start; v <= end; v++) {
        if (v == start && v == 1) {
          verseSpans.add(WidgetSpan(child: HeaderWidget(suraNumber: surah)));
          if (pageNumber != 1 && pageNumber != 187) {
            if (surah != 97) {
              verseSpans.add(
                TextSpan(
                  text: " ﱁ  ﱂﱃﱄ\n",
                  style: TextStyle(
                    fontFamily: "QCF_P001",
                    package: 'qcf_quran',
                    fontSize: getScreenType(context) == ScreenType.large
                        ? 13.2 / sp
                        : 24 / sp,
                    color: Colors.black,
                  ),
                ),
              );
            } else {
              verseSpans.add(
                TextSpan(
                  text: "齃𧻓𥳐龎\n",
                  style: TextStyle(
                    fontFamily: "QCF_BSML",
                    package: 'qcf_quran',
                    fontSize: getScreenType(context) == ScreenType.large
                        ? 13.2 / sp
                        : 18 / sp,
                    color: Colors.black,
                  ),
                ),
              );
            }
          }
        }
        final spanRecognizer = LongPressGestureRecognizer();
        spanRecognizer.onLongPress = () => onLongPress?.call(surah, v);
        spanRecognizer.onLongPressStart =
            (LongPressStartDetails d) => onLongPressStart?.call(surah, v, d);
        spanRecognizer.onLongPressUp = () => onLongPressUp?.call(surah, v);
        spanRecognizer.onLongPressEnd =
            (LongPressEndDetails d) => onLongPressCancel?.call(surah, v);

        final verseBgColor = verseBackgroundColor?.call(surah, v);

        verseSpans.add(
          TextSpan(
            text: v == ranges[0]['start']
                ? "${getVerseQCF(surah, v, verseEndSymbol: false).substring(0, 1)}\u200A${getVerseQCF(surah, v, verseEndSymbol: false).substring(1, getVerseQCF(surah, v, verseEndSymbol: false).length)}"
                : getVerseQCF(surah, v, verseEndSymbol: false),
            recognizer: spanRecognizer,
            style: verseBgColor != null
                ? TextStyle(backgroundColor: verseBgColor)
                : null,
            children: [
              TextSpan(
                text: getVerseNumberQCF(surah, v),
                style: TextStyle(
                  fontFamily: pageFont,
                  package: 'qcf_quran',
                  color: Colors.brown,
                  height: 1.35 / h,
                  backgroundColor: verseBgColor,
                ),
              ),
            ],
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
      color: Colors.transparent,
      child: Text.rich(
        TextSpan(children: verseSpans),
        locale: const Locale("ar"),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: TextStyle(
          fontFamily: pageFont,
          package: 'qcf_quran',
          fontSize: baseFontSize,
          color: textColor,
          height: (pageNumber == 1 || pageNumber == 2)
              ? 2.2
              : MediaQuery.of(context).systemGestureInsets.left > 0 == false
                  ? 2.2
                  : MediaQuery.of(context).viewPadding.top > 0
                      ? 2.2
                      : 2.2,
        ),
      ),
    );
  }
}
