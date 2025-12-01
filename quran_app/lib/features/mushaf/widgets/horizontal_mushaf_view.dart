// lib/features/mushaf/widgets/horizontal_mushaf_view.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../controller/mushaf_controller.dart';
import '../screens/verse_details_screen.dart';

class HorizontalMushafView extends StatelessWidget {
  final MushafController controller;

  const HorizontalMushafView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PageviewQuran(
          initialPageNumber: controller.currentPage,
          scrollMode: ScrollMode.horizontal,
          onPageChanged: (page) {
            controller.setPage(page);
          },
          textColor: Theme.of(context).colorScheme.onBackground,
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
        ),
        // Page indicator
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: ListenableBuilder(
            listenable: controller,
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
                      () => _navigateToPage(controller.currentPage - 1),
                      controller.currentPage > 1,
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
                        'Page ${controller.currentPage} of 604',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildNavigationButton(
                      context,
                      Icons.arrow_forward,
                      () => _navigateToPage(controller.currentPage + 1),
                      controller.currentPage < 604,
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

  void _navigateToPage(int page) {
    if (page >= 1 && page <= 604) {
      controller.setPage(page);
    }
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
    // Navigate to verse details screen
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
