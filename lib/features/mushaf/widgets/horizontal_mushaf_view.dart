import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/services/audio_player_service.dart';
import '../../audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late final AudioPlayerService _audioPlayer;
  late final VoidCallback _ayahListener;
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;
  final bool _isSequentialMode = false;
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
    _pageController = PageController(
      initialPage: widget.controller.currentPage - 1,
    );
    _sliderValue = widget.controller.currentPage.toDouble();
    _audioPlayer = AudioPlayerService.instance;
    _ayahListener = () {
      if (!mounted || !_isSequentialMode) return;
      final s = _audioPlayer.currentSurah.value;
      final a = _audioPlayer.currentAyah.value;
      if (s != null && a != null) {
        widget.controller.setHighlightedVerse(s, a);
      }
    };
    _audioPlayer.currentSurah.addListener(_ayahListener);
    _audioPlayer.currentAyah.addListener(_ayahListener);

    // Listen for centralized navigation events
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
  void dispose() {
    _navSubscription?.cancel();
    _audioPlayer.currentSurah.removeListener(_ayahListener);
    _audioPlayer.currentAyah.removeListener(_ayahListener);
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    final targetPage = widget.controller.currentPage - 1;
    if (!_isSliderActive && _pageController.hasClients) {
      // Don't interrupt user scrolling with external updates
      if (_pageController.position.isScrollingNotifier.value) return;

      if ((_pageController.page?.round() ?? -1) != targetPage) {
        _sliderValue = null;
        _isSliderActive = false;
        // Use jumpToPage instead of animateToPage to avoid lag with IndexedStack
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = BrandColors.accent;
    final bookmarkState = context.watch<BookmarkNotesNotifier>();
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleOverlay,
          onVerticalDragUpdate: _handleVerticalDrag,
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
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageviewQuran(
                        controller: _pageController,
                        initialPageNumber: widget.controller.currentPage,
                        scrollMode: ScrollMode.horizontal,
                        onPageChanged: (page) {
                          widget.controller.setPage(page);
                        },
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
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        _buildPageOverlay(),
      ],
    );
  }

  Color? _getVerseBackgroundColor(
      BookmarkNotesNotifier state, int surah, int verse) {
    final b = state.bookmarkForVerse(surah, verse);
    if (b != null) {
      if (b.isKhatmahPin) {
        // Last read: no verse-level highlight (represents whole page)
        return null;
      }
      final color = Color(_parseColor(b.colorHex));
      return color.withValues(alpha: 0.25);
    }
    return null;
  }

  Widget _buildPageOverlay() {
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
                    constraints: const BoxConstraints(maxWidth: 540),
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
                          12,
                          4,
                          12,
                          MediaQuery.of(context).padding.bottom + 8,
                        ),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _NavPill(
                                icon: Icons.subdirectory_arrow_left,
                                label:
                                    currentPage > 1 ? '${currentPage - 1}' : '',
                                enabled: currentPage > 1,
                                onTap: () => _navigateToPage(currentPage - 1),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, c) {
                                    const double trackH = 28;
                                    const double pillW = 44;
                                    const double minV = 1.0;
                                    const double maxV = 604.0;
                                    final double fraction =
                                        ((currentDouble - minV) / (maxV - minV))
                                            .clamp(0.0, 1.0);
                                    final double left =
                                        (c.maxWidth - pillW) * fraction;
                                    return SizedBox(
                                      height: trackH,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
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
                                                  _navigateToPage(page);
                                                  _scheduleAutoHide();
                                                },
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: left,
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
    // Memoize to avoid recomputation during rapid slider updates
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

  // Navigation buttons and page number removed in favor of slider

  void _navigateToPage(int page) {
    widget.controller.navigateToPage(page.clamp(1, 604));
  }

  void _openCurrentPageNote(int page) {
    final pd = getPageData(page);
    if (pd.isEmpty) return;
    final first = pd.first;
    final surah = int.tryParse(first['surah'].toString()) ?? 1;
    final ayah = int.tryParse(first['ayah'].toString()) ?? 1;
    final state = context.read<BookmarkNotesNotifier>();
    unawaited(_openNoteSheet(context, state, surah, ayah));
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
        AppTheme theme = themeService.currentTheme;

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
                                        mushafSettings
                                            .setScrollMode(ScrollMode.horizontal);
                                        setStateSheet(() => mode =
                                            ScrollMode.horizontal);
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
                                  'Theme',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: AppTheme.values.map((t) {
                                    final selected = t == theme;
                                    return _ThemeCardTile(
                                      theme: t,
                                      selected: selected,
                                      onTap: () {
                                        themeService.setTheme(t);
                                        setStateSheet(() => theme = t);
                                      },
                                    );
                                  }).toList(),
                                ),
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
                                        setStateSheet(() =>
                                            searchGesture = val);
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
                          backgroundColor: color.withOpacity(0.25),
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
    if (!mounted) return;
    _showBookmarkSnackbar(this.context, false);
  }

  Future<void> _openNoteSheet(
    BuildContext context,
    BookmarkNotesNotifier state,
    int surah,
    int verse,
  ) async {
    final existing = state.noteForVerse(surah, verse);
    final controller = TextEditingController(text: existing?.content ?? '');

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Note for $surah:$verse',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Write your reflection here',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () async {
                        await state.deleteNoteForVerse(surah, verse);
                        if (context.mounted) {
                          Navigator.pop(context, true);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await state.upsertNote(
                        surahId: surah,
                        ayahId: verse,
                        content: controller.text.trim(),
                      );
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved == true && mounted) {
      _showSnack('Note saved for $surah:$verse');
    }
  }

  Future<void> _shareVerseCard(int surah, int verse) async {
    final surahName = getSurahName(surah);
    final verseText = getVerseQCF(surah, verse, verseEndSymbol: true);
    try {
      final bytes = await _screenshotController.captureFromWidget(
        _VerseShareCard(
          surah: surah,
          verse: verse,
          surahName: surahName,
          verseText: verseText,
        ),
        pixelRatio: 2.5,
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ayah_${surah}_$verse.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Surah $surahName ($surah:$verse)',
      );
    } catch (e) {
      _showSnack('Could not share verse: $e');
    }
  }

  void _viewTafsir(BuildContext context, int surah, int verse) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerseDetailsScreen(
          surahNumber: surah,
          ayahNumber: verse,
        ),
      ),
    );
  }

  void _copyVerseText(int surah, int verse) {
    final text = getVerseQCF(surah, verse, verseEndSymbol: true);
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied Surah $surah:$verse');
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
        ? BrandColors.accent
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
            iconSize: 28,
            padding: const EdgeInsets.all(8),
            icon: Icon(icon, color: iconColor),
          ),
        ),
        if (label.isNotEmpty)
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}

class _NotesIcon extends StatelessWidget {
  final VoidCallback onTap;
  const _NotesIcon({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onTap,
              child: Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: BrandColors.accent,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _SettingOptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SettingOptionTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final border = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    return Expanded(
      child: Material(
        color: selected
            ? BrandColors.accent.withOpacity(0.12)
            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
        shape: border,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: BrandColors.accent),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_circle, color: BrandColors.accent, size: 18),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeCardTile extends StatelessWidget {
  final AppTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCardTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = ThemeService.getMainframeImagePath(theme);
    final name = ThemeService.getThemeName(theme);
    return SizedBox(
      width: 160,
      height: 84,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? BrandColors.accent
                    : Theme.of(context).dividerColor.withOpacity(0.4),
                width: selected ? 2 : 1,
              ),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                alignment: Alignment.center,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.06),
                  BlendMode.srcATop,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.9),
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.35),
                    Colors.transparent,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: BrandColors.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerseShareCard extends StatelessWidget {
  final int surah;
  final int verse;
  final String surahName;
  final String verseText;

  const _VerseShareCard({
    required this.surah,
    required this.verse,
    required this.surahName,
    required this.verseText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.dark();
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 1080,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$surahName — $surah:$verse',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                verseText,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.bedtime, color: Colors.white70, size: 18),
                SizedBox(width: 8),
                Text(
                  'Ayah App • Offline bookmark',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
