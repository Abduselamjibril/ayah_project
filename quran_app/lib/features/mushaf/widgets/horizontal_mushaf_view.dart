import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/services/audio_player_service.dart';
import '../../audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/highlights/state/highlight_notifier.dart';
import '../controller/mushaf_controller.dart';
import 'surah_info_sheet.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

// Result type for the verse menu editor dialog
import 'verse_options_sheet.dart';
import 'page_settings_sheet.dart';

enum _ShareFormat { image, text, textWithoutDiacritics }

class HorizontalMushafView extends StatefulWidget {
  final MushafController controller;
  final ValueChanged<bool>? onOverlayVisibilityChanged;
  final VoidCallback? onDragDown;

  const HorizontalMushafView({
    super.key,
    required this.controller,
    this.onOverlayVisibilityChanged,
    this.onDragDown,
  });

  @override
  State<HorizontalMushafView> createState() => _HorizontalMushafViewState();
}

class _HorizontalMushafViewState extends State<HorizontalMushafView> {
  late PageController _pageController;
  final ValueNotifier<double?> _sliderDragNotifier =
      ValueNotifier<double?>(null);
  bool _isSliderActive = false;
  int _lastControllerPage = 1;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  late final VoidCallback _audioStateListener;
  final Map<int, String> _surahNameCache = {};

  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  Timer? _highlightClearTimer;

  double _contentOpacity = 1.0;
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  bool _isFading = false;

  // Audio-page synchronization tracking
  int? _previousAudioPage;
  DateTime? _lastManualPageChange;

  StreamSubscription<int>? _navSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.controller.currentPage - 1,
    );
    _lastControllerPage = widget.controller.currentPage;

    _audioPlayer = AudioPlayerService.instance;
    _audioStateListener = () {
      if (!mounted) return;
      if (_audioPlayer.isPlaying.value || _audioPlayer.isDownloading.value) {
        _cancelHighlightClear();
      }
    };
    _audioPlayer.isPlaying.addListener(_audioStateListener);
    _audioPlayer.isDownloading.addListener(_audioStateListener);

    _ayahListener = () {
      if (!mounted) return;
      final s = _audioPlayer.currentSurah.value;
      final a = _audioPlayer.currentAyah.value;

      if (s != null && a != null) {
        _cancelHighlightClear();
        widget.controller.setHighlightedVerse(s, a, isAudio: true);

        // Calculate which page this ayah is on
        final audioPage = getPageNumber(s, a);
        final displayedPage = _getBasePage().round();

        // Detect page transition: did audio move to a different page?
        if (_previousAudioPage != null && _previousAudioPage != audioPage) {
          // Page changed! Check if we were synced on the PREVIOUS page
          // We need to check if displayedPage matches the OLD audio page, not the new one
          final wasSyncedOnPreviousPage = (displayedPage == _previousAudioPage);

          // Check if user recently manually navigated (within last 500ms)
          final timeSinceManualNav = _lastManualPageChange != null
              ? DateTime.now().difference(_lastManualPageChange!)
              : Duration.zero;
          final isRecentManualNav = timeSinceManualNav.inMilliseconds < 500;

          if (wasSyncedOnPreviousPage && !isRecentManualNav) {
            // We were following along and user hasn't manually navigated recently
            widget.controller.navigateToPage(audioPage);
          }
        }

        _previousAudioPage = audioPage;
      } else {
        widget.controller.clearHighlight();
        _previousAudioPage = null;
      }
    };
    _audioPlayer.currentSurah.addListener(_ayahListener);
    _audioPlayer.currentAyah.addListener(_ayahListener);

    _navSubscription = widget.controller.navigationStream.listen((page) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page - 1);
      }
    });

    widget.controller.addListener(_onControllerChanged);
    _scheduleAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOverlayVisibilityChanged?.call(true);
    });
  }

  @override
  void didUpdateWidget(HorizontalMushafView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if we need to sync with the controller's page when becoming visible
    // This happens when switching from vertical to horizontal mode
    if (_pageController.hasClients) {
      final controllerPage = widget.controller.currentPage;
      final currentDisplayedPage = _getBasePage().round();

      // If there's a mismatch, navigate to the controller's page
      if (controllerPage != currentDisplayedPage &&
          (controllerPage - currentDisplayedPage).abs() > 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && mounted) {
            _pageController.jumpToPage(controllerPage - 1);
            _lastControllerPage = controllerPage;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    _audioPlayer.currentSurah.removeListener(_ayahListener);
    _audioPlayer.currentAyah.removeListener(_ayahListener);
    _audioPlayer.isPlaying.removeListener(_audioStateListener);
    _audioPlayer.isDownloading.removeListener(_audioStateListener);
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _autoHideTimer?.cancel();
    _highlightClearTimer?.cancel();
    _sliderDragNotifier.dispose();
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
      widget.controller.clearHighlight(onlyManual: true);
    });
  }

  void _navigateToVerseWithTempHighlight(int surah, int verse) {
    _cancelHighlightClear();
    widget.controller.navigateToVerse(surah, verse);
    _scheduleHighlightClear();
  }

  void _onControllerChanged() {
    final controllerPage = widget.controller.currentPage;
    if (controllerPage == _lastControllerPage) return;
    _lastControllerPage = controllerPage;
  }

  double _getDisplayPage() {
    final dragValue = _sliderDragNotifier.value;
    if (_isSliderActive && dragValue != null) return dragValue;
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions) {
      return (_pageController.page ?? 0) + 1;
    }
    return widget.controller.currentPage.toDouble();
  }

  double _getBasePage() {
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions) {
      return (_pageController.page ?? 0) + 1;
    }
    return widget.controller.currentPage.toDouble();
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
    } catch (_) {
      return '';
    }
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
            onVerticalDragUpdate: _handleVerticalDrag,
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
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: ListenableBuilder(
                          listenable: Listenable.merge(
                              [widget.controller, ThemeService()]),
                          builder: (context, _) {
                            return PageviewQuran(
                              controller: _pageController,
                              initialPageNumber: widget.controller.currentPage,
                              scrollMode: ScrollMode.horizontal,
                              onPageChanged: (page) {
                                _lastManualPageChange = DateTime.now();
                                widget.controller.setPage(page);
                              },
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              pageBackgroundColor: ThemeService()
                                  .getMushafBackgroundColor(
                                      Theme.of(context).brightness),
                              verseBackgroundColor: (s, v) =>
                                  _getVerseBackgroundColor(bookmarkState, s, v),
                              onLongPress: (surah, verse) {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (context) => VerseOptionsSheet(
                                    surah: surah,
                                    verse: verse,
                                  ),
                                ).whenComplete(_scheduleHighlightClear);
                              },
                              onLongPressStart: (surah, verse, details) {
                                _cancelHighlightClear();
                                widget.controller
                                    .setHighlightedVerse(surah, verse);
                              },
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
        _buildPageOverlay(),
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
      if (b.isKhatmahPin) return null;
      final color = Color(_parseColor(b.colorHex));
      return color.withOpacity(0.25);
    }
    return null;
  }

  Widget _buildPageOverlay() {
    if (!_overlayVisible) return const SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, _pageController]),
        builder: (context, child) {
          final baseDouble = _getBasePage();
          final basePage = baseDouble.round();
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
                if (isSliding)
                  ValueListenableBuilder<double?>(
                    valueListenable: _sliderDragNotifier,
                    builder: (context, dragValue, _) {
                      final currentDouble = dragValue ?? baseDouble;
                      final currentPage = currentDouble.round();
                      final surahName = _surahNameForPage(currentPage);
                      return Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceVariant
                              .withOpacity(0.95),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.2),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              surahName,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Page ${currentPage.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                else
                  _buildAudioPlayerCard(),
                const SizedBox(height: 2),
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: panelMaxWidth),
                    child: Card(
                      elevation: 16,
                      margin: EdgeInsets.zero,
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          ResponsiveLayout.scaled(context, 12,
                              min: 10, max: 16),
                          ResponsiveLayout.scaled(context, 4, min: 2, max: 8),
                          ResponsiveLayout.scaled(context, 12,
                              min: 10, max: 16),
                          bottomPad,
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                width: isSliding ? 0 : null,
                                child: ClipRect(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    opacity: isSliding ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: isSliding,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _NavPill(
                                            icon: Icons.subdirectory_arrow_left,
                                            label: basePage < 604
                                                ? '${basePage + 1}'
                                                : '',
                                            enabled: basePage < 604,
                                            onTap: () =>
                                                _navigateWithFade(basePage + 1),
                                          ),
                                          const SizedBox(width: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    const double trackH = 28;
                                    const double pillW = 44;
                                    return ValueListenableBuilder<double?>(
                                      valueListenable: _sliderDragNotifier,
                                      builder: (context, dragValue, _) {
                                        final currentDouble =
                                            (isSliding && dragValue != null)
                                                ? dragValue
                                                : baseDouble;

                                        // For RTL: page 1 is at the right, page 604 at the left
                                        // The slider value is reversed so that visually, 1 is at the right and 604 at the left
                                        final double sliderValue =
                                            605 - currentDouble;
                                        // For RTL: page 1 is at the right, so fraction = 0 means rightmost
                                        final double fraction =
                                            ((currentDouble - 1.0) / 603.0)
                                                .clamp(0.0, 1.0);
                                        final double pillPositionFromRight =
                                            (c.maxWidth - pillW) * fraction;

                                        return SizedBox(
                                          height: trackH,
                                          child: Stack(
                                            children: [
                                              // Not passed area (lighter, left of the pill) with border and shadow for visibility
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surface,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            trackH / 2),
                                                    border: Border.all(
                                                      color: Theme.of(context)
                                                                  .brightness ==
                                                              Brightness.dark
                                                          ? Colors.white
                                                              .withOpacity(0.10)
                                                          : Colors.black
                                                              .withOpacity(
                                                                  0.12),
                                                      width: 1.2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.10),
                                                        blurRadius: 6,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Passed area (darker, after the pill, RTL) with vertical gradient
                                              Positioned(
                                                right: 0,
                                                width: pillPositionFromRight +
                                                    pillW,
                                                top: 0,
                                                bottom: 0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                        Theme.of(context)
                                                            .colorScheme
                                                            .surfaceContainerHighest,
                                                      ],
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.horizontal(
                                                      right: Radius.circular(
                                                          trackH / 2),
                                                      left: Radius.circular(
                                                          trackH / 2),
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.22),
                                                        blurRadius: 12,
                                                        offset:
                                                            const Offset(-3, 0),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // The pill
                                              Positioned(
                                                right: pillPositionFromRight,
                                                top: 0,
                                                width: pillW,
                                                height: trackH,
                                                child: IgnorePointer(
                                                  child: Container(
                                                    alignment: Alignment.center,
                                                    decoration: BoxDecoration(
                                                      color: BrandColors.accent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              trackH / 2),
                                                    ),
                                                    child: Text(
                                                      '${currentDouble.round()}',
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w700),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              // Transparent slider for interaction
                                              Positioned.fill(
                                                child: SliderTheme(
                                                  data: SliderTheme.of(context)
                                                      .copyWith(
                                                    activeTrackColor:
                                                        Colors.transparent,
                                                    inactiveTrackColor:
                                                        Colors.transparent,
                                                    thumbShape:
                                                        const RoundSliderThumbShape(
                                                            enabledThumbRadius:
                                                                0.0),
                                                    overlayShape:
                                                        const RoundSliderOverlayShape(
                                                            overlayRadius: 0),
                                                  ),
                                                  child: Slider(
                                                    min: 1,
                                                    max: 604,
                                                    divisions: 603,
                                                    value: sliderValue,
                                                    onChangeStart: (value) {
                                                      setState(() {
                                                        _isSliderActive = true;
                                                        _overlayVisible = true;
                                                      });
                                                      _sliderDragNotifier
                                                              .value =
                                                          605 -
                                                              value; // Reverse to get the correct page
                                                    },
                                                    onChanged: (value) {
                                                      if (!_isSliderActive) {
                                                        setState(() {
                                                          _isSliderActive =
                                                              true;
                                                          _overlayVisible =
                                                              true;
                                                        });
                                                      }
                                                      _sliderDragNotifier
                                                              .value =
                                                          605 -
                                                              value; // Reverse to get the correct page
                                                    },
                                                    onChangeEnd: (value) {
                                                      final page = (605 - value)
                                                          .round(); // Reverse to get the correct page
                                                      _navigateWithFade(page)
                                                          .then((_) {
                                                        if (mounted) {
                                                          setState(() {
                                                            _isSliderActive =
                                                                false;
                                                          });
                                                          _sliderDragNotifier
                                                              .value = null;
                                                        }
                                                      });
                                                      _scheduleAutoHide();
                                                    },
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
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                curve: Curves.easeOut,
                                width: isSliding ? 0 : null,
                                child: ClipRect(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 120),
                                    opacity: isSliding ? 0.0 : 1.0,
                                    child: IgnorePointer(
                                      ignoring: isSliding,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(width: 12),
                                          _NotesIcon(
                                              onTap: _openPageSettingsSheet),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
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
      ),
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
              overrideCurrentPage: _getDisplayPage().round(),
            ),
          ),
        ),
      ),
    );
  }

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (e) {
      return 0xFFFFC107;
    }
  }

  Future<void> _navigateWithFade(int page) async {
    final target = page.clamp(1, 604);
    if (_isFading) return;
    _isFading = true;
    try {
      if (mounted) setState(() => _contentOpacity = 0.5);
      final half =
          Duration(milliseconds: (_fadeDuration.inMilliseconds / 2).round());
      await Future.delayed(half);
      if (!mounted) return;
      widget.controller.navigateToPage(target);
      if (mounted) setState(() => _contentOpacity = 1);
      await Future.delayed(_fadeDuration);
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

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() => _overlayVisible = false);
      widget.onOverlayVisibilityChanged?.call(false);
    });
  }

  void _showOverlay() {
    if (!_overlayVisible) {
      setState(() => _overlayVisible = true);
      widget.onOverlayVisibilityChanged?.call(true);
    }
    _scheduleAutoHide();
  }

  void _hideOverlay() {
    if (_overlayVisible) {
      setState(() => _overlayVisible = false);
      widget.onOverlayVisibilityChanged?.call(false);
    }
    _autoHideTimer?.cancel();
  }

  void _toggleOverlay() {
    if (_overlayVisible) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    final delta = details.primaryDelta;
    if (delta != null && delta > 8) {
      widget.onDragDown?.call();
      _showOverlay();
    }
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
        icon: const Icon(Icons.menu_book_rounded,
            color: BrandColors.accent, size: 26));
  }
}

class _SurahListEntry {
  final bool isHeader;
  final int juzNumber;
  final Map<String, dynamic>? surahInfo;
  const _SurahListEntry._(this.isHeader, this.juzNumber, this.surahInfo);
  factory _SurahListEntry.header(int juzNumber) =>
      _SurahListEntry._(true, juzNumber, null);
  factory _SurahListEntry.surah(int juzNumber, Map<String, dynamic> info) =>
      _SurahListEntry._(false, juzNumber, info);
}
