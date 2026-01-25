import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/features/audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/bookmark_screen.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/mushaf/controller/mushaf_controller.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/features/share/presentation/dialogs/share_preview_dialog.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';
import 'package:quran_app/features/share/services/share_service.dart';
import 'play_range_dialog.dart';
import 'surah_info_sheet.dart';

// Result type for the verse menu editor dialog
class _MenuEditResult {
  _MenuEditResult({required this.order, required this.hidden});

  final List<String> order;
  final List<String> hidden;
}

enum _ShareFormat { image, text, textWithoutDiacritics }

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

  static const List<String> _bookmarkColors = [
    '#EF5350', // Red
    '#FFB300', // Yellow
    '#66BB6A', // Green
    '#42A5F5', // Blue
  ];

  static const List<String> _defaultSectionOrder = [
    'bookmarks',
    'recitation',
    'downloads',
    'sharing',
    'highlight',
  ];

  List<String> _sectionOrder = List.from(_defaultSectionOrder);
  List<String> _hiddenSections = [];
  static const _sectionOrderKey = 'verse_menu_order';
  static const _hiddenSectionKey = 'verse_menu_hidden';

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

    _loadSectionOrder();
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
                              pageBackgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor,
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
      return Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.5);
    }

    final b = state.bookmarkForVerse(surah, verse);
    if (b != null) {
      if (b.isKhatmahPin) {
        return null;
      }
      final color = Color(_parseColor(b.colorHex));
      return color.withValues(alpha: 0.25);
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
              final bottomPad = MediaQuery.paddingOf(context).bottom;
              return RepaintBoundary(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isSliding
                          ? Card(
                              elevation: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.95),
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
                          color: Theme.of(context)
                              .colorScheme
                              .surface
                              .withOpacity(0.95),
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
                              bottomPad +
                                  ResponsiveLayout.scaled(context, 8,
                                      min: 6, max: 14),
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
                                  Column(
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
                                              icon: const Icon(
                                                  Icons.remove_circle_outline),
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
                                                      BorderRadius.circular(22),
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
    final bottom = media.padding.bottom + 170;

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
                  final value =
                      (_sliderValue ?? currentDouble).clamp(1.0, 604.0);
                  final page = value.round();
                  setState(() {
                    _isSliderActive = false;
                    _sliderValue = null;
                  });
                  _navigateWithFade(page);
                  _scheduleAutoHide();
                }

                final t = (currentDouble - 1) / 603;
                final pillTop = (trackHeight * t).clamp(0, trackHeight);

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanDown: (details) => handleDrag(details.localPosition.dy),
                  onPanUpdate: (details) =>
                      handleDrag(details.localPosition.dy),
                  onPanEnd: (_) => handleEnd(),
                  onTapDown: (details) => handleDrag(details.localPosition.dy),
                  onTapUp: (_) => handleEnd(),
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4,
                          right: 4,
                          top: pillTop.toDouble(),
                          child: Container(
                            height: pillHeight,
                            decoration: BoxDecoration(
                              color: BrandColors.accent,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$currentPage',
                              textScaler: const TextScaler.linear(1.0),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
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
        });
  }

  Widget _buildAudioPlayerCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Material(
            elevation: 8,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AudioPlayerCard(controller: widget.controller),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
      final name = getSurahName(surahNum);
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
                    Text('${tempSpeed.toStringAsFixed(0)} pixels/second'),
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

  ({ShareCardBackground background, bool isDark, String frameAsset})
      _resolveShareCardTheme() {
    final themeService = ThemeService();
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    ShareCardBackground background;

    if (isDarkMode) {
      background = ShareCardBackground.gradient(
        const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else {
      background = ShareCardBackground.solid(const Color(0xFFFFF4DA));
    }

    return (
      background: background,
      isDark: isDarkMode,
      frameAsset: themeService.getResponsiveMainframePath(brightness),
    );
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

  Future<void> _openPageSettingsSheet() async {
    final mushafSettings = MushafSettingsService();
    final themeService = ThemeService();
    await SharedPreferences.getInstance();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        ScrollMode mode = mushafSettings.scrollMode;
        ThemeMode themeMode = themeService.themeMode;
        SurahHeaderStyle surahStyle = themeService.surahHeaderStyle;

        return DraggableScrollableSheet(
          minChildSize: 0.5,
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          builder: (context, controller) {
            return StatefulBuilder(
              builder: (context, setStateSheet) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Page Settings',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.close_rounded,
                                    color: BrandColors.accent),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ListView(
                              controller: controller,
                              children: [
                                const SizedBox(height: 8),
                                Text(
                                  'Scroll Direction',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    _SettingOptionTile(
                                      label: 'Horizontal',
                                      icon: Icons.view_day,
                                      selected: mode == ScrollMode.horizontal,
                                      onTap: () {
                                        mushafSettings.setScrollMode(
                                            ScrollMode.horizontal);
                                        setStateSheet(
                                            () => mode = ScrollMode.horizontal);
                                      },
                                    ),
                                    const SizedBox(width: 12),
                                    _SettingOptionTile(
                                      label: 'Vertical',
                                      icon: Icons.view_stream,
                                      selected: mode == ScrollMode.vertical,
                                      onTap: () {
                                        mushafSettings
                                            .setScrollMode(ScrollMode.vertical);
                                        setStateSheet(
                                            () => mode = ScrollMode.vertical);
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Theme Mode',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: ThemeMode.values
                                      .where((t) => t != ThemeMode.system)
                                      .map((t) {
                                    final selected = t == themeMode;
                                    String label;
                                    IconData icon;
                                    switch (t) {
                                      case ThemeMode.light:
                                        label = 'Light';
                                        icon = Icons.wb_sunny;
                                        break;
                                      case ThemeMode.dark:
                                        label = 'Dark';
                                        icon = Icons.nightlight_round;
                                        break;
                                      default:
                                        label = '';
                                        icon = Icons.error;
                                    }

                                    return _ThemeModeTile(
                                      label: label,
                                      icon: icon,
                                      selected: selected,
                                      onTap: () {
                                        themeService.setThemeMode(t);
                                        setStateSheet(() => themeMode = t);
                                      },
                                    );
                                  }).toList(),
                                ),
                                if (themeMode != ThemeMode.dark) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    'Surah Header Style',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: SurahHeaderStyle.values.map((s) {
                                      final selected = s == surahStyle;
                                      String label =
                                          s == SurahHeaderStyle.golden
                                              ? 'Golden'
                                              : 'Green';
                                      return _ThemeModeTile(
                                        label: label,
                                        icon: Icons.image,
                                        selected: selected,
                                        onTap: () {
                                          themeService.setSurahHeaderStyle(s);
                                          setStateSheet(() => surahStyle = s);
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                Text(
                                  'Language',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: const [Locale('en'), Locale('ar')]
                                      .map((loc) {
                                    final isSel = LanguageService()
                                            .currentLocale
                                            .languageCode ==
                                        loc.languageCode;
                                    final label = loc.languageCode == 'ar'
                                        ? 'العربية'
                                        : 'English';
                                    return ChoiceChip(
                                      selected: isSel,
                                      label: Text(label),
                                      selectedColor:
                                          BrandColors.accent.withOpacity(0.18),
                                      onSelected: (v) async {
                                        await LanguageService().setLocale(loc);
                                        setStateSheet(() {});
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
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

  Future<void> _toggleLastReadAt(
      BookmarkNotesNotifier state, int surah, int verse) async {
    int? page;
    try {
      page = getPageNumber(surah, verse);
    } catch (_) {}

    final pin = state.khatmahPin;
    final isSameLastRead = pin != null &&
        pin.surahId == surah &&
        pin.ayahId == verse &&
        (pin.categoryName == 'Last read' || pin.categoryName == null);

    if (isSameLastRead) {
      await state.clearKhatmahPin();
      if (!mounted) return;
      _showSnack(page != null
          ? 'Removed last read for page $page'
          : 'Removed last read');
      return;
    }

    await state.setKhatmahPin(
      surahId: surah,
      ayahId: verse,
      colorHex: '#4DB6AC',
      category: 'Last read',
    );

    if (!mounted) return;
    final name = getSurahName(surah);
    final pageLabel = page != null ? 'Page $page • ' : '';
    _showSnack('$pageLabel$name:$verse set as last read');
  }

  /// REPLACED showVerseOptions with Git Layout + Merged Functions
  void _showVerseOptions(
    BuildContext context,
    BookmarkNotesNotifier bookmarkState,
    int surah,
    int verse,
  ) {
    final rootContext = context;
    final surahTitle = '${getSurahName(surah)}: $verse';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(context);
        final accent = BrandColors.accent;
        final width = MediaQuery.of(context).size.width;
        final shareCardWidth = (width - 16 * 2 - 12 * 3) / 4;

        final orderedSections = _buildOrderedSections(
          sheetContext,
          bookmarkState,
          surah,
          verse,
          shareCardWidth,
          rootContext,
        );

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            TextButton(
                              onPressed: () async {
                                final result =
                                    await _openMenuEditor(sheetContext);
                                if (result != null && mounted) {
                                  setState(() {
                                    _sectionOrder = result.order;
                                    _hiddenSections = result.hidden;
                                  });
                                  await _saveMenuConfig(
                                      result.order, result.hidden);
                                }
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: accent,
                                textStyle: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 17),
                              ),
                              child: const Text('Edit'),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(surahTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18)),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.onSurface
                                    .withOpacity(0.1),
                                foregroundColor: accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...orderedSections,
                        const SizedBox(height: 12),
                        _buildSectionLabel('Actions', context),
                        const SizedBox(height: 8),
                        _buildQuickActions(
                            context, bookmarkState, rootContext, surah, verse),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String text, BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
      ),
    );
  }

  List<Widget> _buildOrderedSections(
    BuildContext context,
    BookmarkNotesNotifier bookmarkState,
    int surah,
    int verse,
    double shareCardWidth,
    BuildContext rootContext,
  ) {
    final widgets = <Widget>[];
    void addSpacer() => widgets.add(const SizedBox(height: 14));

    for (final section in _visibleSections) {
      switch (section) {
        case 'bookmarks':
          widgets
            ..add(_buildSectionLabel('Bookmarks', context))
            ..add(const SizedBox(height: 8))
            ..add(
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      width: double.infinity,
                      icon: Icons.bookmark_border,
                      iconColor: Colors.redAccent,
                      label: 'Red',
                      onTap: () {
                        Navigator.pop(context);
                        unawaited(() async {
                          await bookmarkState.saveBookmark(
                            surahId: surah,
                            ayahId: verse,
                            colorHex: '#EF5350',
                            category: 'Red',
                          );
                          if (!mounted) return;
                          _showBookmarkSnackbar(rootContext, false);
                        }());
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      width: double.infinity,
                      icon: Icons.list_alt,
                      label: 'All',
                      trailing: Icons.chevron_right,
                      onTap: () async {
                        Navigator.pop(context);
                        if (!bookmarkState.isInitialized)
                          await bookmarkState.initialize();
                        else
                          await bookmarkState.refresh();
                        await Navigator.push(
                            rootContext,
                            MaterialPageRoute(
                                builder: (_) => const BookmarkScreen()));
                      },
                    ),
                  ),
                ],
              ),
            );
          addSpacer();
          break;
        case 'recitation':
          widgets
            ..add(_buildSectionLabel('Recitation', context))
            ..add(const SizedBox(height: 8))
            ..add(
              _buildActionWrap(
                context,
                [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      width: double.infinity,
                      icon: Icons.play_arrow,
                      label: 'Play',
                      onTap: () {
                        Navigator.pop(context);
                        AudioPlayerService.instance
                            .playSurahSequenceWithDownload(
                                rootContext, surah, verse);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      width: double.infinity,
                      icon: Icons.playlist_play,
                      label: 'Play to...',
                      onTap: () {
                        Navigator.pop(context);
                        _showPlayToDialog(rootContext, surah, verse);
                      },
                    ),
                  ),
                ],
              ),
            );
          addSpacer();
          break;
        case 'downloads':
          widgets
            ..add(_buildSectionLabel('Downloads', context))
            ..add(const SizedBox(height: 8))
            ..add(
              _buildActionCard(
                context,
                width: double.infinity,
                icon: Icons.download_rounded,
                label: 'Downloads',
                trailing: Icons.chevron_right,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      rootContext,
                      MaterialPageRoute(
                          builder: (_) => const DownloadsScreen()));
                },
              ),
            );
          addSpacer();
          break;
        case 'sharing':
          widgets
            ..add(_buildSectionLabel('Sharing', context))
            ..add(const SizedBox(height: 8))
            ..add(
              _buildActionWrap(
                context,
                [
                  _buildActionCard(context,
                      width: shareCardWidth,
                      icon: Icons.copy,
                      label: 'Copy', onTap: () {
                    Navigator.pop(context);
                    _copyVerseText(surah, verse);
                  }),
                  _buildActionCard(context,
                      width: shareCardWidth,
                      icon: Icons.image_outlined,
                      label: 'Card', onTap: () {
                    Navigator.pop(context);
                    _shareVerseCardPreview(
                        surah, verse); // Use Current logic for "Card"
                  }),
                  _buildActionCard(context,
                      width: shareCardWidth,
                      icon: Icons.share,
                      label: 'Share', onTap: () {
                    Navigator.pop(context);
                    _openShareSheet(rootContext, surah,
                        verse); // Use Git logic for range sheet
                  }),
                ],
              ),
            );
          addSpacer();
          break;
        case 'highlight':
          widgets
            ..add(_buildSectionLabel('Highlight', context))
            ..add(const SizedBox(height: 10))
            ..add(_buildHighlightRow(context, bookmarkState, surah, verse));
          addSpacer();
          break;
      }
    }
    if (widgets.isNotEmpty && widgets.last is SizedBox) widgets.removeLast();
    return widgets;
  }

  Widget _buildActionWrap(BuildContext context, List<Widget> children) {
    return Row(children: children);
  }

  Widget _buildActionCard(
    BuildContext context, {
    required double width,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    IconData? trailing,
    bool enabled = true,
    Color? iconColor,
  }) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color:
                theme.colorScheme.onSurface.withOpacity(enabled ? 0.08 : 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.08), width: 1),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: enabled
                      ? (iconColor ?? accent)
                      : theme.colorScheme.onSurface.withOpacity(0.4)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: enabled
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailing != null)
                Icon(trailing,
                    size: 18,
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
      BuildContext context, BookmarkNotesNotifier state, int surah, int verse) {
    final chips = <Widget>[];
    final existingColor =
        state.bookmarkForVerse(surah, verse)?.colorHex.toLowerCase();
    for (var i = 0; i < _bookmarkColors.length; i++) {
      final hex = _bookmarkColors[i];
      final color = Color(_parseColor(hex));
      final isSelected = existingColor == hex.toLowerCase();
      chips.add(Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            if (isSelected) {
              state.deleteBookmark(surah, verse);
            } else {
              state.saveBookmark(
                surahId: surah,
                ayahId: verse,
                colorHex: hex,
                category: _getCategoryName(hex),
              );
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isSelected ? color.withOpacity(0.3) : color.withOpacity(0.18),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(isSelected ? Icons.check : Icons.brush,
                size: 18, color: color),
          ),
        ),
      ));
    }
    return Row(children: chips);
  }

  String _getCategoryName(String hex) {
    if (hex == '#EF5350') return 'Red';
    if (hex == '#FFB300') return 'Yellow';
    if (hex == '#66BB6A') return 'Green';
    if (hex == '#42A5F5') return 'Blue';
    return 'Bookmark';
  }

  Widget _buildQuickActions(BuildContext context, BookmarkNotesNotifier state,
      BuildContext rootContext, int surah, int verse) {
    return Column(
      children: [
        _buildActionCard(context,
            width: double.infinity,
            icon: Icons.push_pin_outlined,
            label: 'Pin here (Khatmah)', onTap: () {
          Navigator.pop(context);
          _pinKhatmah(state, surah, verse);
        }),
        const SizedBox(height: 10),
        _buildActionCard(context,
            width: double.infinity,
            icon: Icons.flag_outlined,
            label: 'Set as last read', onTap: () {
          Navigator.pop(context);
          unawaited(_toggleLastReadAt(state, surah, verse));
        }),
        const SizedBox(height: 10),
        _buildActionCard(context,
            width: double.infinity,
            icon: Icons.note_add_outlined,
            label: 'Write note',
            trailing: Icons.chevron_right, onTap: () {
          Navigator.pop(context);
          unawaited(_openNoteSheet(rootContext, state, surah, verse));
        }),
        const SizedBox(height: 10),
        _buildActionCard(context,
            width: double.infinity,
            icon: Icons.menu_book_outlined,
            label: 'View Tafsir',
            trailing: Icons.chevron_right, onTap: () {
          Navigator.pop(context);
          _viewTafsir(rootContext, surah, verse);
        }),
      ],
    );
  }

  Future<void> _pinKhatmah(
      BookmarkNotesNotifier state, int surah, int verse) async {
    await state.setKhatmahPin(
        surahId: surah,
        ayahId: verse,
        colorHex: '#FFB300',
        category: 'Khatmah');
    if (!mounted) return;
    _showSnack('Pinned for Khatmah');
  }

  Future<_MenuEditResult?> _openMenuEditor(BuildContext context) async {
    final order = List<String>.from(_sectionOrder);
    final hidden = List<String>.from(_hiddenSections);
    return showModalBottomSheet<_MenuEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return FractionallySizedBox(
          heightFactor: 0.8,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx)),
                    const Spacer(),
                    const Text('Edit Verse Menu',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    const Spacer(),
                    TextButton(
                        onPressed: () => Navigator.pop(
                            ctx,
                            _MenuEditResult(
                                order: List.from(order),
                                hidden: List.from(hidden))),
                        child: const Text('Done')),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StatefulBuilder(
                    builder: (context, setSheetState) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Display Order',
                              style: theme.textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ReorderableListView.builder(
                              itemCount: order.length,
                              buildDefaultDragHandles: false,
                              itemBuilder: (context, index) {
                                final item = order[index];
                                return Card(
                                  key: ValueKey(item),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.05),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  child: ListTile(
                                    title: Text(_labelForSection(item),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            icon: const Icon(
                                                Icons.remove_circle_outline,
                                                color: Colors.redAccent),
                                            onPressed: () {
                                              setSheetState(() {
                                                order.removeAt(index);
                                                if (!hidden.contains(item))
                                                  hidden.add(item);
                                              });
                                            }),
                                        ReorderableDragStartListener(
                                            index: index,
                                            child:
                                                const Icon(Icons.drag_handle)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                setSheetState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final item = order.removeAt(oldIndex);
                                  order.insert(newIndex, item);
                                });
                              },
                            ),
                          ),
                          if (hidden.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text('Hidden',
                                style: theme.textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              for (final item in hidden)
                                InputChip(
                                    label: Text(_labelForSection(item)),
                                    avatar: const Icon(Icons.add),
                                    onPressed: () {
                                      setSheetState(() {
                                        hidden.remove(item);
                                        order.add(item);
                                      });
                                    }),
                            ]),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelForSection(String key) {
    switch (key) {
      case 'bookmarks':
        return 'Bookmarks';
      case 'recitation':
        return 'Recitation';
      case 'downloads':
        return 'Downloads';
      case 'sharing':
        return 'Sharing';
      case 'highlight':
        return 'Highlight';
      default:
        return key;
    }
  }

  Future<void> _loadSectionOrder() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sectionOrder = prefs.getStringList(_sectionOrderKey) ??
          List.from(_defaultSectionOrder);
      _hiddenSections = prefs.getStringList(_hiddenSectionKey) ?? [];
    });
  }

  Future<void> _saveMenuConfig(List<String> order, List<String> hidden) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sectionOrderKey, order);
    await prefs.setStringList(_hiddenSectionKey, hidden);
  }

  List<String> get _visibleSections => _sectionOrder;

  void _showBookmarkSnackbar(BuildContext context, bool wasBookmarked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text(wasBookmarked ? 'Bookmark removed' : 'Verse bookmarked'),
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _openNoteSheet(BuildContext context, BookmarkNotesNotifier state,
      int surah, int verse) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');
    String? lastSavedText = existing?.content;
    bool saving = false;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleSave() async {
              if (saving) return;
              setModalState(() => saving = true);
              try {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  if (existing != null)
                    await state.deleteNoteForVerse(surah, verse);
                  lastSavedText = '';
                } else {
                  await state.upsertNote(
                      surahId: surah, ayahId: verse, content: text);
                  lastSavedText = text;
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (context.mounted) _showSnack('Failed to save note');
              } finally {
                setModalState(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Note for $surah:$verse',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: controller,
                      maxLines: 6,
                      decoration: const InputDecoration(
                          hintText: 'Write your reflection here',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (existing != null)
                        TextButton.icon(
                          onPressed: saving
                              ? null
                              : () async {
                                  setModalState(() => saving = true);
                                  await state.deleteNoteForVerse(surah, verse);
                                  if (context.mounted)
                                    Navigator.pop(context, true);
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete'),
                        ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: saving ? null : handleSave,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(saving ? 'Saving...' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved == true && mounted) {
      _showSnack((lastSavedText == null || lastSavedText!.isEmpty)
          ? 'Note removed for $surah:$verse'
          : 'Note saved for $surah:$verse');
    }
  }

  Future<void> _openShareSheet(
      BuildContext context, int surah, int verse) async {
    final surahName = getSurahName(surah);
    final maxVerse = getVerseCount(surah);
    var format = _ShareFormat.image;
    var fromVerse = verse;
    var toVerse = verse;
    var includeSurahName = true;
    var includeVerseReference = true;
    var includeBadge = true;
    var isSharing = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final theme = Theme.of(context);
            final accent = BrandColors.accent;

            Future<void> handleShare() async {
              if (isSharing) return;
              setSheetState(() => isSharing = true);
              try {
                if (format == _ShareFormat.image) {
                  final shareTheme = _resolveShareCardTheme();
                  await ShareService.instance.shareVerseImage(
                    surahNumber: surah,
                    ayahNumber: fromVerse,
                    endAyahNumber: toVerse,
                    background: shareTheme.background,
                    isDark: shareTheme.isDark,
                    frameAsset: shareTheme.frameAsset,
                    showSurahName: includeSurahName,
                    showPageNumber: includeVerseReference,
                    showBadge: includeBadge,
                    size: 1080,
                    pixelRatio: 2.5,
                  );
                } else {
                  await ShareService.instance.shareVerseText(
                    surahNumber: surah,
                    ayahNumber: fromVerse,
                    endAyahNumber: toVerse,
                    stripDiacritics:
                        format == _ShareFormat.textWithoutDiacritics,
                    includeSurahName: includeSurahName,
                    includeReference: includeVerseReference,
                    includeBadge: includeBadge,
                  );
                }
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showSnack('Could not share: $e');
              } finally {
                setSheetState(() => isSharing = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4)))),
                    const SizedBox(height: 14),
                    Text('Share $surahName',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 16),
                    const Text('Share as',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Wrap(spacing: 8, children: [
                      ChoiceChip(
                          label: const Text('Image'),
                          selected: format == _ShareFormat.image,
                          onSelected: (_) =>
                              setSheetState(() => format = _ShareFormat.image)),
                      ChoiceChip(
                          label: const Text('Text'),
                          selected: format == _ShareFormat.text,
                          onSelected: (_) =>
                              setSheetState(() => format = _ShareFormat.text)),
                      ChoiceChip(
                          label: const Text('Text (No Diacritics)'),
                          selected:
                              format == _ShareFormat.textWithoutDiacritics,
                          onSelected: (_) => setSheetState(() =>
                              format = _ShareFormat.textWithoutDiacritics)),
                    ]),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: _buildStepper(
                              context,
                              'From',
                              fromVerse,
                              (v) => setSheetState(
                                  () => fromVerse = v.clamp(1, toVerse)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _buildStepper(
                              context,
                              'To',
                              toVerse,
                              (v) => setSheetState(() =>
                                  toVerse = v.clamp(fromVerse, maxVerse)))),
                    ]),
                    const SizedBox(height: 18),
                    SwitchListTile.adaptive(
                        title: const Text('Surah Name'),
                        value: includeSurahName,
                        onChanged: (v) =>
                            setSheetState(() => includeSurahName = v),
                        contentPadding: EdgeInsets.zero),
                    SwitchListTile.adaptive(
                        title: const Text('Reference'),
                        value: includeVerseReference,
                        onChanged: (v) =>
                            setSheetState(() => includeVerseReference = v),
                        contentPadding: EdgeInsets.zero),
                    SwitchListTile.adaptive(
                        title: const Text('Badge'),
                        value: includeBadge,
                        onChanged: (v) => setSheetState(() => includeBadge = v),
                        contentPadding: EdgeInsets.zero),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: isSharing ? null : handleShare,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.white),
                            child: isSharing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Text('Share'))),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepper(BuildContext context, String label, int value,
      ValueChanged<int> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05)),
        child: Row(children: [
          IconButton(
              onPressed: () => onChanged(value - 1),
              icon: const Icon(Icons.remove)),
          Expanded(
              child: Center(
                  child: Text(value.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)))),
          IconButton(
              onPressed: () => onChanged(value + 1),
              icon: const Icon(Icons.add)),
        ]),
      ),
    ]);
  }

  Future<void> _shareVerseCardPreview(int surah, int verse) async {
    await showSharePreviewDialog(
        context: context, surahNumber: surah, ayahNumber: verse);
  }

  void _viewTafsir(BuildContext context, int surah, int verse) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) =>
                VerseDetailsScreen(surahNumber: surah, ayahNumber: verse)));
  }

  Future<void> _showPlayToDialog(
      BuildContext context, int startSurah, int startVerse) async {
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) =>
            PlayRangeDialog(startSurah: startSurah, startVerse: startVerse));
  }

  void _copyVerseText(int surah, int verse) {
    Clipboard.setData(
        ClipboardData(text: getVerseQCF(surah, verse, verseEndSymbol: true)));
    _showSnack('Copied Surah $surah:$verse');
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

class _SettingOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SettingOptionTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected
            ? BrandColors.accent.withOpacity(0.12)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child:
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: BrandColors.accent),
                  const SizedBox(width: 10),
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600))
                ]))),
      ),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeModeTile(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 84,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? BrandColors.accent
                    : Colors.grey.withOpacity(0.3),
                width: selected ? 2 : 1)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: selected ? BrandColors.accent : Colors.grey),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? BrandColors.accent : null)),
          ],
        ),
      ),
    );
  }
}
