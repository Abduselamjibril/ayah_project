import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/qcf_quran.dart';
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
  double? _sliderValue;

  @override
  void initState() {
    super.initState();
    _lastPage = widget.controller.currentPage;
    _sliderValue = _lastPage.toDouble();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (widget.controller.currentPage != _lastPage) {
      _lastPage = widget.controller.currentPage;
      // Release slider to follow controller updates
      _sliderValue = null;
      final viewportHeight = MediaQuery.of(context).size.height;
      final offset = (_lastPage - 1) * viewportHeight;
      widget.scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageviewQuran(
          initialPageNumber: widget.controller.currentPage,
          scrollMode: ScrollMode.vertical,
          verticalScrollController: widget.scrollController,
          onPageChanged: (page) {
            _lastPage = page;
            widget.controller.setPage(page);
          },
          textColor: Theme.of(context).colorScheme.onSurface,
          pageBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
          verseBackgroundColor: _getVerseBackgroundColor,
          onLongPress: (surah, verse) =>
              _showVerseOptions(context, surah, verse),
          onLongPressStart: (surah, verse, details) =>
              widget.controller.setHighlightedVerse(surah, verse),
          onLongPressCancel: (surah, verse) =>
              widget.controller.clearHighlight(),
          sp: 1.0,
          h: 1.0,
        ),
        _buildPageIndicator(),
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

  Widget _buildPageIndicator() {
    return Positioned(
      bottom: 16,
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
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  surahName,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Page ${currentPage.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Slider(
                  min: 1,
                  max: 604,
                  divisions: 603,
                  value: currentDouble,
                  onChanged: (value) {
                    setState(() {
                      _sliderValue = value;
                    });
                  },
                  onChangeEnd: (value) {
                    final page = value.round();
                    setState(() {
                      _sliderValue = null;
                    });
                    _scrollToPage(page);
                    widget.controller.setPage(page);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _surahNameForPage(int page) {
    try {
      final pd = getPageData(page);
      if (pd.isEmpty) return '';
      final first = pd[0];
      final surahNum = int.parse(first['surah'].toString());
      return getSurahName(surahNum);
    } catch (e) {
      return '';
    }
  }

  void _scrollToPage(int page) {
    if (page < 1 || page > 604) return;

    final viewportHeight = MediaQuery.of(context).size.height;
    final offset = (page - 1) * viewportHeight;
    widget.scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Navigation buttons and page number removed in favor of slider

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

  void _copyVerseText(int surah, int verse) {
    // TODO: Implement copy to clipboard
    print('Copying text for Surah $surah, Verse $verse');
  }
}
