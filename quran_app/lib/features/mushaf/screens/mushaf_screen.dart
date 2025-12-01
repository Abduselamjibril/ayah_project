// features/mushaf/screens/mushaf_screen.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../settings/settings_screen.dart';
import '../controller/mushaf_controller.dart';
import '../widgets/horizontal_mushaf_view.dart';
import '../widgets/surah_drawer.dart';
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
        actions: [
          // Scroll mode toggle
          IconButton(
            icon: Icon(
              _controller.scrollMode == ScrollMode.horizontal
                  ? Icons.view_day
                  : Icons.view_stream,
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
          // Settings icon
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: SurahDrawer(
        onSurahSelected: _jumpToSurah,
        controller: _controller,
      ),
      body: _controller.scrollMode == ScrollMode.horizontal
          ? HorizontalMushafView(controller: _controller)
          : VerticalMushafView(
              controller: _controller,
              scrollController: _scrollController,
            ),
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

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
