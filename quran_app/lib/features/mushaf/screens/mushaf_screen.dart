import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../../settings/settings_screen.dart';
import '../controller/mushaf_controller.dart';
import '../widgets/horizontal_mushaf_view.dart';
import '../widgets/vertical_mushaf_view.dart';
import '../../search/search_screen.dart';
import 'package:quran_app/features/mushaf/widgets/surah_drawer.dart';
import '../../daily_verse/verse_of_the_day_screen.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/core/ui/snackbar_utils.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MushafController _controller = MushafController();

  bool _appBarVisible = true;
  DateTime? _lastBackPress;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: Scaffold(
        key: _scaffoldKey,
        drawer: SurahDrawer(
          onSurahSelected: _jumpToSurah,
          controller: _controller,
        ),
        body: Stack(
          children: [
            ValueListenableBuilder<ScrollMode>(
              valueListenable: _controller.scrollModeListenable,
              builder: (context, mode, _) => _buildMushafView(mode),
            ),
            _buildFloatingAppBar(context),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleBackPress() async {
    final scaffoldState = _scaffoldKey.currentState;
    if (scaffoldState?.isDrawerOpen == true) {
      Navigator.of(context).pop();
      return false;
    }

    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) <= const Duration(seconds: 2)) {
      return true;
    }
    _lastBackPress = now;

    final message =
        AppLocalizations.of(context)?.translate('press_back_again_to_exit') ??
            'Press back again to exit';
    showAppSnack(context, message, type: AppSnackType.info);
    return false;
  }

  Widget _buildFloatingAppBar(BuildContext context) {
    final iconSize = ResponsiveLayout.scaled(context, 26, min: 24, max: 32);
    final gap = ResponsiveLayout.scaled(context, 8, min: 6, max: 12);
    final barHeight =
        ResponsiveLayout.scaled(context, kToolbarHeight, min: 52, max: 64);
    final verticalPad = ResponsiveLayout.scaled(context, 2, min: 1, max: 4);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_appBarVisible,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          opacity: _appBarVisible ? 1 : 0,
          child: AnimatedScale(
            scale: _appBarVisible ? 1.0 : 0.95,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(0),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: verticalPad),
                      child: SizedBox(
                        height: barHeight,
                        child: Row(
                          key: const ValueKey('default-mode'),
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              color: BrandColors.accent,
                              iconSize: iconSize,
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('surahs_tooltip') ??
                                  'Surahs',
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                            SizedBox(width: gap),
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              color: BrandColors.accent,
                              iconSize: iconSize,
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('search_tooltip') ??
                                  'Search',
                              onPressed: () => _openSearch(context),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.calendar_month_rounded),
                              color: BrandColors.accent,
                              iconSize: iconSize,
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('verse_of_the_day_tooltip') ??
                                  'Verse of the Day',
                              onPressed: () async {
                                final result = await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder: (ctx) => const VerseOfTheDayScreen(),
                                );
                                if (result != null &&
                                    result is Map<String, int> &&
                                    mounted) {
                                  _controller.navigateToVerse(
                                      result['surah']!, result['verse']!);
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.settings_rounded),
                              color: BrandColors.accent,
                              iconSize: iconSize,
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('settings_tooltip') ??
                                  'Settings',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const SettingsScreen()),
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
          ),
        ),
      ),
    );
  }

  Future<void> _openSearch(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SearchScreen(query: ''),
      ),
    );

    if (result != null && result is Map<String, int> && mounted) {
      _controller.navigateToVerse(result['surah']!, result['ayah']!);
    }
  }

  Widget _buildMushafView(ScrollMode mode) {
    final isHorizontal = mode == ScrollMode.horizontal;
    return Stack(
      children: [
        Offstage(
          offstage: !isHorizontal,
          child: RepaintBoundary(
            child: HorizontalMushafView(
              controller: _controller,
              isVisible: isHorizontal,
              onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
              onDragDown: () async {
                final prefs = await SharedPreferences.getInstance();
                final enabled =
                    prefs.getBool('search_gesture_enabled') ?? false;
                if (enabled && mounted) {
                  await _openSearch(context);
                }
              },
            ),
          ),
        ),
        Offstage(
          offstage: isHorizontal,
          child: RepaintBoundary(
            child: VerticalMushafView(
              controller: _controller,
              isVisible: !isHorizontal,
              onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
            ),
          ),
        ),
      ],
    );
  }

  void _jumpToSurah(int surah) {
    _controller.navigateToSurah(surah);
  }

  void _onOverlayVisibilityChanged(bool visible) {
    if (_appBarVisible == visible) return;
    setState(() {
      _appBarVisible = visible;
    });
  }
}
