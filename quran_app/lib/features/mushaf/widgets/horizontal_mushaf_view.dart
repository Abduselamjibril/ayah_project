import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/qcf_quran.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';

class HorizontalMushafView extends StatefulWidget {
  final MushafController controller;
  final ValueChanged<bool>? onOverlayVisibilityChanged;

  const HorizontalMushafView({
    super.key,
    required this.controller,
    this.onOverlayVisibilityChanged,
  });

  @override
  State<HorizontalMushafView> createState() => _HorizontalMushafViewState();
}

class _HorizontalMushafViewState extends State<HorizontalMushafView> {
  late PageController _pageController;
  double? _sliderValue;
  bool _isPlaying = false;
  String _audioName = 'Select audio';
  final Map<int, String> _surahNameCache = {};
  bool _overlayVisible = true;
  Timer? _autoHideTimer;

  @override
  void initState() {
    super.initState();
    _pageController =
        PageController(initialPage: widget.controller.currentPage - 1);
    _sliderValue = widget.controller.currentPage.toDouble();
    widget.controller.addListener(_onControllerChanged);
    _scheduleAutoHide();
    widget.onOverlayVisibilityChanged?.call(true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    _autoHideTimer?.cancel();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!_pageController.hasClients) return;

    final targetPage = widget.controller.currentPage - 1;
    if (_pageController.page?.round() != targetPage) {
      // Release slider to follow controller updates
      _sliderValue = null;
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _toggleOverlay,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = min(constraints.maxWidth, 900.0);
              final topMargin =
                  MediaQuery.of(context).padding.top + kToolbarHeight + 8;
              return Center(
                child: Padding(
                  padding: EdgeInsets.only(top: topMargin),
                  child: SizedBox(
                    width: maxWidth,
                    height: constraints.maxHeight - topMargin,
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: PageviewQuran(
                        controller: _pageController,
                        initialPageNumber: widget.controller.currentPage,
                        scrollMode: ScrollMode.horizontal,
                        onPageChanged: widget.controller.setPage,
                        textColor: Theme.of(context).colorScheme.onSurface,
                        pageBackgroundColor:
                            Theme.of(context).scaffoldBackgroundColor,
                        verseBackgroundColor: _getVerseBackgroundColor,
                        onLongPress: (surah, verse) =>
                            _showVerseOptions(context, surah, verse),
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

  Color? _getVerseBackgroundColor(int surah, int verse) {
    if (widget.controller.isBookmarked(surah, verse)) {
      return Colors.yellow.withOpacity(0.3);
    }
    if (widget.controller.highlightedSurah == surah &&
        widget.controller.highlightedVerse == verse) {
      return Colors.blue.withOpacity(0.2);
    }
    return null;
  }

  Widget _buildPageOverlay() {
    if (!_overlayVisible) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, child) {
          final currentDouble =
              (_sliderValue ?? widget.controller.currentPage.toDouble())
                  .clamp(1.0, 604.0);
          final currentPage = currentDouble.round();
          final surahName = _surahNameForPage(currentPage);
          final isSliding = _sliderValue != null;

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
                              .withOpacity(0.95),
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
                  color:
                      Theme.of(context).colorScheme.surface.withOpacity(0.95),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Directionality(
                      textDirection: TextDirection.rtl,
                      child: Slider(
                        min: 1,
                        max: 604,
                        divisions: 603,
                        value: currentDouble,
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
    return Card(
      elevation: 12,
      color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayPause,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _audioName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _openAudioPicker,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    // TODO: integrate with real audio playback
    _showOverlay();
  }

  void _openAudioPicker() {
    // TODO: navigate to audio selection screen in future
    debugPrint('Open audio picker');
    _showOverlay();
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
    if (page >= 1 && page <= 604) {
      widget.controller.setPage(page);
    }
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

  void _showVerseOptions(BuildContext context, int surah, int verse) {
    final isBookmarked = widget.controller.isBookmarked(surah, verse);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOptionTile(
              icon: isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
              title: isBookmarked ? 'Remove Bookmark' : 'Bookmark Verse',
              onTap: () {
                widget.controller.toggleBookmark(surah, verse);
                Navigator.pop(context);
                _showBookmarkSnackbar(context, isBookmarked);
              },
            ),
            _buildOptionTile(
              icon: Icons.volume_up,
              title: 'Play Audio',
              onTap: () {
                Navigator.pop(context);
                _playAudio(surah, verse);
              },
            ),
            _buildOptionTile(
              icon: Icons.menu_book,
              title: 'View Tafsir',
              onTap: () {
                Navigator.pop(context);
                _viewTafsir(context, surah, verse);
              },
            ),
            _buildOptionTile(
              icon: Icons.share,
              title: 'Share Verse',
              onTap: () {
                Navigator.pop(context);
                _shareVerse(surah, verse);
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

  void _playAudio(int surah, int verse) {
    // TODO: Implement audio playback
    print('Playing audio for Surah $surah, Verse $verse');
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

  void _shareVerse(int surah, int verse) {
    // TODO: Implement share functionality
    print('Sharing Surah $surah, Verse $verse');
  }
}
