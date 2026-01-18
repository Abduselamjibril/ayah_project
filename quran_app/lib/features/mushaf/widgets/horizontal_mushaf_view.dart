import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/services/audio_player_service.dart';
import '../../audio_player/audio_player_screen.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/share/presentation/dialogs/share_preview_dialog.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';
import 'play_range_dialog.dart';

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
    // Only repaint if necessary, but DO NOT force page jumps here.
    // Page jumps are handled exclusively by _navSubscription to avoid
    // race conditions where setHighlightedVerse() triggers a revert to an old page.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 8),
                _buildAudioPlayerCard(),
                const SizedBox(height: 4),
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
    widget.controller.navigateToPage(page);
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
                  icon: Icons.playlist_play,
                  title: 'Play to...',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPlayToDialog(rootContext, surah, verse);
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
    await showSharePreviewDialog(
      context: context,
      surahNumber: surah,
      ayahNumber: verse,
    );
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

  Future<void> _showPlayToDialog(
      BuildContext context, int startSurah, int startVerse) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlayRangeDialog(
        startSurah: startSurah,
        startVerse: startVerse,
      ),
    );
  }

  void _copyVerseText(int surah, int verse) {
    final text = getVerseQCF(surah, verse, verseEndSymbol: true);
    Clipboard.setData(ClipboardData(text: text));
    _showSnack('Copied Surah $surah:$verse');
  }
}
