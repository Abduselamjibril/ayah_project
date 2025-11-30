import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import './../data/page_data.dart';
import './../data/quran_text.dart';
import './../data/page_font_size.dart';
import './../data/suwar.dart';
import 'header_widget.dart';
import 'qcf_verse.dart';

enum ScrollMode { horizontal, vertical }

/// A Quran mushaf that supports both horizontal (page-by-page) and vertical (continuous) scrolling.
class PageviewQuran extends StatefulWidget {
  /// 1-based initial page number (1..604) for horizontal mode
  final int initialPageNumber;

  /// Initial surah number (1..114) for vertical mode
  final int initialSurahNumber;

  /// Scroll mode - horizontal (page view) or vertical (continuous)
  final ScrollMode scrollMode;

  /// Optional external controller for horizontal mode.
  final PageController? controller;

  //sp (adding 1.sp to get the ratio of screen size for responsive font design)
  final double sp;

  //h (adding 1.h to get the ratio of screen size for responsive font design)
  final double h;

  /// Optional callback when page changes in horizontal mode. Provides 1-based page number.
  final ValueChanged<int>? onPageChanged;

  /// Optional callback when surah changes in vertical mode. Provides 1-based surah number.
  final ValueChanged<int>? onSurahChanged;

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
  )? onLongPressDown;

  const PageviewQuran({
    super.key,
    this.initialPageNumber = 1,
    this.initialSurahNumber = 1,
    this.scrollMode = ScrollMode.horizontal,
    this.controller,
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
    this.onLongPressDown,
  })  : assert(initialPageNumber >= 1 && initialPageNumber <= totalPagesCount),
        assert(initialSurahNumber >= 1 && initialSurahNumber <= 114);

  @override
  State<PageviewQuran> createState() => _PageviewQuranState();
}

class _PageviewQuranState extends State<PageviewQuran> {
  PageController? _internalController;
  final ScrollController _verticalController = ScrollController();
  int _currentSurah = 1;

  PageController get _pageController => widget.controller ?? _internalController!;

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _currentSurah = widget.initialSurahNumber;
    
    if (_ownsController && widget.scrollMode == ScrollMode.horizontal) {
      _internalController = PageController(
        initialPage: widget.initialPageNumber - 1,
      );
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _internalController?.dispose();
    }
    _verticalController.dispose();
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
      reverse: false, // right-to-left paging order
      itemCount: totalPagesCount,
      onPageChanged: (index) =>
          widget.onPageChanged?.call(index + 1), // 1-based
      itemBuilder: (context, index) {
        final pageNumber = index + 1; // 1-based page
        return _PageContent(
          pageNumber: pageNumber,
          fontSize: widget.fontSize,
          textColor: widget.textColor,
          verseBackgroundColor: widget.verseBackgroundColor,
          onLongPress: widget.onLongPress,
          onLongPressUp: widget.onLongPressUp,
          onLongPressCancel: widget.onLongPressCancel,
          onLongPressDown: widget.onLongPressDown,
          sp: widget.sp,
          h: widget.h,
        );
      },
    );
  }

  Widget _buildVerticalView() {
    return CustomScrollView(
      controller: _verticalController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final surahNumber = index + 1;
              return _SurahSection(
                surahNumber: surahNumber,
                fontSize: widget.fontSize,
                textColor: widget.textColor,
                verseBackgroundColor: widget.verseBackgroundColor,
                onLongPress: widget.onLongPress,
                onLongPressUp: widget.onLongPressUp,
                onLongPressCancel: widget.onLongPressCancel,
                onLongPressDown: widget.onLongPressDown,
                sp: widget.sp,
                h: widget.h,
                onSurahVisible: (surah) {
                  if (_currentSurah != surah) {
                    setState(() {
                      _currentSurah = surah;
                    });
                    widget.onSurahChanged?.call(surah);
                  }
                },
              );
            },
            childCount: 114, // Total surahs in Quran
          ),
        ),
      ],
    );
  }
}

class _PageContent extends StatelessWidget {
  final int pageNumber;
  final double? fontSize;
  final Color textColor;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;
  final void Function(int surahNumber, int verseNumber)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onLongPressUp;
  final void Function(int surahNumber, int verseNumber)? onLongPressCancel;
  final double sp;
  final double h;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressDown;

  const _PageContent({
    required this.pageNumber,
    required this.fontSize,
    required this.textColor,
    this.verseBackgroundColor,
    required this.onLongPress,
    required this.onLongPressUp,
    required this.onLongPressCancel,
    required this.onLongPressDown,
    required this.sp,
    required this.h,
  });

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
            (LongPressStartDetails d) => onLongPressDown?.call(surah, v, d);
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

class _SurahSection extends StatefulWidget {
  final int surahNumber;
  final double? fontSize;
  final Color textColor;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;
  final void Function(int surahNumber, int verseNumber)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onLongPressUp;
  final void Function(int surahNumber, int verseNumber)? onLongPressCancel;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressDown;
  final double sp;
  final double h;
  final void Function(int surahNumber)? onSurahVisible;

  const _SurahSection({
    required this.surahNumber,
    required this.fontSize,
    required this.textColor,
    this.verseBackgroundColor,
    required this.onLongPress,
    required this.onLongPressUp,
    required this.onLongPressCancel,
    required this.onLongPressDown,
    required this.sp,
    required this.h,
    this.onSurahVisible,
  });

  @override
  State<_SurahSection> createState() => _SurahSectionState();
}

class _SurahSectionState extends State<_SurahSection> {
  final GlobalKey _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfVisible();
    });
  }

  void _checkIfVisible() {
    final renderObject = _key.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final position = renderObject.localToGlobal(Offset.zero);
      final size = renderObject.size;

      if (position.dy < MediaQuery.of(context).size.height && 
          position.dy + size.height > 0) {
        widget.onSurahVisible?.call(widget.surahNumber);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final verseCount = getVerseCount(widget.surahNumber);
    
    return Column(
      key: _key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Surah header
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Surah ${getSurahName(widget.surahNumber)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Verses: $verseCount',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        // Verses
        ...List.generate(verseCount, (verseIndex) {
          final verseNumber = verseIndex + 1;
          return _VerseTile(
            surahNumber: widget.surahNumber,
            verseNumber: verseNumber,
            fontSize: widget.fontSize,
            textColor: widget.textColor,
            verseBackgroundColor: widget.verseBackgroundColor,
            onLongPress: widget.onLongPress,
            onLongPressUp: widget.onLongPressUp,
            onLongPressCancel: widget.onLongPressCancel,
            onLongPressDown: widget.onLongPressDown,
            sp: widget.sp,
            h: widget.h,
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _VerseTile extends StatelessWidget {
  final int surahNumber;
  final int verseNumber;
  final double? fontSize;
  final Color textColor;
  final Color? Function(int surahNumber, int verseNumber)? verseBackgroundColor;
  final void Function(int surahNumber, int verseNumber)? onLongPress;
  final void Function(int surahNumber, int verseNumber)? onLongPressUp;
  final void Function(int surahNumber, int verseNumber)? onLongPressCancel;
  final void Function(
    int surahNumber,
    int verseNumber,
    LongPressStartDetails details,
  )? onLongPressDown;
  final double sp;
  final double h;

  const _VerseTile({
    required this.surahNumber,
    required this.verseNumber,
    required this.fontSize,
    required this.textColor,
    this.verseBackgroundColor,
    required this.onLongPress,
    required this.onLongPressUp,
    required this.onLongPressCancel,
    required this.onLongPressDown,
    required this.sp,
    required this.h,
  });

  @override
  Widget build(BuildContext context) {
    final verseBgColor = verseBackgroundColor?.call(surahNumber, verseNumber);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onLongPress: () => onLongPress?.call(surahNumber, verseNumber),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: verseBgColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Arabic text using QcfVerse
              QcfVerse(
                surahNumber: surahNumber,
                verseNumber: verseNumber,
                fontSize: fontSize,
                textColor: textColor,
                backgroundColor: verseBgColor ?? Colors.transparent,
                onLongPress: () => onLongPress?.call(surahNumber, verseNumber),
                onLongPressUp: () => onLongPressUp?.call(surahNumber, verseNumber),
                onLongPressCancel: () => onLongPressCancel?.call(surahNumber, verseNumber),
                onLongPressDown: (details) => onLongPressDown?.call(surahNumber, verseNumber, details),
                sp: sp,
                h: h,
              ),
              const SizedBox(height: 8),
              // Verse info
              Text(
                'Surah $surahNumber, Verse $verseNumber',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}