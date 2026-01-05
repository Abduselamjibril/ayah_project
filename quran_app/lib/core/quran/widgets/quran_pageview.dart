import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

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

  /// Controller for vertical index-based scrolling
  final ItemScrollController? itemScrollController;

  /// Listener for vertical item positions
  final ItemPositionsListener? itemPositionsListener;

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

  /// Optional builder to render a small widget after each verse (e.g. note icon).
  final Widget? Function(int surahNumber, int verseNumber)?
      verseTrailingBuilder;

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
    this.itemScrollController,
    this.itemPositionsListener,
    this.onPageChanged,
    this.fontSize,
    this.sp = 1,
    this.h = 1,
    this.textColor = const Color(0xFF000000),
    this.pageBackgroundColor = const Color(0xFFFFFFFF),
    this.pageNumberTextStyle,
    this.verseBackgroundColor,
    this.verseTrailingBuilder,
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
  // Removed _internalVerticalController as we now use ItemScrollController
  ItemScrollController? _internalItemScrollController;
  ItemPositionsListener? _internalItemPositionsListener;

  int _currentPage = 1;

  PageController get _controller => widget.controller ?? _internalController!;

  ItemScrollController get _itemScrollController =>
      widget.itemScrollController ?? _internalItemScrollController!;

  ItemPositionsListener get _itemPositionsListener =>
      widget.itemPositionsListener ?? _internalItemPositionsListener!;

  bool get _ownsController => widget.controller == null;
  bool get _ownsVerticalController => widget.itemScrollController == null;
  bool get _isVertical => widget.scrollMode == ScrollMode.vertical;

  // ... (existing methods)

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
      if (_ownsVerticalController) {
        _internalItemScrollController = ItemScrollController();
        _internalItemPositionsListener = ItemPositionsListener.create();
      }

      // Use ItemPositionsListener to update current page
      _itemPositionsListener.itemPositions.addListener(_handleItemPositions);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(index: widget.initialPageNumber - 1);
        }
      });
    }
  }

  void _handleItemPositions() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Find the item that covers the most screen area or is the top-most fully visible
    // Simple heuristic: The first item in the list is the "top" one.
    // Positions are not guaranteed to be sorted by index, so sorting helps.
    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final firstVisible = sorted.first;
    final newPage = firstVisible.index + 1;

    if (newPage >= 1 && newPage <= totalPagesCount && newPage != _currentPage) {
      _currentPage = newPage;
      widget.onPageChanged?.call(_currentPage);
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController?.dispose();
    }
    // ItemScrollController/Listener don't strictly need dispose, but we remove listener
    if (_isVertical) {
      _itemPositionsListener.itemPositions.removeListener(_handleItemPositions);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isVertical) {
      return _buildVerticalList(context);
    }
    return _buildHorizontalList(context);
  }

  _PageHeader _headerForPage(int pageNumber) {
    try {
      final pageData = getPageData(pageNumber);
      if (pageData.isEmpty) {
        return const _PageHeader(surahName: '', juzNumber: 0);
      }
      final first = pageData.first;
      final surah = int.tryParse(first['surah'].toString()) ?? 1;
      final start = int.tryParse(first['start'].toString()) ?? 1;
      final juz = getJuzNumber(surah, start);
      final name = getSurahName(surah);
      return _PageHeader(surahName: name, juzNumber: juz);
    } catch (_) {
      return const _PageHeader(surahName: '', juzNumber: 0);
    }
  }

  Widget _buildHorizontalList(BuildContext context) {
    return Container(
      color: widget.pageBackgroundColor,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          controller: _controller,
          itemCount: totalPagesCount,
          onPageChanged: (index) {
            _currentPage = index + 1;
            widget.onPageChanged?.call(_currentPage);
          },
          physics: const BouncingScrollPhysics(),
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            // For horizontal, we might not show headers inside the page if the app bar handles it,
            // but let's keep consistent with _PageWithNumber usage if acceptable.
            // Usually horizontal mode relies on external UI for Surah name.
            // We'll pass empty strings to avoid clutter, or maybe the same logic?
            // Let's pass empty for now as horizontal view usually has overlay.
            return RepaintBoundary(
              child: _PageWithNumber(
                backgroundColor: widget.pageBackgroundColor,
                pageNumber: pageNumber,
                pageNumberTextStyle: widget.pageNumberTextStyle,
                textColorFallback: widget.textColor,
                leftLabel: '',
                rightLabel: '',
                child: QuranPageContent(
                  pageNumber: pageNumber,
                  fontSize: widget.fontSize,
                  textColor: widget.textColor,
                  verseBackgroundColor: widget.verseBackgroundColor,
                  verseTrailingBuilder: widget.verseTrailingBuilder,
                  onLongPress: widget.onLongPress,
                  onLongPressUp: widget.onLongPressUp,
                  onLongPressCancel: widget.onLongPressCancel,
                  onLongPressStart: widget.onLongPressStart,
                  sp: widget.sp,
                  h: widget.h,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVerticalList(BuildContext context) {
    // We still use constraints to ensure full height, but ScrollablePositionedList handles the jumping
    final viewportHeight = MediaQuery.of(context).size.height;

    return Container(
      color: widget.pageBackgroundColor,
      child: MediaQuery.withNoTextScaling(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          physics: const BouncingScrollPhysics(),
          itemCount: totalPagesCount,
          initialScrollIndex: widget.initialPageNumber - 1,
          // Removed cacheExtent etc as they differ in this package
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            final header = _headerForPage(pageNumber);
            final isLandscape =
                MediaQuery.of(context).orientation == Orientation.landscape;

            return SizedBox(
              height: isLandscape ? null : viewportHeight,
              child: RepaintBoundary(
                child: _PageWithNumber(
                  backgroundColor: widget.pageBackgroundColor,
                  pageNumber: pageNumber,
                  pageNumberTextStyle: widget.pageNumberTextStyle,
                  textColorFallback: widget.textColor,
                  leftLabel: header.surahName,
                  rightLabel:
                      header.juzNumber > 0 ? "Part ${header.juzNumber}" : '',
                  child: QuranPageContent(
                    pageNumber: pageNumber,
                    fontSize: widget.fontSize,
                    textColor: widget.textColor,
                    verseBackgroundColor: widget.verseBackgroundColor,
                    verseTrailingBuilder: widget.verseTrailingBuilder,
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
      ),
    );
  }
}

class _PageHeader {
  final String surahName;
  final int juzNumber;

  const _PageHeader({required this.surahName, required this.juzNumber});
}

class _PageWithNumber extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final TextStyle? pageNumberTextStyle;
  final Color textColorFallback;
  final Color backgroundColor;
  final String leftLabel;
  final String rightLabel;

  const _PageWithNumber({
    required this.child,
    required this.pageNumber,
    required this.textColorFallback,
    required this.backgroundColor,
    required this.leftLabel,
    required this.rightLabel,
    this.pageNumberTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    final style = pageNumberTextStyle ??
        TextStyle(
          color: textColorFallback.withValues(alpha: 0.6),
          fontSize: 12.0,
          fontWeight: FontWeight.w500,
        );

    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              textDirection: TextDirection.ltr,
              children: [
                Text(
                  leftLabel,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                  textAlign: TextAlign.left,
                ),
                const Spacer(),
                Text(
                  rightLabel,
                  style: style,
                ),
              ],
            ),
          ),
          Flexible(fit: FlexFit.loose, child: child),
          SafeArea(
            top: false,
            left: false,
            right: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 8),
              child: _PageNumberWithBackground(
                pageNumber: pageNumber,
                textStyle: style,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget that displays the page number with a themed background image
class _PageNumberWithBackground extends StatelessWidget {
  final int pageNumber;
  final TextStyle textStyle;

  const _PageNumberWithBackground({
    required this.pageNumber,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final backgroundImage = themeService.pageBackgroundImagePath;

    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background decorative image
          Image.asset(
            backgroundImage,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback to plain text if image not found
              return const SizedBox.shrink();
            },
          ),
          // Page number text overlay
          Text(
            pageNumber.toString(),
            style: textStyle.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
  final Widget? Function(int surahNumber, int verseNumber)?
      verseTrailingBuilder;

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
    this.verseTrailingBuilder,
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
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final screenType = getScreenType(context);
    final isLargeScreen = screenType == ScreenType.large;

    final headerFontSize = isLandscape
        ? (isLargeScreen ? 50.0 : 35.0) / widget.sp
        : (isLargeScreen ? 13.2 : 24.0) / widget.sp;

    final bsmlFontSize = isLandscape
        ? (isLargeScreen ? 45.0 : 30.0) / widget.sp
        : (isLargeScreen ? 13.2 : 18.0) / widget.sp;

    final verseSpans = <InlineSpan>[];
    if (widget.pageNumber == 2 || widget.pageNumber == 1) {
      verseSpans.add(
        WidgetSpan(
          child: SizedBox(height: mediaQuery.size.height * .000001),
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
                    fontSize: headerFontSize,
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
                    fontSize: bsmlFontSize,
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
        final verseText = getVerseQCF(surah, v, verseEndSymbol: false);
        final text = v == ranges[0]['start']
            ? "${verseText.substring(0, 1)}\u200A${verseText.substring(1)}"
            : verseText;

        verseSpans.add(
          TextSpan(
            text: text,
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
              if (widget.verseTrailingBuilder != null)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: widget.verseTrailingBuilder!(surah, v) ??
                        const SizedBox.shrink(),
                  ),
                ),
            ],
          ),
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useFitWidth = isLandscape;

        // Use contain for tablets to fill screen, scaleDown for others to avoid overflow
        final fitMode = isLargeScreen ? BoxFit.contain : BoxFit.scaleDown;

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
                      : mediaQuery.systemGestureInsets.left > 0 == false
                          ? 2.2
                          : mediaQuery.viewPadding.top > 0
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
