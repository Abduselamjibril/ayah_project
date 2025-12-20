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
  bool _appBarVisible = true;

  @override
  void dispose() {
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAnimatedAppBar(context),
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

  PreferredSizeWidget _buildAnimatedAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRect(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          height: _appBarVisible ? kToolbarHeight : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _appBarVisible ? 1 : 0,
            child: _buildAppBar(context),
          ),
        ),
      ),
    );
  }

  Widget _buildMushafView() {
    return _controller.scrollMode == ScrollMode.horizontal
        ? HorizontalMushafView(
            controller: _controller,
            onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
          )
        : VerticalMushafView(
            controller: _controller,
            scrollController: _scrollController,
            onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
          );
  }

  void _jumpToSurah(int surah) {
    _controller.setSurah(surah);
    final pageNumber = getPageNumber(surah, 1);
    _controller.setPage(pageNumber);
  }

  void _onOverlayVisibilityChanged(bool visible) {
    if (_appBarVisible == visible) return;
    setState(() {
      _appBarVisible = visible;
    });
  }
}
