// features/mushaf/widgets/vertical_mushaf_view.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../controller/mushaf_controller.dart';

class VerticalMushafView extends StatelessWidget {
  final MushafController controller;
  final ScrollController scrollController;

  const VerticalMushafView({
    super.key,
    required this.controller,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return PageviewQuran(
      initialPageNumber: controller.currentPage,
      scrollMode: ScrollMode.vertical,
      onPageChanged: (page) {
        controller.setPage(page);
      },
      textColor: Theme.of(context).colorScheme.onSurface,
      pageBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      verseBackgroundColor: (surah, verse) {
        // Highlight bookmarked verses
        if (controller.isBookmarked(surah, verse)) {
          return Colors.yellow.withOpacity(0.3);
        }
        // Highlight selected verse
        if (controller.highlightedSurah == surah &&
            controller.highlightedVerse == verse) {
          return Colors.blue.withOpacity(0.2);
        }
        return null;
      },
      onLongPress: (surah, verse) {
        _showVerseOptions(context, surah, verse);
      },
      onLongPressDown: (surah, verse, details) {
        controller.setHighlightedVerse(surah, verse);
      },
      onLongPressCancel: (surah, verse) {
        controller.clearHighlight();
      },
      sp: 1.0,
      h: 1.0,
    );
  }

  void _showVerseOptions(BuildContext context, int surah, int verse) {
    final isBookmarked = controller.isBookmarked(surah, verse);

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
                  controller.toggleBookmark(surah, verse);
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
                  _viewTafsir(surah, verse);
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
    // Implement audio playback
    print('Playing audio for Surah $surah, Verse $verse');
  }

  void _viewTafsir(int surah, int verse) {
    // Implement tafsir navigation
    print('Viewing tafsir for Surah $surah, Verse $verse');
  }

  void _shareVerse(int surah, int verse) {
    // Implement share functionality
    print('Sharing Surah $surah, Verse $verse');
  }

  void _copyVerseText(int surah, int verse) {
    // Implement copy to clipboard
    print('Copying text for Surah $surah, Verse $verse');
  }
}
