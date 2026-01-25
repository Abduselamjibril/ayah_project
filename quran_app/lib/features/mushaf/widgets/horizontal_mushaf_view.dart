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
  // _livePage removed as it was unused after refactor
  bool _isSliderActive = false;
  int _lastControllerPage = 1;
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  Timer? _highlightClearTimer;
  final bool _isSequentialMode = false;

  double _contentOpacity = 1.0;
  static const Duration _fadeDuration = Duration(milliseconds: 220);
  bool _isFading = false;

  static const List<String> _bookmarkColors = [
    '#FFB300',
    '#4DB6AC',
    '#29B6F6',
    '#AB47BC',
    '#EF5350',
    '#8D6E63',
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
    // _livePage and _sliderValue state moved to ValueNotifiers/local calculation
    // Removed _handlePageScroll listener that caused setStates

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
    // No listener to remove for _handlePageScroll
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
    // final targetPage = controllerPage - 1; // Removed as part of fix

    // Only update the local tracker.
    // Programmatic jumps (e.g. from search/surah list) are handled via navigationStream.
    // Manual scrolling updates currentPage via onPageChanged.
    // We do NOT want to force a jump here because:
    // 1. It causes "fighting" if the user is mid-scroll.
    // 2. It causes reset jumps if notifyListeners() is called for non-page-change events (e.g. highlights)
    //    and round() calculations are slightly off.
  }

  // Helper to get current display page from controller or slider
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
                                // No setState here for live page, only controller update
                                widget.controller.setPage(page);
                              },
                              textColor:
                                  Theme.of(context).colorScheme.onSurface,
                              pageBackgroundColor:
                                  Theme.of(context).scaffoldBackgroundColor,
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
      return Theme.of(context)
          .colorScheme
          .primaryContainer
          .withValues(alpha: 0.5);
    }

    final b = state.bookmarkForVerse(surah, verse);
    if (b != null) {
      if (b.isKhatmahPin) return null;
      final color = Color(_parseColor(b.colorHex));
      return color.withValues(alpha: 0.25);
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
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  surahName,
                                  textAlign: TextAlign.right,
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
                                  textAlign: TextAlign.right,
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
                const SizedBox(height: 4),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                          // Using LTR for the Row layout: [NavPill | Slider | Notes]
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // ORIGINAL ICON RESTORED: subdirectory_arrow_left
                              // LOGIC: Moves to NEXT page (Page 1 -> 2)
                              _NavPill(
                                icon: Icons.subdirectory_arrow_left,
                                label: currentPage < 604
                                    ? '${currentPage + 1}'
                                    : '',
                                enabled: currentPage < 604,
                                onTap: () => _navigateWithFade(currentPage + 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    const double trackH = 28;
                                    const double pillW = 44;
                                    // Fraction of the total book
                                    final double fraction =
                                        ((currentDouble - 1.0) / 603.0)
                                            .clamp(0.0, 1.0);

                                    // REVERSED CALCULATION:
                                    // Measuring from the right makes Page 1 start on the right side.
                                    final double pillPositionFromRight =
                                        (c.maxWidth - pillW) * fraction;

                                    return SizedBox(
                                      height: trackH,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Directionality(
                                              // Forces slider track to fill from right to left
                                              textDirection: TextDirection.rtl,
                                              child: SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                  trackHeight: trackH,
                                                  inactiveTrackColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.2),
                                                  activeTrackColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .onSurface
                                                          .withOpacity(0.2),
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
                                                  value: currentDouble,
                                                  onChangeStart: (value) {
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
                                                    final page = value.round();
                                                    setState(() {
                                                      _isSliderActive = false;
                                                      _sliderValue = null;
                                                    });
                                                    _navigateWithFade(page);
                                                    _scheduleAutoHide();
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            // Pill anchored to the right side
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
                                                    fontWeight: FontWeight.w700,
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
                              ),
                              const SizedBox(width: 12),
                              // ORIGINAL NOTES ICON RESTORED
                              _NotesIcon(
                                onTap: _openPageSettingsSheet,
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
    final prefs = await SharedPreferences.getInstance();
    bool searchGesture = prefs.getBool('search_gesture_enabled') ?? false;

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

                                // Show Surah Header Style only if NOT strictly Dark mode
                                // (It works in System too if system is Light, but simplest is to just show it generally or check brightness)
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
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Two-finger Search',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w700),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Drag down to search',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                      .withOpacity(0.6),
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: searchGesture,
                                      onChanged: (val) async {
                                        setStateSheet(
                                            () => searchGesture = val);
                                        await prefs.setBool(
                                            'search_gesture_enabled', val);
                                      },
                                      activeColor:
                                          Theme.of(context).colorScheme.primary,
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

  ({ShareCardBackground background, bool isDark, String frameAsset})
      _resolveShareCardTheme() {
    final themeService = ThemeService();
    // For sharing, we check the actual brightness context or just the mode.
    // Since this is a method, we can check the current context brightness.
    final brightness = Theme.of(context).brightness;
    final isDarkMode = brightness == Brightness.dark;

    ShareCardBackground background;

    if (isDarkMode) {
      // Dark Mode -> Ornate Twilight (Green/Blue Dark Gradient)
      background = ShareCardBackground.gradient(
        const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else {
      // Light Mode -> Golden Parchment (Solid)
      background = ShareCardBackground.solid(const Color(0xFFFFF4DA));
    }

    return (
      background: background,
      isDark: isDarkMode,
      frameAsset: themeService.getResponsiveMainframePath(brightness),
    );
  }

  void _toggleOverlay() {
    if (_overlayVisible)
      _hideOverlay();
    else
      _showOverlay();
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
    ).whenComplete(_scheduleHighlightClear);
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
                    _shareVerseCard(surah, verse);
                  }),
                  _buildActionCard(context,
                      width: shareCardWidth,
                      icon: Icons.share,
                      label: 'Share', onTap: () {
                    Navigator.pop(context);
                    _openShareSheet(rootContext, surah, verse);
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
            unawaited(() async {
              await state.saveBookmark(
                  surahId: surah,
                  ayahId: verse,
                  colorHex: hex,
                  category: 'Highlight');
              if (!mounted) return;
              _showBookmarkSnackbar(context, false);
            }());
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
        return Padding(
          padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16),
          child: StatefulBuilder(
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

              return Column(
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
              );
            },
          ),
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

  Future<void> _shareVerseCard(int surah, int verse) async {
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
