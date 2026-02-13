import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
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

  /// Callback when user long-presses on a surah header.
  final void Function(int surahNumber)? onSurahHeaderLongPress;

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
    this.onSurahHeaderLongPress,
  }) : assert(initialPageNumber >= 1 && initialPageNumber <= totalPagesCount);

  @override
  State<PageviewQuran> createState() => _PageviewQuranState();
}

class _PageviewQuranState extends State<PageviewQuran> {
  final Map<int, _PageHeader> _headerCache = {};
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
      setState(() {
        _currentPage = newPage;
      });
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
    if (_headerCache.containsKey(pageNumber)) {
      return _headerCache[pageNumber]!;
    }
    try {
      final pageData = getPageData(pageNumber);
      if (pageData.isEmpty) {
        return const _PageHeader(surahNumber: 0, juzNumber: 0);
      }
      final first = pageData.first;
      final surah = int.tryParse(first['surah'].toString()) ?? 1;
      final start = int.tryParse(first['start'].toString()) ?? 1;
      final juz = getJuzNumber(surah, start);
      final header = _PageHeader(surahNumber: surah, juzNumber: juz);
      _headerCache[pageNumber] = header;
      return header;
    } catch (_) {
      return const _PageHeader(surahNumber: 0, juzNumber: 0);
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
            setState(() {
              _currentPage = index + 1;
            });
            widget.onPageChanged?.call(_currentPage);
          },
          dragStartBehavior: DragStartBehavior.down,
          physics: const PageScrollPhysics(
            parent: BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
          ),
          allowImplicitScrolling: true,
          pageSnapping: true,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            final header = _headerForPage(pageNumber);

            return RepaintBoundary(
              child: _PageWithNumber(
                backgroundColor: widget.pageBackgroundColor,
                pageNumber: pageNumber,
                pageNumberTextStyle: widget.pageNumberTextStyle,
                textColorFallback: widget.textColor,
                leftLabel: header.surahNumber > 0
                    ? getBilingualSurahName(context, header.surahNumber)
                    : '',
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
                  onSurahHeaderLongPress: widget.onSurahHeaderLongPress,
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
    return ColoredBox(
      color: widget.pageBackgroundColor,
      child: MediaQuery.withNoTextScaling(
        child: ScrollablePositionedList.builder(
          itemScrollController: _itemScrollController,
          itemPositionsListener: _itemPositionsListener,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          itemCount: totalPagesCount,
          initialScrollIndex: widget.initialPageNumber - 1,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            final header = _headerForPage(pageNumber);

            return RepaintBoundary(
              child: _PageWithNumber(
                isVertical: true,
                backgroundColor: widget.pageBackgroundColor,
                pageNumber: pageNumber,
                pageNumberTextStyle: widget.pageNumberTextStyle,
                textColorFallback: widget.textColor,
                leftLabel: header.surahNumber > 0
                    ? getBilingualSurahName(context, header.surahNumber)
                    : '',
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
                  onSurahHeaderLongPress: widget.onSurahHeaderLongPress,
                  sp: widget.sp,
                  h: widget.h,
                  allowInternalScroll: false,
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
  final int surahNumber;
  final int juzNumber;

  const _PageHeader({required this.surahNumber, required this.juzNumber});
}

class _PageWithNumber extends StatelessWidget {
  final Widget child;
  final int pageNumber;
  final TextStyle? pageNumberTextStyle;
  final Color textColorFallback;
  final Color backgroundColor;
  final String leftLabel;
  final String rightLabel;
  final bool isVertical;

  static const double _footerPaddingTop = 0.0;
  static const double _footerPaddingBottom = 0.0;

  const _PageWithNumber({
    required this.child,
    required this.pageNumber,
    required this.textColorFallback,
    required this.backgroundColor,
    required this.leftLabel,
    required this.rightLabel,
    this.pageNumberTextStyle,
    this.isVertical = false,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = pageNumberTextStyle ??
        TextStyle(
          color: textColorFallback.withOpacity(0.6),
          fontSize: 15.0,
          fontWeight: FontWeight.w500,
        );
    final double baseFontSize = baseStyle.fontSize ?? 15.0;
    final surahLabelStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: baseFontSize,
    );
    final metaLabelStyle = baseStyle.copyWith(fontWeight: FontWeight.w700);

    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;
    final isTablet = mediaQuery.size.shortestSide >= 600;

    // Widen reference for Tablet/Landscape
    final isWideReference = isLandscape || isTablet;
    final double referenceWidth = isWideReference ? 600.0 : 430.0;

    // Layout Logic determined by User Request:
    // 1. Wide Mode (Landscape OR Tablet): Scrollable (fitWidth), constrained to 85% of screen.
    // 2. Phone Portrait: Fixed (contain), full width/height.

    final bool isWideLayout = isLandscape || isTablet;

    final bool enableScrolling = isWideLayout || isVertical;
    final BoxFit fitMode = isWideLayout ? BoxFit.fitWidth : BoxFit.contain;

    // The scalable content with fixed reference size
    Widget scaledContent = FittedBox(
      fit: fitMode,
      child: Container(
        width: referenceWidth,
        height: 932, // Reference Height
        color: backgroundColor,
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(
                    child: Text(
                      leftLabel,
                      overflow: TextOverflow.ellipsis,
                      style: surahLabelStyle,
                      textAlign: TextAlign.left,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    rightLabel,
                    style: metaLabelStyle,
                  ),
                ],
              ),
            ),
            Expanded(child: child),
            SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: _footerPaddingBottom,
                  top: _footerPaddingTop,
                ),
                child: _PageNumberWithBackground(
                  pageNumber: pageNumber,
                  textStyle: metaLabelStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (enableScrolling) {
      // Wide Mode: 85% width constraint + Scrolling
      Widget content = scaledContent;
      if (isWideLayout && !isVertical) {
        content = SizedBox(
          width: mediaQuery.size.width * 0.85,
          child: scaledContent,
        );
      }

      return Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: content,
        ),
      );
    } else {
      // Phone Portrait: Contain (No Scroll)
      return Center(child: scaledContent);
    }
  }
}

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

    // Hizb Logic
    final hizbNumber = getHizbNumberForPage(pageNumber);
    final hasHizb = hizbNumber != -1;
    final isEven = pageNumber % 2 == 0;

    // Page Number Widget
    final pageNumberWidget = SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            backgroundImage,
            width: 60,
            height: 60,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const SizedBox.shrink();
            },
          ),
          Text(
            pageNumber.toString(),
            style: textStyle.copyWith(
              fontSize: 15,
            ),
          ),
        ],
      ),
    );

    // Hizb Widget
    Widget hizbWidget;
    if (hasHizb) {
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      hizbWidget = Container(
        width: 60,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFFFACC15).withOpacity(0.18)
              : const Color(0xFFB45309).withOpacity(0.09),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFFFACC15).withOpacity(0.4)
                : const Color(0xFFB45309).withOpacity(0.18),
          ),
        ),
        child: Text(
          "Hizb $hizbNumber",
          style: textStyle.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color:
                isDarkMode ? const Color(0xFFFACC15) : const Color(0xFFB45309),
          ),
        ),
      );
    } else {
      hizbWidget = const SizedBox(width: 60, height: 32);
    }

    // Layout: Even = Page Left, Hizb Right; Odd = Hizb Left, Page Right
    List<Widget> children;
    if (isEven) {
      children = [pageNumberWidget, hizbWidget];
    } else {
      children = [hizbWidget, pageNumberWidget];
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: children,
        ),
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

  /// Callback when user long-presses on a surah header.
  final void Function(int surahNumber)? onSurahHeaderLongPress;

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
    this.onSurahHeaderLongPress,
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

  final GlobalKey _paragraphKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    super.build(
        context); // Must call super when using AutomaticKeepAliveClientMixin
    final ranges = getPageData(widget.pageNumber);
    final pageFont = "QCF_P${widget.pageNumber.toString().padLeft(3, '0')}";
    final baseFontSize = getFontSize(widget.pageNumber, context) / widget.sp;

    // Fixed reference sizes
    final headerFontSize = 24.0 / widget.sp;
    final bsmlFontSize = 18.0 / widget.sp;

    final verseSpans = <InlineSpan>[];
    final highlightRanges = <_HighlightRange>[];
    var textOffset = 0;
    if (widget.pageNumber == 2 || widget.pageNumber == 1) {
      verseSpans.add(
        const WidgetSpan(
          child: SizedBox(height: 1),
        ),
      );
      textOffset += 1; // WidgetSpan placeholder
    }
    const lineHeight = 2.1; // consistent line spacing across all lines

    for (final r in ranges) {
      final surah = int.parse(r['surah'].toString());
      final start = int.parse(r['start'].toString());
      final end = int.parse(r['end'].toString());

      for (int v = start; v <= end; v++) {
        if (v == start && v == 1) {
          verseSpans.add(WidgetSpan(
            child: HeaderWidget(
              suraNumber: surah,
              onLongPress: () => widget.onSurahHeaderLongPress?.call(surah),
            ),
          ));
          textOffset += 1; // WidgetSpan placeholder

          verseSpans.add(const TextSpan(text: "\n"));
          textOffset += 1;

          if (widget.pageNumber == 1 || widget.pageNumber == 2) {
            verseSpans.add(const TextSpan(text: "\n"));
            textOffset += 1;
          }

          if (widget.pageNumber != 1 && widget.pageNumber != 187) {
            if (surah != 97) {
              const t = " ﱁ  ﱂﱃﱄ\n";
              verseSpans.add(
                TextSpan(
                  text: t,
                  style: TextStyle(
                    fontFamily: "QCF_P001",
                    fontSize: headerFontSize,
                  ),
                ),
              );
              textOffset += t.length;
            } else {
              const t = "齃𧻓𥳐龎\n";
              verseSpans.add(
                TextSpan(
                  text: t,
                  style: TextStyle(
                    fontFamily: "QCF_BSML",
                    fontSize: bsmlFontSize,
                  ),
                ),
              );
              textOffset += t.length;
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
        final verseStart = textOffset;
        textOffset += text.length;
        final verseNumberText = getVerseNumberQCF(surah, v);
        textOffset += verseNumberText.length;
        final verseEnd = textOffset;
        if (verseBgColor != null) {
          highlightRanges.add(
            _HighlightRange(
              start: verseStart,
              end: verseEnd,
              color: verseBgColor,
            ),
          );
        }

        verseSpans.add(
          TextSpan(
            text: text,
            recognizer: spanRecognizer,
            children: [
              TextSpan(
                text: verseNumberText,
                style: TextStyle(
                  fontFamily: pageFont,
                  color: widget.textColor,
                  height: lineHeight,
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
        if (widget.verseTrailingBuilder != null) {
          textOffset += 1; // WidgetSpan placeholder
        }
      }
    }

    // Strict ratio lock: lay out the text once (no reflow), then scale it uniformly
    // to fit the available box. Keep constraints finite to avoid infinite width.
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 5.0),
          color: Colors.transparent,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: ConstrainedBox(
              // Keep constraints finite for FittedBox while letting the text
              // honor its intrinsic line breaks (header/basmala).
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth,
                maxHeight: constraints.maxHeight,
              ),
              child: CustomPaint(
                painter: _RoundedVerseHighlightPainter(
                  paragraphKey: _paragraphKey,
                  ranges: highlightRanges,
                  radius: 8,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 4,
                  ),
                ),
                child: Text.rich(
                  TextSpan(
                    children: verseSpans,
                    style: TextStyle(
                      fontFamily: pageFont,
                      fontSize: baseFontSize,
                      color: widget.textColor,
                      height: lineHeight,
                    ),
                  ),
                  key: _paragraphKey,
                  locale: const Locale("ar"),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  softWrap: true,
                  textWidthBasis: TextWidthBasis.longestLine,
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: true,
                    applyHeightToLastDescent: true,
                    leadingDistribution: TextLeadingDistribution.even,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HighlightRange {
  final int start;
  final int end;
  final Color color;

  const _HighlightRange({
    required this.start,
    required this.end,
    required this.color,
  });
}

class _RoundedVerseHighlightPainter extends CustomPainter {
  final GlobalKey paragraphKey;
  final List<_HighlightRange> ranges;
  final double radius;
  final EdgeInsets padding;
  final double tightenFactor;

  const _RoundedVerseHighlightPainter({
    required this.paragraphKey,
    required this.ranges,
    required this.radius,
    required this.padding,
    this.tightenFactor = 0.26,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (ranges.isEmpty) return;
    final renderObject = paragraphKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;

    final paint = Paint()..isAntiAlias = true;
    for (final r in ranges) {
      final boxes = renderObject.getBoxesForSelection(
        TextSelection(baseOffset: r.start, extentOffset: r.end),
        boxHeightStyle: ui.BoxHeightStyle.tight,
        boxWidthStyle: ui.BoxWidthStyle.tight,
      );

      paint.color = r.color;
      for (final b in boxes) {
        final rect = Rect.fromLTRB(b.left, b.top, b.right, b.bottom);
        // The mushaf text uses a large line height for readability; the raw
        // selection boxes include that leading, which makes highlights too tall.
        // Tighten the box vertically so the highlight hugs the script.
        final tighten = rect.height * tightenFactor;
        final tightenedTop = rect.top + tighten;
        final tightenedBottom = rect.bottom - tighten;
        final tightened = tightenedBottom > tightenedTop
            ? Rect.fromLTRB(
                rect.left, tightenedTop, rect.right, tightenedBottom)
            : rect;

        final padded = Rect.fromLTRB(
          tightened.left - padding.left,
          tightened.top - padding.top,
          tightened.right + padding.right,
          tightened.bottom + padding.bottom,
        );

        final maxRadius = padded.shortestSide / 2;
        final rRadius =
            Radius.circular(radius < maxRadius ? radius : maxRadius);
        canvas.drawRRect(
          RRect.fromRectAndRadius(padded, rRadius),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoundedVerseHighlightPainter oldDelegate) {
    return oldDelegate.paragraphKey != paragraphKey ||
        oldDelegate.radius != radius ||
        oldDelegate.padding != padding ||
        oldDelegate.ranges.length != ranges.length ||
        !_sameRanges(oldDelegate.ranges, ranges);
  }

  bool _sameRanges(List<_HighlightRange> a, List<_HighlightRange> b) {
    for (var i = 0; i < a.length; i++) {
      final ar = a[i];
      final br = b[i];
      if (ar.start != br.start || ar.end != br.end || ar.color != br.color) {
        return false;
      }
    }
    return true;
  }
}
