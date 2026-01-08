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

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MushafController _controller = MushafController();

  bool _appBarVisible = true;

  @override
  void dispose() {
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
          ValueListenableBuilder<ScrollMode>(
            valueListenable: _controller.scrollModeListenable,
            builder: (context, mode, _) => _buildMushafView(mode),
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
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: SizedBox(
                        height: kToolbarHeight,
                        child: Row(
                          key: const ValueKey('default-mode'),
                          children: [
                            IconButton(
                              icon: const Icon(Icons.menu_rounded),
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('surahs_tooltip') ??
                                  'Surahs',
                              onPressed: () =>
                                  _scaffoldKey.currentState?.openDrawer(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)
                                      ?.translate('app_title') ??
                                  'Al-Quran',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.search_rounded),
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('search_tooltip') ??
                                  'Search',
                              onPressed: () => _openSearch(context),
                            ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month_rounded),
                              tooltip: AppLocalizations.of(context)
                                      ?.translate('verse_of_the_day_tooltip') ??
                                  'Verse of the Day',
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const VerseOfTheDayScreen()),
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
    // Use Stack with Offstage to keep views alive but only render the visible one
    final isHorizontal = mode == ScrollMode.horizontal;
    // The following lines were part of the instruction but appear to be
    // misplaced from a SearchRepository context.
    // final res = deduped.take(limit).toList();
    // _setSuggestCache(cacheKey, res);
    // return res;
    return Stack(
      children: [
        Offstage(
          offstage: !isHorizontal,
          child: RepaintBoundary(
            child: HorizontalMushafView(
              controller: _controller,
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
