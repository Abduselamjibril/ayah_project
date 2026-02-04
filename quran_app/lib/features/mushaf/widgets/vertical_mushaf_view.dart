import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/features/audio_player/audio_player_screen.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/highlights/state/highlight_notifier.dart';
import 'package:quran_app/features/mushaf/controller/mushaf_controller.dart';

import 'surah_info_sheet.dart';
import 'verse_options_sheet.dart';
import 'page_settings_sheet.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

// Result type for the verse menu editor dialog

class VerticalMushafView extends StatefulWidget {
  final MushafController controller;
  final ValueChanged<bool>? onOverlayVisibilityChanged;

  const VerticalMushafView({
    super.key,
    required this.controller,
    this.onOverlayVisibilityChanged,
  });

  @override
  State<VerticalMushafView> createState() => _VerticalMushafViewState();
}

class _VerticalMushafViewState extends State<VerticalMushafView> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  int _lastPage = 1;
  double? _sliderValue;
  final ValueNotifier<double> _livePageNotifier = ValueNotifier(1.0);

  // _livePage state removed in favor of notifier

  bool _isSliderActive = false;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  Timer? _highlightClearTimer;

  double _contentOpacity = 1.0;
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  bool _isFading = false;

  bool _isAutoScrolling = false;
  bool _autoScrollControlsVisible = false;
  double _autoScrollSpeed = 30.0;
  int _scrollGeneration = 0;

  // Track if audio player is expanded
  bool _audioPlayerExpanded = false;

  StreamSubscription<int>? _navSubscription;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.controller.currentPage;
    _sliderValue = _lastPage.toDouble();
    _livePageNotifier.value = _lastPage.toDouble();
    _audioPlayer = AudioPlayerService.instance;

    _ayahListener = () {
      if (!mounted) return;
      final s = _audioPlayer.currentSurah.value;
      final a = _audioPlayer.currentAyah.value;
      if (s != null && a != null) {
        widget.controller.setHighlightedVerse(s, a);
      } else {
        widget.controller.clearHighlight();
      }
    };

    _audioPlayer.currentSurah.addListener(_ayahListener);
    _audioPlayer.currentAyah.addListener(_ayahListener);

    _navSubscription = widget.controller.navigationStream.listen((page) {
      if (_itemScrollController.isAttached) {
        _stopAutoScroll();
        _lastPage = page;
        _livePageNotifier.value = page.toDouble(); // Update notifier
        _itemScrollController.jumpTo(index: page - 1);
      }
    });

    _itemPositionsListener.itemPositions.addListener(_onVisibleItemsChanged);

    widget.controller.addListener(_onControllerChanged);
    _scheduleAutoHide();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_itemScrollController.isAttached) {
        _itemScrollController.jumpTo(index: widget.controller.currentPage - 1);
      }
      widget.onOverlayVisibilityChanged?.call(true);
    });
  }

  void _onVisibleItemsChanged() {
    if (_isSliderActive) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    final firstVisible = sorted.first;
    final live = (firstVisible.index + 1 - firstVisible.itemLeadingEdge)
        .clamp(1.0, 604.0);

    // Update notifier instead of calling setState via _setLivePage
    if ((_livePageNotifier.value - live).abs() > 0.001) {
      _livePageNotifier.value = live;
    }

    final page = live.round().clamp(1, 604);
    if (page != _lastPage) {
      _lastPage = page;
      widget.controller.setPage(page);
    }
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    _itemPositionsListener.itemPositions.removeListener(_onVisibleItemsChanged);
    _audioPlayer.currentSurah.removeListener(_ayahListener);
    _audioPlayer.currentAyah.removeListener(_ayahListener);
    widget.controller.removeListener(_onControllerChanged);
    _stopAutoScroll();
    _autoHideTimer?.cancel();
    _highlightClearTimer?.cancel();
    _livePageNotifier.dispose(); // Dispose notifier
    super.dispose();
  }

  void _cancelHighlightClear() {
    _highlightClearTimer?.cancel();
    _highlightClearTimer = null;
  }

  void _scheduleHighlightClear() {
    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      widget.controller.clearHighlight();
    });
  }

  void _navigateToVerseWithTempHighlight(int surah, int verse) {
    _cancelHighlightClear();
    widget.controller.navigateToVerse(surah, verse);
    _scheduleHighlightClear();
  }

  void _onControllerChanged() {
    if (widget.controller.currentPage != _lastPage) {
      final isAudioActive = _audioPlayer.isPlaying.value ||
          _audioPlayer.hasSourceNotifier.value ||
          _audioPlayer.isDownloading.value;
      if (isAudioActive) {
        unawaited(_audioPlayer.stop());
      }
      _lastPage = widget.controller.currentPage;
      _sliderValue = null;
      _isSliderActive = false;
      _livePageNotifier.value = widget.controller.currentPage.toDouble();
    }
  }

  double _getDisplayPage() {
    if (_isSliderActive && _sliderValue != null) return _sliderValue!;
    return _livePageNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkState = context.watch<BookmarkNotesNotifier>();
    final highlightState = context.watch<HighlightNotifier>();

    return Stack(
      children: [
        AnimatedOpacity(
          duration: _fadeDuration,
          curve: Curves.easeInOut,
          opacity: _contentOpacity,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _toggleOverlay,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final sidePadding =
                    ResponsiveLayout.scaled(context, 6, min: 4, max: 12);
                final availableWidth =
                    math.max(0.0, constraints.maxWidth - (sidePadding * 2));
                final maxWidth = math.min(
                  availableWidth,
                  ResponsiveLayout.scaled(context, 900, min: 740, max: 1080),
                );
                final topMargin = MediaQuery.paddingOf(context).top +
                    ResponsiveLayout.scaled(context, 12, min: 8, max: 16);
                final contentHeight =
                    math.max(0.0, constraints.maxHeight - topMargin);

                return Center(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: topMargin,
                      left: sidePadding,
                      right: sidePadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxWidth,
                        maxHeight: contentHeight,
                      ),
                      child: NotificationListener<UserScrollNotification>(
                        onNotification: (notification) {
                          if (_isAutoScrolling) {
                            _stopAutoScroll();
                          }
                          return false;
                        },
                        child: ListenableBuilder(
                          listenable: Listenable.merge(
                              [widget.controller, ThemeService()]),
                          builder: (context, _) {
                            return PageviewQuran(
                              initialPageNumber: widget.controller.currentPage,
                              scrollMode: ScrollMode.vertical,
                              itemScrollController: _itemScrollController,
                              itemPositionsListener: _itemPositionsListener,
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              pageBackgroundColor: ThemeService()
                                  .getMushafBackgroundColor(
                                      Theme.of(context).brightness),
                              verseBackgroundColor: (s, v) =>
                                  _getVerseBackgroundColor(bookmarkState, s, v),
                              onLongPress: (surah, verse) => _showVerseOptions(
                                  context, bookmarkState, surah, verse),
                              onLongPressStart: (surah, verse, details) =>
                                  widget.controller
                                      .setHighlightedVerse(surah, verse),
                              onLongPressCancel: (surah, verse) =>
                                  widget.controller.clearHighlight(),
                              onSurahHeaderLongPress: (surahNumber) {
                                showSurahInfoSheet(
                                  context: context,
                                  surahNumber: surahNumber,
                                  onNavigateToVerse: (verseNumber) {
                                    Navigator.pop(context);
                                    _navigateToVerseWithTempHighlight(
                                        surahNumber, verseNumber);
                                  },
                                );
                              },
                              sp: 1.0,
                              h: 1.0,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        _buildSideSlider(),
        _buildPageIndicator(),
      ],
    );
  }

  Color? _getVerseBackgroundColor(
      BookmarkNotesNotifier state, int surah, int verse) {
    final highlightedSurah = widget.controller.highlightedSurah;
    final highlightedVerse = widget.controller.highlightedVerse;
    if (highlightedSurah == surah && highlightedVerse == verse) {
      return Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5);
    }
    // Highlight logic
    final highlight =
        context.read<HighlightNotifier>().getHighlight(surah, verse);
    if (highlight != null) {
      final color = Color(_parseColor(highlight.colorHex));
      return color.withOpacity(0.25);
    }
    // Bookmark logic
    final b = state.bookmarkForVerse(surah, verse);
    if (b != null) {
      if (b.isKhatmahPin) {
        return null;
      }
      final color = Color(_parseColor(b.colorHex));
      return color.withOpacity(0.25);
    }
    return null;
  }

  Widget _buildPageIndicator() {
    if (!_overlayVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ValueListenableBuilder<double>(
        valueListenable: _livePageNotifier,
        builder: (context, livePage, _) {
          return ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              final currentDouble = _getDisplayPage();
              final currentPage = currentDouble.round();
              final surahName = _surahNameForPage(currentPage);
              final isSliding = _isSliderActive;
              final panelMaxWidth =
                  ResponsiveLayout.scaled(context, 540, min: 360, max: 640);
              final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
              final bottomInset = MediaQuery.paddingOf(context).bottom;
              final extraBottom =
                  ResponsiveLayout.scaled(context, 8, min: 6, max: 14);
              final bottomPad = (isIOS ? bottomInset * 0.5 : bottomInset) +
                  (isIOS ? extraBottom * 0.6 : extraBottom);
              return RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSliding
                          ? Card(
                              elevation: 12,
                              color: Theme.of(context).colorScheme.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      surahName,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Page ${currentPage.toString().padLeft(2, '0')}',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 8),
                    _buildAudioPlayerCard(),
                    const SizedBox(height: 8),
                    Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: panelMaxWidth),
                        child: Card(
                          elevation: 16,
                          margin: EdgeInsets.zero,
                          color: Theme.of(context).colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              ResponsiveLayout.scaled(context, 12,
                                  min: 10, max: 16),
                              ResponsiveLayout.scaled(context, 2,
                                  min: 1, max: 4),
                              ResponsiveLayout.scaled(context, 12,
                                  min: 10, max: 16),
                              bottomPad,
                            ),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _NotesIcon(
                                    onTap: _openPageSettingsSheet,
                                  ),
                                  const Spacer(),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Text(
                                              'Auto-Scroll',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_isAutoScrolling) ...[
                                              IconButton(
                                                icon: const Icon(Icons
                                                    .remove_circle_outline),
                                                color: BrandColors.accent
                                                    .withOpacity(0.8),
                                                onPressed: () =>
                                                    _changeAutoScrollSpeed(-5),
                                              ),
                                              const SizedBox(width: 4),
                                            ],
                                            Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                                onTap: () {
                                                  setState(() {
                                                    _overlayVisible = true;
                                                  });
                                                  if (!_autoScrollControlsVisible) {
                                                    _autoScrollControlsVisible =
                                                        true;
                                                    _startAutoScroll();
                                                  } else if (_isAutoScrolling) {
                                                    _stopAutoScroll();
                                                  } else {
                                                    _startAutoScroll();
                                                  }
                                                  _scheduleAutoHide();
                                                },
                                                onLongPress:
                                                    _showAutoScrollSpeedSheet,
                                                child: Container(
                                                  width: 92,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant
                                                        .withOpacity(0.35),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            22),
                                                  ),
                                                  alignment: Alignment.center,
                                                  child:
                                                      !_autoScrollControlsVisible
                                                          ? Icon(
                                                              Icons
                                                                  .arrow_downward,
                                                              size: 26,
                                                              color: BrandColors
                                                                  .accent
                                                                  .withOpacity(
                                                                      0.9),
                                                            )
                                                          : Icon(
                                                              _isAutoScrolling
                                                                  ? Icons
                                                                      .pause_circle_filled
                                                                  : Icons
                                                                      .play_circle_fill,
                                                              size: 32,
                                                              color: BrandColors
                                                                  .accent
                                                                  .withOpacity(
                                                                      _isAutoScrolling
                                                                          ? 1.0
                                                                          : 0.9),
                                                            ),
                                                ),
                                              ),
                                            ),
                                            if (_isAutoScrolling) ...[
                                              const SizedBox(width: 4),
                                              IconButton(
                                                icon: const Icon(
                                                    Icons.add_circle_outline),
                                                color: BrandColors.accent
                                                    .withOpacity(0.8),
                                                onPressed: () =>
                                                    _changeAutoScrollSpeed(5),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  _NavPill(
                                    icon: Icons.subdirectory_arrow_left,
                                    label: currentPage > 1
                                        ? '${currentPage - 1}'
                                        : '',
                                    enabled: currentPage > 1,
                                    onTap: () =>
                                        _navigateWithFade(currentPage - 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSideSlider() {
    if (!_overlayVisible) return const SizedBox.shrink();
    final media = MediaQuery.of(context);
    final top = media.padding.top + 64;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final baseBottom = _audioPlayerExpanded ? 250 : 170;
    final bottom =
        media.padding.bottom + (isIOS ? baseBottom - 24 : baseBottom);
    final compactSlider = _audioPlayerExpanded;

    return ValueListenableBuilder<double>(
      valueListenable: _livePageNotifier,
      builder: (context, livePage, _) {
        final currentDouble = _getDisplayPage();
        final currentPage = currentDouble.round();

        return Positioned(
          left: 10,
          top: top,
          bottom: bottom,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              const pillHeight = 26.0;
              final trackHeight =
                  (height - pillHeight).clamp(1.0, double.infinity);

              // Responsive font size based on screen width
              final screenWidth = MediaQuery.of(context).size.width;
              double fontSize = 12;
              if (screenWidth < 300) {
                final media = MediaQuery.of(context);
                final top = media.padding.top +
                    48; // Reduce top padding for more height
                // Add extra bottom padding if audio player is expanded
                final bottom = media.padding.bottom +
                    (_audioPlayerExpanded
                        ? 220
                        : 120); // Reduce bottom padding for more height

                return ValueListenableBuilder<double>(
                  valueListenable: _livePageNotifier,
                  builder: (context, livePage, _) {
                    final currentDouble = _getDisplayPage();
                    final currentPage = currentDouble.round();

                    return Positioned(
                      left: 4, // Move slider closer to the edge
                      top: top,
                      bottom: bottom,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final height = constraints.maxHeight;
                          final pillHeight = compactSlider
                              ? 34.0
                              : 40.0; // Increased pill height
                          final trackHeight =
                              (height - pillHeight).clamp(1.0, double.infinity);

                          // Responsive font size based on screen width
                          final screenWidth = MediaQuery.of(context).size.width;
                          double fontSize = compactSlider ? 14 : 16;
                          if (screenWidth < 300) {
                            fontSize = 12;
                          } else if (screenWidth < 400) {
                            fontSize = compactSlider ? 12 : 13;
                          } else if (screenWidth > 600) {
                            fontSize = compactSlider ? 16 : 18;
                          }

                          void handleDrag(double dy) {
                            final clamped =
                                (dy - pillHeight / 2).clamp(0, trackHeight);
                            final t = clamped / trackHeight;
                            final value = 1 + t * 603;
                            _stopAutoScroll();
                            setState(() {
                              _isSliderActive = true;
                              _sliderValue = value;
                              _overlayVisible = true;
                            });
                            _scheduleAutoHide();
                          }

                          void handleEnd() {
                            final value = (_sliderValue ?? currentDouble)
                                .clamp(1.0, 604.0);
                            final page = value.round();
                            _navigateWithFade(page).then((_) {
                              if (mounted) {/* Lines 637-641 omitted */}
                            });
                            _scheduleAutoHide();
                          }

                          final t = (currentDouble - 1) / 603;
                          final pillTop =
                              (trackHeight * t).clamp(0, trackHeight);

                          // Colors for progress and background (theme-based, mushaf page aware)
                          final Color passedColor = Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest;
                          final Color notPassedColor =
                              Theme.of(context).colorScheme.surface;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanDown: (details) =>
                                handleDrag(details.localPosition.dy),
                            onPanUpdate: (details) =>
                                handleDrag(details.localPosition.dy),
                            onPanEnd: (_) => handleEnd(),
                            onTapDown: (details) =>
                                handleDrag(details.localPosition.dy),
                            onTapUp: (_) => handleEnd(),
                            child: Container(
                              width: compactSlider ? 40 : 48,
                              decoration: BoxDecoration(
                                color: notPassedColor,
                                borderRadius:
                                    BorderRadius.circular(14), // More rounded
                                // Removed boxShadow for no shadow
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .outline
                                      .withOpacity(0.18),
                                  width: 1.2,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Passed area (darker area)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    height: pillTop + pillHeight / 2,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: passedColor,
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(14),
                                          bottom: Radius.circular(0),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // The pill
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: pillTop.toDouble(),
                                    height: pillHeight,
                                    child: Center(
                                      child: Container(
                                        width: compactSlider ? 36 : 44,
                                        height: pillHeight,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withOpacity(0.18),
                                            width: 1.2,
                                          ),
                                          // No shadow
                                        ),
                                        child: Center(
                                          child: Text(
                                            currentPage.toString(),
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                              fontWeight: FontWeight.bold,
                                              fontSize: fontSize,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              }
              // Normal slider for wider screens
              void handleDrag(double dy) {
                final clamped = (dy - pillHeight / 2).clamp(0, trackHeight);
                final t = clamped / trackHeight;
                final value = 1 + t * 603;
                _stopAutoScroll();
                setState(() {
                  _isSliderActive = true;
                  _sliderValue = value;
                  _overlayVisible = true;
                });
                _scheduleAutoHide();
              }

              void handleEnd() {
                final value = (_sliderValue ?? currentDouble).clamp(1.0, 604.0);
                final page = value.round();
                _navigateWithFade(page).then((_) {
                  if (mounted) {/* Lines 637-641 omitted */}
                });
                _scheduleAutoHide();
              }

              final t = (currentDouble - 1) / 603;
              final pillTop = (trackHeight * t).clamp(0, trackHeight);
              final normalPillHeight = compactSlider ? 22.0 : pillHeight;
              final normalBarWidth = compactSlider ? 26.0 : 32.0;

              // Colors for progress and background (theme-based, mushaf page aware)
              final Color passedColor =
                  Theme.of(context).colorScheme.surfaceContainerHighest;
              final Color notPassedColor =
                  Theme.of(context).colorScheme.surface;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (details) => handleDrag(details.localPosition.dy),
                onPanUpdate: (details) => handleDrag(details.localPosition.dy),
                onPanEnd: (_) => handleEnd(),
                onTapDown: (details) => handleDrag(details.localPosition.dy),
                onTapUp: (_) => handleEnd(),
                child: Container(
                  width: normalBarWidth,
                  decoration: BoxDecoration(
                    color: notPassedColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.18),
                      width: 1.2,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Passed area (darker area)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        height: pillTop + normalPillHeight / 2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: passedColor,
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(10),
                              bottom: Radius.circular(0),
                            ),
                          ),
                        ),
                      ),
                      // The pill (expanded to fit bar width)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: pillTop.toDouble(),
                        child: Container(
                          height: normalPillHeight,
                          decoration: BoxDecoration(
                            color: BrandColors.accent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$currentPage',
                            textScaler: const TextScaler.linear(1.0),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize,
                              height: 1.05,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildAudioPlayerCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AudioPlayerCard(
              controller: widget.controller,
              onExpandChanged: (expanded) {
                if (_audioPlayerExpanded != expanded) {
                  setState(() {
                    _audioPlayerExpanded = expanded;
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  String _surahNameForPage(int page) {
    final cached = _surahNameCache[page];
    if (cached != null) return cached;
    try {
      final pd = getPageData(page);
      if (pd.isEmpty) return '';
      final first = pd[0];
      final surahNum = int.parse(first['surah'].toString());
      final name = getBilingualSurahName(context, surahNum);
      _surahNameCache[page] = name;
      return name;
    } catch (e) {
      return '';
    }
  }

  Future<void> _startAutoScroll() async {
    if (_isAutoScrolling || !_itemScrollController.isAttached) return;

    setState(() {
      _isAutoScrolling = true;
      _autoScrollControlsVisible = true;
      _scrollGeneration++;
    });

    _scrollLoop();
  }

  Future<void> _scrollLoop() async {
    final myGen = _scrollGeneration;
    if (!_isAutoScrolling || !mounted || myGen != _scrollGeneration) return;

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    final current = sorted.first;

    const int stepDurationMs = 250;
    final pageHeight = MediaQuery.of(context).size.height;
    if (pageHeight <= 0) return;

    final speed = _autoScrollSpeed < 1.0 ? 1.0 : _autoScrollSpeed;
    final movePixels = speed * (stepDurationMs / 1000.0);
    final moveFraction = movePixels / pageHeight;

    double targetLimit = current.itemLeadingEdge - moveFraction;
    int targetIndex = current.index;

    if (current.itemLeadingEdge < -0.8 && sorted.length > 1) {
      final next = sorted[1];
      targetIndex = next.index;
      targetLimit = next.itemLeadingEdge - moveFraction;
    } else if (current.itemLeadingEdge < -1.5) {
      targetIndex = current.index + 1;
      if (targetIndex > 604) {
        _stopAutoScroll();
        return;
      }
      targetLimit = 0;
    }

    try {
      await _itemScrollController.scrollTo(
        index: targetIndex,
        alignment: targetLimit,
        duration: const Duration(milliseconds: stepDurationMs),
        curve: Curves.linear,
      );
      if (myGen != _scrollGeneration) return;
      _scrollLoop();
    } catch (_) {
      if (myGen == _scrollGeneration) {
        _stopAutoScroll();
      }
    }
  }

  void _stopAutoScroll() {
    _scrollGeneration++;
    if (!_isAutoScrolling) return;

    if (mounted) {
      setState(() {
        _isAutoScrolling = false;
      });
    } else {
      _isAutoScrolling = false;
    }
  }

  void _showAutoScrollSpeedSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        double tempSpeed = _autoScrollSpeed;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Auto-scroll speed',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      min: 10,
                      max: 80,
                      divisions: 70,
                      label: '${tempSpeed.toStringAsFixed(0)} px/s',
                      value: tempSpeed,
                      onChanged: (value) {
                        setSheetState(() => tempSpeed = value);
                        setState(() {
                          _autoScrollSpeed = value;
                          if (_isAutoScrolling) {
                            _scrollGeneration++;
                            _scrollLoop();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (AppLocalizations.of(context)
                                  ?.translate('pixels_per_second') ??
                              '{value} pixels/second')
                          .replaceAll('{value}', tempSpeed.toStringAsFixed(0)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _changeAutoScrollSpeed(double delta) {
    final double newSpeed =
        (_autoScrollSpeed + delta).clamp(10.0, 80.0).toDouble();
    setState(() {
      _autoScrollSpeed = newSpeed;
      if (_isAutoScrolling) {
        _scrollGeneration++;
        _scrollLoop();
      }
    });
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _overlayVisible = false;
      });
      widget.onOverlayVisibilityChanged?.call(false);
    });
  }

  void _showOverlay() {
    if (!_overlayVisible) {
      setState(() {
        _overlayVisible = true;
      });
      widget.onOverlayVisibilityChanged?.call(true);
    }
    _scheduleAutoHide();
  }

  void _hideOverlay() {
    if (_overlayVisible) {
      setState(() {
        _overlayVisible = false;
      });
      widget.onOverlayVisibilityChanged?.call(false);
    }
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  void _toggleOverlay() {
    if (_overlayVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  Future<void> _navigateWithFade(int page) async {
    final target = page.clamp(1, 604);
    if (_isFading) return;

    _isFading = true;
    try {
      if (mounted) {
        setState(() {
          _contentOpacity = 0.5; // dim but keep page visible
        });
      }

      final half =
          Duration(milliseconds: (_fadeDuration.inMilliseconds / 2).round());
      await Future.delayed(half);
      if (!mounted) return;

      // Fix: update slider state before jumping
      setState(() {
        _sliderValue = target.toDouble();
        _isSliderActive = false;
      });
      widget.controller.navigateToPage(target);

      if (mounted) {
        setState(() => _contentOpacity = 1);
      }

      await Future.delayed(_fadeDuration);
      if (!mounted) return;
    } finally {
      _isFading = false;
    }
  }

  void _openPageSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const PageSettingsSheet(),
    );
  }

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (_) {
      return int.parse('FFFFC107', radix: 16);
    }
  }

  void _showVerseOptions(
    BuildContext context,
    BookmarkNotesNotifier bookmarkState,
    int surah,
    int verse,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => VerseOptionsSheet(surah: surah, verse: verse),
    ).whenComplete(_scheduleHighlightClear);
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _NavPill(
      {required this.icon,
      required this.label,
      required this.enabled,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? BrandColors.accent
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.25);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, color: color, size: 28)),
      if (label.isNotEmpty)
        Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 13)),
    ]);
  }
}

class _NotesIcon extends StatelessWidget {
  final VoidCallback onTap;
  const _NotesIcon({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return IconButton(
        onPressed: onTap,
        icon:
            Icon(Icons.menu_book_rounded, color: BrandColors.accent, size: 26));
  }
}
