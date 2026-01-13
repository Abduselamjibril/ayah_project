import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/services/audio_player_service.dart';
import 'package:quran_app/features/audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/mushaf/controller/mushaf_controller.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';
import 'package:screenshot/screenshot.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';

const _brandGreen = Color(0xFF0B7743);

class VerticalMushafView extends StatefulWidget {
  final MushafController controller;
  // Previously scrollController was passed, but now we use ItemScrollController internally
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
  // Use ItemScrollController for index-based jumping
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();

  int _lastPage = 1;
  double? _sliderValue;
  bool _isSliderActive = false;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;

  // Auto-scroll implementation now relies on programmed scrolling via index jumps or simplified standard scrolling if using a different approach?
  // ScrollablePositionedList doesn't support smooth continuous pixel-scrolling easily for "auto scroll" (teleprompter style)
  // WITHOUT jumpTo/animateTo usage.
  // However, we can simulate it or just disable it for this refactor to ensure stability first.
  // The user requirement was to fix vertical navigation accuracy.
  // Let's implement a simple version of auto-scroll if possible, or leave it for later.
  // For now, I will comment out auto-scroll logic that relied on scrollController.offset to avoid compilation errors,
  // focusing on the primary goal: index-based navigation.

  bool _isAutoScrolling = false;
  double _autoScrollSpeed = 30.0; // pixels per second (conceptually)
  int _scrollGeneration = 0;

  final ScreenshotController _screenshotController = ScreenshotController();

  static const List<String> _bookmarkColors = [
    '#FFB300',
    '#4DB6AC',
    '#29B6F6',
    '#AB47BC',
    '#EF5350',
    '#8D6E63',
  ];

  StreamSubscription<int>? _navSubscription;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.controller.currentPage;
    _sliderValue = _lastPage.toDouble();
    _audioPlayer = AudioPlayerService.instance;

    _ayahListener = () {
      if (!mounted) return;
      // We don't have _isSequentialMode tracked here easily without checking player service
      // But we can check if we should auto-highlight
      final s = _audioPlayer.currentSurah.value;
      final a = _audioPlayer.currentAyah.value;
      if (s != null && a != null) {
        widget.controller.setHighlightedVerse(s, a);
      }
    };

    _audioPlayer.currentSurah.addListener(_ayahListener);
    _audioPlayer.currentAyah.addListener(_ayahListener);

    // Listen to navigation events from the controller
    _navSubscription = widget.controller.navigationStream.listen((page) {
      if (_itemScrollController.isAttached) {
        // Stop any manual auto-scroll
        _stopAutoScroll();
        _lastPage = page;
        // Index is 0-based
        _itemScrollController.jumpTo(index: page - 1);
      }
    });

    // Listen to scroll positions to sync back to controller
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

    // Sort to find the top-most item
    final sorted = positions.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    // The top-most visible item is our current page (index + 1)
    final firstVisible = sorted.first;
    // We can also check itemTrailingEdge to see if it's mostly scrolled off

    final page = firstVisible.index + 1;

    if (page != _lastPage) {
      _lastPage = page;
      // We use setPage specifically to update state WITHOUT triggering a navigation event loop
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
    super.dispose();
  }

  void _onControllerChanged() {
    // Only handle state syncs, not navigation (handled by stream)
    if (widget.controller.currentPage != _lastPage) {
      _lastPage = widget.controller.currentPage;
      _sliderValue = null;
      _isSliderActive = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Using simple provider lookup or whatever was used before
    final bookmarkState = context.watch<BookmarkNotesNotifier>();

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleOverlay,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = min(constraints.maxWidth, 900.0);
              final topMargin = MediaQuery.of(context).padding.top + 12;

              return Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topMargin, left: 5, right: 5),
                  child: SizedBox(
                    width: maxWidth,
                    height: constraints.maxHeight - topMargin,
                    child: NotificationListener<UserScrollNotification>(
                      onNotification: (notification) {
                        if (_isAutoScrolling) {
                          _stopAutoScroll();
                        }
                        return false;
                      },
                      child: PageviewQuran(
                        initialPageNumber: widget.controller.currentPage,
                        scrollMode: ScrollMode.vertical,
                        itemScrollController: _itemScrollController,
                        itemPositionsListener: _itemPositionsListener,
                        // We don't use onPageChanged callback here because we use the listener
                        textColor: Theme.of(context).colorScheme.onSurface,
                        pageBackgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        verseBackgroundColor: (s, v) =>
                            _getVerseBackgroundColor(bookmarkState, s, v),
                        onLongPress: (surah, verse) => _showVerseOptions(
                            context, bookmarkState, surah, verse),
                        onLongPressStart: (surah, verse, details) =>
                            widget.controller.setHighlightedVerse(surah, verse),
                        onLongPressCancel: (surah, verse) =>
                            widget.controller.clearHighlight(),
                        sp: 1.0,
                        h: 1.0,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildPageIndicator(),
      ],
    );
  }

  Color? _getVerseBackgroundColor(
      BookmarkNotesNotifier state, int surah, int verse) {
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
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final currentDouble = ((_isSliderActive && _sliderValue != null)
                  ? _sliderValue!
                  : widget.controller.currentPage.toDouble())
              .clamp(1.0, 604.0);
          final currentPage = currentDouble.round();
          final surahName = _surahNameForPage(currentPage);
          final isSliding = _isSliderActive;
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
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Page ${currentPage.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
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
                Card(
                  elevation: 16,
                  margin: EdgeInsets.zero,
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        12, 2, 12, MediaQuery.of(context).padding.bottom + 8),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _NavPill(
                            icon: Icons.arrow_back_rounded,
                            label: currentPage > 1 ? '${currentPage - 1}' : '',
                            enabled: currentPage > 1,
                            onTap: () => _navigateToPage(currentPage - 1),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 12,
                                    inactiveTrackColor:
                                        Colors.black.withOpacity(0.2),
                                    activeTrackColor:
                                        Colors.black.withOpacity(0.2),
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 0.0),
                                    overlayShape:
                                        const RoundSliderOverlayShape(overlayRadius: 0),
                                  ),
                                  child: Slider(
                                    min: 1,
                                    max: 604,
                                    divisions: 603,
                                    value: currentDouble,
                                    onChangeStart: (value) {
                                      _stopAutoScroll();
                                      setState(() {
                                        _isSliderActive = true;
                                        _sliderValue = value;
                                        _overlayVisible = true;
                                      });
                                      _scheduleAutoHide();
                                    },
                                    onChanged: (value) {
                                      setState(() {
                                        _overlayVisible = true;
                                        _sliderValue = value;
                                      });
                                      _scheduleAutoHide();
                                    },
                                    onChangeEnd: (value) {
                                      _stopAutoScroll();
                                      final page = value.round();
                                      setState(() {
                                        _isSliderActive = false;
                                        _sliderValue = null;
                                      });
                                      _navigateToPage(page);
                                      _scheduleAutoHide();
                                    },
                                  ),
                                ),
                                IgnorePointer(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _brandGreen,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      '$currentPage',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          _NavPill(
                            icon: Icons.arrow_forward_rounded,
                            label: currentPage < 604 ? '${currentPage + 1}' : '',
                            enabled: currentPage < 604,
                            onTap: () => _navigateToPage(currentPage + 1),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip:
                                'Auto-scroll (tap to start/stop, long press to set speed)',
                            icon: const Icon(Icons.arrow_upward),
                            color: _brandGreen.withOpacity(
                                _isAutoScrolling ? 1.0 : 0.35),
                            onPressed: () {
                              setState(() {
                                _overlayVisible = true;
                              });
                              if (_isAutoScrolling) {
                                _stopAutoScroll();
                              } else {
                                _startAutoScroll();
                              }
                              _scheduleAutoHide();
                            },
                            onLongPress: _showAutoScrollSpeedSheet,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioPlayerCard() {
    return AudioPlayerCard(controller: widget.controller);
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

    // Determine the target index
    int targetIndex = current.index;

    // Provide a small duration for micro-steps (e.g., 250ms)
    // This allows frequent checks for stop/speed change without long waits
    const int stepDurationMs = 250;

    // Calculate how much we move in this step in terms of viewport fraction
    final pageHeight = MediaQuery.of(context).size.height;
    if (pageHeight <= 0) return;

    final speed = _autoScrollSpeed < 1.0 ? 1.0 : _autoScrollSpeed;
    final movePixels = speed * (stepDurationMs / 1000.0);
    final moveFraction = movePixels / pageHeight;

    // Current alignment (leading edge)
    // If we are scrolling down, leading edge decreases (moves up/negative)
    double targetLimit = current.itemLeadingEdge - moveFraction;

    // Check if we need to switch to the next page reference
    // If the current item is almost off-screen (e.g. leading edge < -0.9),
    // calculating alignment relative to it becomes unstable or unsupported.
    // Instead, target the NEXT item.
    // Assuming reduced height or overlap, let's say if leading edge is < -0.5, catch the next one?
    // ScrollablePositionedList reports visible items. If 'current' is index 5 but index 6 is also visible.
    // We can target index 6.

    // Simple logic:
    // If targetLimit is significantly negative (e.g. < -1.0), it means this page is fully scrolled out.
    // But we are in a loop. We just want to move *a little bit*.

    // Ideally, we scroll 'current' to 'targetLimit'.
    // If 'targetLimit' is valid.

    // Let's use the 'jump' logic only if we need to change reference item?
    // No, scrollTo uses index.

    // Use the next item if the current one is mostly gone.
    if (current.itemLeadingEdge < -0.8 && sorted.length > 1) {
      // Target the next item instead for better stability
      final next = sorted[1];
      targetIndex = next.index;
      // We want to move 'next' upwards.
      // Current 'next' alignment is next.itemLeadingEdge.
      // Target = next.itemLeadingEdge - moveFraction.
      targetLimit = next.itemLeadingEdge - moveFraction;
    } else if (current.itemLeadingEdge < -1.5) {
      // Single item visible but moved way off? Force next.
      targetIndex = current.index + 1;
      // Estimate alignment?
      // If we switch index, we must know its current position or 0.0?
      // This branch shouldn't happen often if we have >1 visible items.
      // Just stop if we hit end of book.
      if (targetIndex > 604) {
        _stopAutoScroll();
        return;
      }
      // Blind guess: alignment 0 (start of page)
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
    // Speed doesn't apply if auto-scroll is disabled, but keeping the UI
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

  void _navigateToPage(int page) {
    widget.controller.navigateToPage(page.clamp(1, 604));
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

  void _showVerseOptions(
    BuildContext context,
    BookmarkNotesNotifier bookmarkState,
    int surah,
    int verse,
  ) {
    final rootContext = context;
    final isBookmarked = bookmarkState.isBookmarked(surah, verse);
    final hasNote = bookmarkState.hasNote(surah, verse);
    final pin = bookmarkState.khatmahPin;
    final isLastReadPin = pin != null &&
        pin.surahId == surah &&
        pin.ayahId == verse &&
        (pin.categoryName == 'Last read' || pin.categoryName == null);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOptionTile(
                  icon: Icons.push_pin,
                  title: 'Pin here (Khatmah)',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(() async {
                      await bookmarkState.setKhatmahPin(
                        surahId: surah,
                        ayahId: verse,
                        colorHex: '#4DB6AC',
                        category: 'Khatmah',
                      );
                      if (!mounted) return;
                      _showSnack('Pinned Surah $surah:$verse for Khatmah');
                    }());
                  },
                ),
                _buildOptionTile(
                  icon: isLastReadPin
                      ? Icons.bookmark_remove
                      : Icons.bookmark_added,
                  title:
                      isLastReadPin ? 'Remove last read' : 'Set as last read',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_toggleLastReadAt(bookmarkState, surah, verse));
                  },
                ),
                _buildOptionTile(
                  icon:
                      isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
                  title:
                      isBookmarked ? 'Remove bookmark' : 'Add colored bookmark',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (isBookmarked) {
                      unawaited(() async {
                        await bookmarkState.toggleBookmark(
                            surahId: surah, ayahId: verse);
                        if (!rootContext.mounted) return;
                        _showBookmarkSnackbar(rootContext, true);
                      }());
                    } else {
                      unawaited(_openBookmarkDialog(
                        rootContext,
                        bookmarkState,
                        surah,
                        verse,
                      ));
                    }
                  },
                ),
                _buildOptionTile(
                  icon: hasNote ? Icons.edit_note : Icons.note_add,
                  title: hasNote ? 'Edit note' : 'Write note',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    unawaited(_openNoteSheet(
                      rootContext,
                      bookmarkState,
                      surah,
                      verse,
                    ));
                  },
                ),
                _buildOptionTile(
                  icon: Icons.volume_up,
                  title: 'Play Audio',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    AudioPlayerService.instance.playSurahSequenceWithDownload(
                      rootContext,
                      surah,
                      verse,
                    );
                  },
                ),
                _buildOptionTile(
                  icon: Icons.menu_book,
                  title: 'View Tafsir',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _viewTafsir(rootContext, surah, verse);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.share,
                  title: 'Share Verse Image',
                  onTap: () {
                    Navigator.pop(context);
                    _shareVerseCard(surah, verse);
                  },
                ),
                _buildOptionTile(
                  icon: Icons.copy,
                  title: 'Copy Verse Text',
                  onTap: () {
                    Navigator.pop(context);
                    _copyVerseText(surah, verse);
                  },
                ),
                const Divider(),
                _buildOptionTile(
                  icon: Icons.close,
                  title: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ListTile _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showBookmarkSnackbar(BuildContext context, bool wasBookmarked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(wasBookmarked ? 'Bookmark removed' : 'Verse bookmarked'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openBookmarkDialog(
    BuildContext context,
    BookmarkNotesNotifier state,
    int surah,
    int verse,
  ) async {
    final existing = state.bookmarkForVerse(surah, verse);
    String selectedColor = existing?.colorHex ?? _bookmarkColors.first;
    final categoryController =
        TextEditingController(text: existing?.categoryName ?? '');

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add colored bookmark',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: _bookmarkColors.map((hex) {
                        final color = Color(_parseColor(hex));
                        final isSelected = hex == selectedColor;
                        return ChoiceChip(
                          label: Icon(
                            isSelected ? Icons.check : Icons.circle,
                            size: isSelected ? 16 : 10,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : color,
                          ),
                          selected: isSelected,
                          selectedColor: color,
                          backgroundColor: color.withValues(alpha: 0.25),
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          shape: StadiumBorder(
                            side: BorderSide(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : color,
                              width: 2,
                            ),
                          ),
                          onSelected: (_) =>
                              setModalState(() => selectedColor = hex),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        hintText: 'e.g. To Memorize',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          label: const Text('Save'),
                          onPressed: () {
                            Navigator.pop<Map<String, String?>>(context, {
                              'color': selectedColor,
                              'category': categoryController.text.trim(),
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    final color = result['color'] ?? _bookmarkColors.first;
    final category =
        (result['category']?.isEmpty ?? true) ? null : result['category'];

    await state.saveBookmark(
      surahId: surah,
      ayahId: verse,
      colorHex: color,
      category: category,
    );

    if (mounted) {
      _showSnack('Bookmark saved');
    }
  }

  Future<void> _openNoteSheet(
    BuildContext context,
    BookmarkNotesNotifier state,
    int surah,
    int verse,
  ) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Note for Surah $surah:$verse',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your note here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final text = controller.text.trim();
                    if (text.isEmpty) {
                      if (existing != null) {
                        await state.deleteNoteForVerse(surah, verse);
                        if (mounted) _showSnack('Note removed');
                      }
                    } else {
                      await state.upsertNote(
                        surahId: surah,
                        ayahId: verse,
                        content: text,
                      );
                      if (mounted) _showSnack('Note saved');
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _viewTafsir(BuildContext context, int surah, int verse) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseDetailsScreen(
          surahNumber: surah,
          ayahNumber: verse,
        ),
      ),
    );
  }

  Future<void> _shareVerseCard(int surah, int verse) async {
    try {
      final name = getSurahName(surah);
      final text = getVerseQCF(surah, verse);
      final widget = Container(
        padding: const EdgeInsets.all(24),
        color: Colors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Surah $name - Verse $verse',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 24,
                fontFamily: 'QCF_BSML', // Simplified shared font
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Shared via Ayah App',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );

      final image = await _screenshotController.captureFromWidget(widget);
      final temp = await getTemporaryDirectory();
      final path = '${temp.path}/ayah_share.png';
      final file = File(path);
      await file.writeAsBytes(image);

      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Surah $name:$verse');
    } catch (e) {
      _showSnack('Failed to share: $e');
    }
  }

  void _copyVerseText(int surah, int verse) {
    final text = getVerseQCF(surah, verse);
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Verse text copied');
  }
}

class _NavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _NavPill({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = enabled
        ? _brandGreen
        : Theme.of(context).colorScheme.onSurface.withOpacity(0.25);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: IconButton(
            onPressed: enabled ? onTap : null,
            icon: Icon(icon, color: iconColor),
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}
