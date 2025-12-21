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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      key: _scaffoldKey,
      drawer: SurahDrawer(
        onSurahSelected: _jumpToSurah,
        controller: _controller,
      ),
      body: Stack(
        children: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _buildMushafView(),
          ),
          _buildFloatingAppBar(context),
        ],
      ),
    );
  }

  Widget _buildFloatingAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_appBarVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          opacity: _appBarVisible ? 1 : 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                child: SizedBox(
                  height: kToolbarHeight,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu),
                        tooltip: 'Surahs',
                        onPressed: () =>
                            _scaffoldKey.currentState?.openDrawer(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Al-Quran',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.settings),
                        tooltip: 'Settings',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const SettingsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
