import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/services/audio_player_service.dart';
import '../../audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/bookmark_screen.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/share/presentation/dialogs/share_preview_dialog.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';
import 'play_range_dialog.dart';
import 'surah_info_sheet.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/features/share/presentation/widgets/share_card.dart';
import 'package:quran_app/features/share/services/share_service.dart';

// Result type for the verse menu editor dialog
class _MenuEditResult {
  _MenuEditResult({required this.order, required this.hidden});
  final List<String> order;
  final List<String> hidden;
}

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
  double? _sliderValue;
  bool _isSliderActive = false;
  int _lastControllerPage = 1;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  Timer? _highlightClearTimer;

  double _contentOpacity = 1.0;
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  bool _isFading = false;

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
    _pageController = PageController(
      initialPage: widget.controller.currentPage - 1,
    );
    _lastControllerPage = widget.controller.currentPage;

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
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page - 1);
      }
    });

    widget.controller.addListener(_onControllerChanged);
    _scheduleAutoHide();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onOverlayVisibilityChanged?.call(true);
    });

    _loadSectionOrder();
  }

  @override
  void dispose() {
    _navSubscription?.cancel();
    _audioPlayer.currentSurah.removeListener(_ayahListener);
    _audioPlayer.currentAyah.removeListener(_ayahListener);
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _autoHideTimer?.cancel();
    _highlightClearTimer?.cancel();
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
    final controllerPage = widget.controller.currentPage;
    if (controllerPage == _lastControllerPage) return;
    _lastControllerPage = controllerPage;
  }

  double _getDisplayPage() {
    if (_isSliderActive && _sliderValue != null) return _sliderValue!;
    if (_pageController.hasClients &&
        _pageController.position.hasContentDimensions) {
      return (_pageController.page ?? 0) + 1;
    }
    return widget.controller.currentPage.toDouble();
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
                                widget.controller.setPage(page);
                              },
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              pageBackgroundColor: ThemeService()
                                  .getMushafBackgroundColor(
                                      Theme.of(context).brightness),
                              verseBackgroundColor: (s, v) =>
                                  _getVerseBackgroundColor(bookmarkState, s, v),
                              onLongPress: (surah, verse) => _showVerseOptions(
                                  context, bookmarkState, surah, verse),
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
          final currentDouble = _getDisplayPage();
          final currentPage = currentDouble.round();
          final panelMaxWidth =
              ResponsiveLayout.scaled(context, 540, min: 360, max: 640);
          final bottomPad = MediaQuery.paddingOf(context).bottom;

          return RepaintBoundary(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAudioPlayerCard(),
                const SizedBox(height: 2),
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
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          ResponsiveLayout.scaled(context, 12,
                              min: 10, max: 16),
                          ResponsiveLayout.scaled(context, 4, min: 2, max: 8),
                          ResponsiveLayout.scaled(context, 12,
                              min: 10, max: 16),
                          bottomPad +
                              ResponsiveLayout.scaled(context, 8,
                                  min: 6, max: 14),
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _NavPill(
                                icon: Icons.subdirectory_arrow_left,
                                label: currentPage < 604
                                    ? '${currentPage + 1}'
                                    : '',
                                enabled: currentPage < 604,
                                onTap: () =>
                                    _navigateWithFade(currentPage + 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    const double trackH = 28;
                                    const double pillW = 44;

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
                                                          .withOpacity(0.12),
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
                                            width:
                                                pillPositionFromRight + pillW,
                                            top: 0,
                                            bottom: 0,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black.withOpacity(
                                                        Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? 0.22
                                                            : 0.13),
                                                    Colors.black.withOpacity(
                                                        Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? 0.13
                                                            : 0.07),
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
                                                  '$currentPage',
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
                                                trackHeight: trackH,
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
                                                    _sliderValue = 605 -
                                                        value; // Reverse to get the correct page
                                                    _overlayVisible = true;
                                                  });
                                                },
                                                onChanged: (value) {
                                                  setState(() {
                                                    _overlayVisible = true;
                                                    _sliderValue = 605 -
                                                        value; // Reverse to get the correct page
                                                  });
                                                },
                                                onChangeEnd: (value) {
                                                  final page = (605 - value)
                                                      .round(); // Reverse to get the correct page
                                                  _navigateWithFade(page)
                                                      .then((_) {
                                                    if (mounted) {
                                                      setState(() {
                                                        _isSliderActive = false;
                                                        _sliderValue = null;
                                                      });
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
                                ),
                              ),
                              const SizedBox(width: 12),
                              _NotesIcon(onTap: _openPageSettingsSheet),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _surahNameForPage(int page) {
    final cached = _surahNameCache[page];
    if (cached != null) return cached;
    try {
      final pd = getPageData(page);
      if (pd.isEmpty) return '';
      final surahNum = int.parse(pd[0]['surah'].toString());
      final name = getSurahName(surahNum);
      _surahNameCache[page] = name;
      return name;
    } catch (e) {
      return '';
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

  Future<void> _openPageSettingsSheet() async {
    final mushafSettings = MushafSettingsService();
    final themeService = ThemeService();
    final prefs = await SharedPreferences.getInstance();
    bool searchGesture = prefs.getBool('search_gesture_enabled') ?? false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          minChildSize: 0.5,
          initialChildSize: 0.5,
          maxChildSize: 0.8,
          builder: (context, controller) {
            return StatefulBuilder(
              builder: (context, setStateSheet) {
                ScrollMode mode = mushafSettings.scrollMode;
                ThemeMode themeMode = themeService.themeMode;
                SurahHeaderStyle surahStyle = themeService.surahHeaderStyle;

                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Page Settings',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
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
                                Text('Scroll Direction',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
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
                                Text('Theme Mode',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: ThemeMode.values
                                      .where((t) => t != ThemeMode.system)
                                      .map((t) {
                                    final selected = t == themeMode;
                                    String label =
                                        t == ThemeMode.light ? 'Light' : 'Dark';
                                    IconData icon = t == ThemeMode.light
                                        ? Icons.wb_sunny
                                        : Icons.nightlight_round;
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
                                if (themeMode == ThemeMode.dark) ...[
                                  const SizedBox(height: 18),
                                  SwitchListTile(
                                    title: const Text('Pure Black Background',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600)),
                                    subtitle:
                                        const Text('Use pure black for Mushaf'),
                                    value: themeService.pureBlackBackground,
                                    onChanged: (value) {
                                      themeService
                                          .setPureBlackBackground(value);
                                      setStateSheet(() {});
                                    },
                                    activeColor: BrandColors.accent,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ],
                                if (themeMode != ThemeMode.dark) ...[
                                  const SizedBox(height: 18),
                                  Text('Surah Header Style',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children:
                                        SurahHeaderStyle.values.map((s) {
                                      final selected = s == surahStyle;
                                      return _ThemeModeTile(
                                        label: s == SurahHeaderStyle.golden
                                            ? 'Golden'
                                            : 'Green',
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
                                Row(
                                  children: [
                                    const Expanded(
                                        child: Text('Two-finger Search',
                                            style: TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    Switch.adaptive(
                                      value: searchGesture,
                                      onChanged: (val) async {
                                        setStateSheet(
                                            () => searchGesture = val);
                                        await prefs.setBool(
                                            'search_gesture_enabled', val);
                                      },
                                      activeColor: BrandColors.accent,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
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

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (e) {
      return 0xFFFFC107;
    }
  }

  void _showVerseOptions(BuildContext context,
      BookmarkNotesNotifier bookmarkState, int surah, int verse) {
    final rootContext = context;
    final surahTitle = '${getSurahName(surah)}: $verse';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(context);
        final width = MediaQuery.of(context).size.width;
        final shareCardWidth = (width - 16 * 2 - 12 * 3) / 4;

        final orderedSections = _buildOrderedSections(sheetContext,
            bookmarkState, surah, verse, shareCardWidth, rootContext);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              child: Container(
                decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24)),
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
                              child: const Text('Edit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: BrandColors.accent)),
                            ),
                            Expanded(
                                child: Center(
                                    child: Text(surahTitle,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 18)))),
                            IconButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...orderedSections,
                        const SizedBox(height: 12),
                        const Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        _buildQuickActions(
                            context, bookmarkState, rootContext, surah, verse),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(_scheduleHighlightClear);
  }

  List<Widget> _buildOrderedSections(
      BuildContext context,
      BookmarkNotesNotifier bookmarkState,
      int surah,
      int verse,
      double shareCardWidth,
      BuildContext rootContext) {
    final widgets = <Widget>[];
    for (final section in _sectionOrder) {
      if (_hiddenSections.contains(section)) continue;
      switch (section) {
        case 'bookmarks':
          widgets.add(const Text('Bookmarks',
              style: TextStyle(fontWeight: FontWeight.w700)));
          widgets.add(const SizedBox(height: 8));
          widgets.add(Row(children: [
            Expanded(
                child: _buildActionCard(context,
                    width: double.infinity,
                    icon: Icons.bookmark_border,
                    iconColor: Colors.redAccent,
                    label: 'Red', onTap: () {
              Navigator.pop(context);
              bookmarkState.saveBookmark(
                  surahId: surah,
                  ayahId: verse,
                  colorHex: '#EF5350',
                  category: 'Red');
            })),
            const SizedBox(width: 12),
            Expanded(
                child: _buildActionCard(context,
                    width: double.infinity,
                    icon: Icons.list_alt,
                    label: 'All',
                    trailing: Icons.chevron_right, onTap: () {
              Navigator.pop(context);
              Navigator.push(rootContext,
                  MaterialPageRoute(builder: (context) => BookmarkScreen()));
            })),
          ]));
          widgets.add(const SizedBox(height: 14));
          break;
        case 'recitation':
          widgets.add(const Text('Recitation',
              style: TextStyle(fontWeight: FontWeight.w700)));
          widgets.add(const SizedBox(height: 8));
          widgets.add(Row(children: [
            Expanded(
                child: _buildActionCard(context,
                    width: double.infinity,
                    icon: Icons.play_arrow,
                    label: 'Play', onTap: () {
              Navigator.pop(context);
              AudioPlayerService.instance
                  .playSurahSequenceWithDownload(rootContext, surah, verse);
            })),
            const SizedBox(width: 12),
            Expanded(
                child: _buildActionCard(context,
                    width: double.infinity,
                    icon: Icons.playlist_play,
                    label: 'Play to...', onTap: () {
              Navigator.pop(context);
              _showPlayToDialog(rootContext, surah, verse);
            })),
          ]));
          widgets.add(const SizedBox(height: 14));
          break;
        case 'downloads':
          widgets.add(_buildActionCard(context,
              width: double.infinity,
              icon: Icons.download_rounded,
              label: 'Downloads',
              trailing: Icons.chevron_right, onTap: () {
            Navigator.pop(context);
            Navigator.push(rootContext,
                MaterialPageRoute(builder: (context) => DownloadsScreen()));
          }));
          widgets.add(const SizedBox(height: 14));
          break;
        case 'sharing':
          widgets.add(Row(children: [
            _buildActionCard(context,
                width: shareCardWidth,
                icon: Icons.copy,
                label: 'Copy',
                onTap: () => _copyVerseText(surah, verse)),
            const SizedBox(width: 8),
            _buildActionCard(context,
                width: shareCardWidth,
                icon: Icons.image_outlined,
                label: 'Card',
                onTap: () => _shareVerseCard(surah, verse)),
            const SizedBox(width: 8),
            _buildActionCard(context,
                width: shareCardWidth,
                icon: Icons.share,
                label: 'Share',
                onTap: () => _openShareSheet(rootContext, surah, verse)),
          ]));
          widgets.add(const SizedBox(height: 14));
          break;
        case 'highlight':
          widgets.add(_buildHighlightRow(context, bookmarkState, surah, verse));
          widgets.add(const SizedBox(height: 14));
          break;
      }
    }
    return widgets;
  }

  Widget _buildActionCard(BuildContext context,
      {required double width,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
      IconData? trailing,
      bool enabled = true,
      Color? iconColor}) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor ?? BrandColors.accent),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis)),
              if (trailing != null) Icon(trailing, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightRow(
      BuildContext context, BookmarkNotesNotifier state, int surah, int verse) {
    final existingColor =
        state.bookmarkForVerse(surah, verse)?.colorHex.toLowerCase();
    return Row(
      children: _bookmarkColors.map((hex) {
        final color = Color(_parseColor(hex));
        final isSelected = existingColor == hex.toLowerCase();
        return Padding(
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
                    category: _getCategoryName(hex));
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.2),
                  border:
                      Border.all(color: color, width: isSelected ? 3 : 1)),
              child: isSelected ? const Icon(Icons.check, size: 20) : null,
            ),
          ),
        );
      }).toList(),
    );
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
    return Column(children: [
      _buildActionCard(context,
          width: double.infinity,
          icon: Icons.push_pin_outlined,
          label: 'Pin here (Khatmah)', onTap: () {
        Navigator.pop(context);
        state.setKhatmahPin(
            surahId: surah,
            ayahId: verse,
            colorHex: '#FFB300',
            category: 'Khatmah');
      }),
      const SizedBox(height: 10),
      _buildActionCard(context,
          width: double.infinity,
          icon: Icons.note_add_outlined,
          label: 'Write note', onTap: () {
        Navigator.pop(context);
        _openNoteSheet(rootContext, state, surah, verse);
      }),
    ]);
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

  Future<_MenuEditResult?> _openMenuEditor(BuildContext context) async {
    final order = List<String>.from(_sectionOrder);
    final hidden = List<String>.from(_hiddenSections);
    return showModalBottomSheet<_MenuEditResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setSheetState) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Edit Menu Order',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...order.map((item) => ListTile(
                    title: Text(item),
                    trailing: IconButton(
                        icon: const Icon(Icons.hide_source),
                        onPressed: () {
                          setSheetState(() {
                            order.remove(item);
                            hidden.add(item);
                          });
                        }))),
                ElevatedButton(
                    onPressed: () => Navigator.pop(
                        ctx, _MenuEditResult(order: order, hidden: hidden)),
                    child: const Text('Done'))
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _openNoteSheet(BuildContext context, BookmarkNotesNotifier state,
      int surah, int verse) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Note content')),
            ElevatedButton(
                onPressed: () {
                  state.upsertNote(
                      surahId: surah, ayahId: verse, content: controller.text);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'))
          ],
        ),
      ),
    );
  }

  Future<void> _openShareSheet(
      BuildContext context, int surah, int verse) async {
    final surahName = getSurahName(surah);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share $surahName: $verse'),
            ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Share as Text'),
                onTap: () {
                  ShareService.instance
                      .shareVerseText(surahNumber: surah, ayahNumber: verse);
                  Navigator.pop(ctx);
                }),
          ],
        ),
      ),
    );
  }

  Future<void> _shareVerseCard(int surah, int verse) async {
    await showSharePreviewDialog(
        context: context, surahNumber: surah, ayahNumber: verse);
  }

  Future<void> _showPlayToDialog(
      BuildContext context, int startSurah, int startVerse) async {
    await showModalBottomSheet(
        context: context,
        builder: (ctx) =>
            PlayRangeDialog(startSurah: startSurah, startVerse: startVerse));
  }

  void _copyVerseText(int surah, int verse) {
    Clipboard.setData(
        ClipboardData(text: getVerseQCF(surah, verse, verseEndSymbol: true)));
    _showSnack('Copied to clipboard');
  }

  ({ShareCardBackground background, bool isDark, String frameAsset})
      _resolveShareCardTheme() {
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;
    final background = isDarkMode
        ? ShareCardBackground.gradient(const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF2C5364)]))
        : ShareCardBackground.solid(const Color(0xFFFFF4DA));
    return (
      background: background,
      isDark: isDarkMode,
      frameAsset: ThemeService().getResponsiveMainframePath(brightness)
    );
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
            : Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: selected
                    ? BrandColors.accent
                    : Colors.grey.withOpacity(0.3))),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: selected ? BrandColors.accent : Colors.grey),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? BrandColors.accent : null))
        ]),
      ),
    );
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