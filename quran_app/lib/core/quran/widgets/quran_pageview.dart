import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';

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

  /// Scroll controller for vertical mode (smooth scrolling)
  final ScrollController? verticalScrollController;

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

  /// Optional style for the page number shown under each page.
  final TextStyle? pageNumberTextStyle;

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
    this.verticalScrollController,
    this.onPageChanged,
    this.fontSize,
    this.sp = 1,
    this.h = 1,
    this.textColor = const Color(0xFF000000),
    this.pageBackgroundColor = const Color(0xFFFFFFFF),
    this.pageNumberTextStyle,
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
  ScrollController? _internalVerticalController;
  int _currentPage = 1;
  double? _viewportHeight;

  PageController get _controller => widget.controller ?? _internalController!;
  ScrollController get _verticalController =>
      widget.verticalScrollController ?? _internalVerticalController!;

  bool get _ownsController => widget.controller == null;
  bool get _ownsVerticalController => widget.verticalScrollController == null;
  bool get _isVertical => widget.scrollMode == ScrollMode.vertical;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPageNumber;

    if (_ownsController && !_isVertical) {
      _internalController = PageController(
        initialPage: widget.initialPageNumber - 1,
      );
    }

    if (_isVertical) {
      _internalVerticalController = ScrollController();

      // Add scroll listener for vertical mode
      _verticalController.addListener(_handleVerticalScroll);

      // Calculate initial scroll position after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToPage(widget.initialPageNumber);
      });
    }
  }

  void _handleVerticalScroll() {
    if (!_isVertical || _viewportHeight == null || _viewportHeight! <= 0) {
      return;
    }

    final scrollOffset = _verticalController.offset;

    // Calculate current page based on scroll position
    final newPage = (scrollOffset / _viewportHeight!).round() + 1;

    // Ensure page is within valid range
    if (newPage >= 1 && newPage <= totalPagesCount && newPage != _currentPage) {
      _currentPage = newPage;
      widget.onPageChanged?.call(_currentPage);
    }
  }

  void _jumpToPage(int page) {
    if (!_isVertical || _viewportHeight == null || _viewportHeight! <= 0) {
      return;
    }

    if (page >= 1 && page <= totalPagesCount) {
      final offset = (page - 1) * _viewportHeight!;
      _verticalController.jumpTo(offset);
      _currentPage = page;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController?.dispose();
    }
    if (_ownsVerticalController) {
      _internalVerticalController?.removeListener(_handleVerticalScroll);
      _internalVerticalController?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Store viewport height for calculations
    _viewportHeight = MediaQuery.of(context).size.height;

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
        onPageChanged: (index) {
          _currentPage = index + 1;
          widget.onPageChanged?.call(_currentPage);
        },
        itemBuilder: (context, index) {
          final pageNumber = index + 1; // 1-based page
          return _PageWithNumber(
            backgroundColor: widget.pageBackgroundColor,
            pageNumber: pageNumber,
            pageNumberTextStyle: widget.pageNumberTextStyle,
            textColorFallback: widget.textColor,
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
    );
  }

  Widget _buildVerticalList(BuildContext context) {
    final viewportHeight = MediaQuery.of(context).size.height;

    return Container(
      color: widget.pageBackgroundColor,
      child: ListView.builder(
        controller: _verticalController,
        physics: const BouncingScrollPhysics(),
        itemCount: totalPagesCount,
        // Cache nearby pages for smoother scrolling
        cacheExtent: viewportHeight * 2, // Cache 2 pages above and below
        // Keep alive widgets to avoid rebuilding
        addAutomaticKeepAlives: true,
        // Add repaint boundaries automatically
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final pageNumber = index + 1;
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;

          return SizedBox(
            height: isLandscape ? null : viewportHeight,
            // Wrap each page in RepaintBoundary for better performance
            child: RepaintBoundary(
              child: _PageWithNumber(
                backgroundColor: widget.pageBackgroundColor,
                pageNumber: pageNumber,
                pageNumberTextStyle: widget.pageNumberTextStyle,
                textColorFallback: widget.textColor,
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
                  allowInternalScroll: false,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageWithNumber extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final TextStyle? pageNumberTextStyle;
  final Color textColorFallback;
  final Color backgroundColor;

  const _PageWithNumber({
    required this.child,
    required this.pageNumber,
    required this.textColorFallback,
    required this.backgroundColor,
    this.pageNumberTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = pageNumberTextStyle ??
        TextStyle(
          color: textColorFallback.withOpacity(0.6),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    return Container(
      color: backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: child),
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 8),
            child: Text(pageNumber.toString(), style: style),
          ),
        ],
      ),
    );
  }
}

class QuranPageContent extends StatefulWidget {
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

  final bool allowInternalScroll;

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
    this.allowInternalScroll = true,
  }) : super(key: key);

  @override
  State<QuranPageContent> createState() => _QuranPageContentState();
}

class _QuranPageContentState extends State<QuranPageContent>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(
        context); // Must call super when using AutomaticKeepAliveClientMixin
    final ranges = getPageData(widget.pageNumber);
    final pageFont = "QCF_P${widget.pageNumber.toString().padLeft(3, '0')}";
    final baseFontSize = getFontSize(widget.pageNumber, context) / widget.sp;

    final verseSpans = <InlineSpan>[];
    if (widget.pageNumber == 2 || widget.pageNumber == 1) {
      verseSpans.add(
        WidgetSpan(
          child: SizedBox(height: MediaQuery.of(context).size.height * .000001),
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
          if (widget.pageNumber != 1 && widget.pageNumber != 187) {
            if (surah != 97) {
              verseSpans.add(
                TextSpan(
                  text: " ﱁ  ﱂﱃﱄ\n",
                  style: TextStyle(
                    fontFamily: "QCF_P001",
                    fontSize: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? getScreenType(context) == ScreenType.large
                            ? 50 / widget.sp // Tablet landscape
                            : 35 / widget.sp // Phone landscape
                        : getScreenType(context) == ScreenType.large
                            ? 13.2 / widget.sp
                            : 24 / widget.sp,
                    color: widget.textColor,
                  ),
                ),
              );
            } else {
              verseSpans.add(
                TextSpan(
                  text: "齃𧻓𥳐龎\n",
                  style: TextStyle(
                    fontFamily: "QCF_BSML",
                    fontSize: MediaQuery.of(context).orientation ==
                            Orientation.landscape
                        ? getScreenType(context) == ScreenType.large
                            ? 45 / widget.sp // Tablet landscape
                            : 30 / widget.sp // Phone landscape
                        : getScreenType(context) == ScreenType.large
                            ? 13.2 / widget.sp
                            : 18 / widget.sp,
                    color: widget.textColor,
                  ),
                ),
              );
            }
          }
        }
        final spanRecognizer = LongPressGestureRecognizer();
        spanRecognizer.onLongPress = () => widget.onLongPress?.call(surah, v);
        spanRecognizer.onLongPressStart = (LongPressStartDetails d) =>
            widget.onLongPressStart?.call(surah, v, d);
        spanRecognizer.onLongPressUp =
            () => widget.onLongPressUp?.call(surah, v);
        spanRecognizer.onLongPressEnd =
            (LongPressEndDetails d) => widget.onLongPressCancel?.call(surah, v);

        final verseBgColor = widget.verseBackgroundColor?.call(surah, v);

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
                  color: widget.textColor,
                  height: 1.35 / widget.h,
                  backgroundColor: verseBgColor,
                ),
              ),
            ],
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenType = getScreenType(context);
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final isTablet = screenType == ScreenType.large;
        final useFitWidth = isLandscape;

        // Use contain for tablets to fill screen, scaleDown for others to avoid overflow
        final fitMode = isTablet ? BoxFit.contain : BoxFit.scaleDown;

        final content = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
          color: Colors.transparent,
          child: FittedBox(
            fit: useFitWidth ? BoxFit.fitWidth : fitMode,
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                minWidth: constraints.maxWidth,
              ),
              child: Text.rich(
                TextSpan(children: verseSpans),
                locale: const Locale("ar"),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  fontFamily: pageFont,
                  fontSize: baseFontSize,
                  color: widget.textColor,
                  height: (widget.pageNumber == 1 || widget.pageNumber == 2)
                      ? 2.2
                      : MediaQuery.of(context).systemGestureInsets.left > 0 ==
                              false
                          ? 2.2
                          : MediaQuery.of(context).viewPadding.top > 0
                              ? 2.2
                              : 2.2,
                ),
              ),
            ),
          ),
        );

        if (useFitWidth && widget.allowInternalScroll) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            child: content,
          );
        }

        return content;
      },
    );
  }
}
