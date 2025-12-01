// features/mushaf/screens/mushaf_screen.dart
import 'package:flutter/material.dart';
import '../../../core/quran/widgets/quran_pageview.dart';
import '../../../core/quran/data/page_data.dart';
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
  void initState() {
    super.initState();
  }

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

    // Get the page number for the first verse of the selected Surah
    final pageNumber = getPageNumber(surah, 1);

    // Set the page in the controller
    _controller.setPage(pageNumber);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }
}
