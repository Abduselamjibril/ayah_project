// features/mushaf/widgets/vertical_mushaf_view.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/data/page_data.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';

class VerticalMushafView extends StatefulWidget {
  final MushafController controller;
  final ScrollController scrollController;

  const VerticalMushafView({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  @override
  State<VerticalMushafView> createState() => _VerticalMushafViewState();
}

class _VerticalMushafViewState extends State<VerticalMushafView> {
  int _lastPage = 1;
  bool _isScrollingToTarget = false;
  bool _isUpdatingFromScroll = false;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.controller.currentPage;
    widget.controller.addListener(_onControllerChanged);
    widget.scrollController.addListener(_onScroll);

    // Scroll to initial page after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToPage(_lastPage);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onControllerChanged() {
    // If the update came from our own scroll listener, don't scroll back!
    if (_isUpdatingFromScroll) return;

    // When controller page changes (e.g. from drawer or button), scroll to that page
    if (widget.controller.currentPage != _lastPage) {
      _lastPage = widget.controller.currentPage;
      _scrollToPage(_lastPage);
    }
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;

    // Calculate current page based on scroll offset
    // Pages are now exactly screen height
    final double pageHeight = MediaQuery.of(context).size.height;
    final double offset = widget.scrollController.offset;

    int pageIndex = (offset / pageHeight).round();
    int currentPage = pageIndex + 1;

    if (currentPage < 1) currentPage = 1;
    if (currentPage > 604) currentPage = 604;

    if (currentPage != _lastPage) {
      _lastPage = currentPage;

      // Set flag to prevent _onControllerChanged from triggering a scroll
      _isUpdatingFromScroll = true;
      widget.controller.setPage(currentPage);
      _isUpdatingFromScroll = false;
    }
  }

  void _scrollToPage(int pageNumber) {
    if (!widget.scrollController.hasClients || _isScrollingToTarget) return;

    _isScrollingToTarget = true;

    // Pages are exactly screen height, so calculation is precise
    final double pageHeight = MediaQuery.of(context).size.height;
    final double targetPosition = (pageNumber - 1) * pageHeight;

    widget.scrollController
        .animateTo(
      targetPosition.clamp(
          0.0, widget.scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      _isScrollingToTarget = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageviewQuran(
          key: ValueKey('vertical_${widget.controller.currentPage}'),
          initialPageNumber: widget.controller.currentPage,
          scrollMode: ScrollMode.vertical,
          verticalController: widget.scrollController,
          onPageChanged: (page) {
            _lastPage = page;
            widget.controller.setPage(page);
          },
          textColor: Theme.of(context).colorScheme.onSurface,
          pageBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
          verseBackgroundColor: (surah, verse) {
            if (widget.controller.isBookmarked(surah, verse)) {
              return Colors.yellow.withOpacity(0.3);
            }
            if (widget.controller.highlightedSurah == surah &&
                widget.controller.highlightedVerse == verse) {
              return Colors.blue.withOpacity(0.2);
            }
            return null;
          },
          onLongPress: (surah, verse) {
            _showVerseOptions(context, surah, verse);
          },
          onLongPressDown: (surah, verse, details) {
            widget.controller.setHighlightedVerse(surah, verse);
          },
          onLongPressCancel: (surah, verse) {
            widget.controller.clearHighlight();
          },
          sp: 1.0,
          h: 1.0,
        ),
        // Page indicator for vertical mode
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, child) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavigationButton(
                      context,
                      Icons.arrow_back,
                      () => _scrollToPage(widget.controller.currentPage - 1),
                      widget.controller.currentPage > 1,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Page ${widget.controller.currentPage} of 604',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildNavigationButton(
                      context,
                      Icons.arrow_forward,
                      () => _scrollToPage(widget.controller.currentPage + 1),
                      widget.controller.currentPage < 604,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButton(BuildContext context, IconData icon,
      VoidCallback onPressed, bool enabled) {
    return IconButton(
      icon: Icon(icon, color: Theme.of(context).colorScheme.onPrimary),
      onPressed: enabled ? onPressed : null,
      style: IconButton.styleFrom(
        backgroundColor: enabled ? Theme.of(context).primaryColor : Colors.grey,
        shape: const CircleBorder(),
      ),
    );
  }

  void _showVerseOptions(BuildContext context, int surah, int verse) {
    final isBookmarked = widget.controller.isBookmarked(surah, verse);

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                    isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add),
                title:
                    Text(isBookmarked ? 'Remove Bookmark' : 'Bookmark Verse'),
                onTap: () {
                  widget.controller.toggleBookmark(surah, verse);
                  Navigator.pop(context);
                  _showBookmarkSnackbar(context, isBookmarked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('Play Audio'),
                onTap: () {
                  Navigator.pop(context);
                  _playAudio(surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: const Text('View Tafsir'),
                onTap: () {
                  Navigator.pop(context);
                  _viewTafsir(context, surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Share Verse'),
                onTap: () {
                  Navigator.pop(context);
                  _shareVerse(surah, verse);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Verse Text'),
                onTap: () {
                  Navigator.pop(context);
                  _copyVerseText(surah, verse);
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBookmarkSnackbar(BuildContext context, bool wasBookmarked) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBookmarked ? 'Bookmark removed' : 'Verse bookmarked',
        ),
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

  void _copyVerseText(int surah, int verse) {
    // TODO: Implement copy to clipboard
    print('Copying text for Surah $surah, Verse $verse');
  }
}
