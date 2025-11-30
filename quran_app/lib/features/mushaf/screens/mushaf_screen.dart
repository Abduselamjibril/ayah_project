// features/mushaf/screens/mushaf_screen.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../controller/mushaf_controller.dart';
import '../widgets/horizontal_mushaf_view.dart';
import '../widgets/vertical_mushaf_view.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final MushafController _controller = MushafController();
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Al-Quran'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          // Scroll mode toggle
          IconButton(
            icon: Icon(
              _controller.scrollMode == ScrollMode.horizontal
                  ? Icons.view_day
                  : Icons.view_stream,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _controller.toggleScrollMode();
              });
            },
            tooltip: _controller.scrollMode == ScrollMode.horizontal
                ? 'Switch to Continuous Scroll'
                : 'Switch to Page View',
          ),
          // Bookmark indicator
          ListenableBuilder(
            listenable: _controller,
            builder: (context, child) {
              final bookmarkCount = _controller.bookmarkedVerses.length;
              return Badge(
                isLabelVisible: bookmarkCount > 0,
                label: Text(bookmarkCount.toString()),
                child: IconButton(
                  icon: const Icon(Icons.bookmark),
                  onPressed: bookmarkCount > 0 ? _showBookmarks : null,
                  tooltip: 'Bookmarks ($bookmarkCount)',
                ),
              );
            },
          ),
          // Jump to surah menu
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu_book),
            tooltip: 'Jump to Surah',
            onSelected: (surah) {
              _jumpToSurah(surah);
            },
            itemBuilder: (context) {
              return List.generate(114, (index) {
                final surahNumber = index + 1;
                return PopupMenuItem(
                  value: surahNumber,
                  child: Text('Surah $surahNumber'),
                );
              });
            },
          ),
        ],
      ),
      body: _controller.scrollMode == ScrollMode.horizontal
          ? HorizontalMushafView(controller: _controller)
          : VerticalMushafView(
              controller: _controller,
              scrollController: _scrollController,
            ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_controller.scrollMode == ScrollMode.vertical) {
      return FloatingActionButton(
        onPressed: _scrollToTop,
        tooltip: 'Scroll to Top',
        child: const Icon(Icons.arrow_upward),
      );
    }
    return null;
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToSurah(int surah) {
    _controller.setSurah(surah);
    if (_controller.scrollMode == ScrollMode.vertical) {
      // In a real implementation, you'd calculate the scroll position
      // based on the surah index and verse count
      _scrollController.animateTo(
        (surah - 1) * 200.0, // Approximate position
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      // For horizontal mode, find the page containing the first verse of the surah
      // This would require additional logic to map surah to page
      _controller.setPage(1); // Placeholder
    }
  }

  void _showBookmarks() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bookmarked Verses'),
        content: _controller.bookmarkedVerses.isEmpty
            ? const Text('No bookmarked verses')
            : ListView(
                shrinkWrap: true,
                children: _controller.bookmarkedVerses.map((verseKey) {
                  final parts = verseKey.split(':');
                  final surah = int.parse(parts[0]);
                  final verse = int.parse(parts[1]);
                  return ListTile(
                    title: Text('Surah $surah, Verse $verse'),
                    onTap: () {
                      Navigator.pop(context);
                      _jumpToVerse(surah, verse);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.bookmark_remove),
                      onPressed: () {
                        _controller.toggleBookmark(surah, verse);
                      },
                    ),
                  );
                }).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _jumpToVerse(int surah, int verse) {
    _controller.setSurah(surah);
    // Implementation would depend on your navigation logic
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
