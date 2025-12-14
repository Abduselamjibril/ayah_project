import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
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
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: SurahDrawer(
        onSurahSelected: _jumpToSurah,
        controller: _controller,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _buildMushafView(),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Al-Quran'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _buildMushafView() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return HorizontalMushafView(controller: _controller);
    }

    return _controller.scrollMode == ScrollMode.horizontal
        ? HorizontalMushafView(controller: _controller)
        : VerticalMushafView(
            controller: _controller,
            scrollController: _scrollController,
          );
  }

  void _jumpToSurah(int surah) {
    _controller.setSurah(surah);
    final pageNumber = getPageNumber(surah, 1);
    _controller.setPage(pageNumber);
  }
}
