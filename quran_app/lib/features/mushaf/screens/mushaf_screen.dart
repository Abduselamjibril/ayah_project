import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import '../../settings/settings_screen.dart';
import '../controller/mushaf_controller.dart';
import '../widgets/horizontal_mushaf_view.dart';
import '../widgets/surah_drawer.dart';
import '../widgets/vertical_mushaf_view.dart';
import 'package:quran_app/data/repositories/search_repository.dart';
import 'package:quran_app/features/search/search_screen.dart';
import '../../daily_verse/verse_of_the_day_screen.dart';

class MushafScreen extends StatefulWidget {
  const MushafScreen({super.key});

  @override
  State<MushafScreen> createState() => _MushafScreenState();
}

class _MushafScreenState extends State<MushafScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final MushafController _controller = MushafController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _appBarVisible = true;
  bool _isSearchMode = false;
  final List<String> _suggestions = [];
  Timer? _suggestionDebounce;

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _suggestionDebounce?.cancel();
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
          if (_isSearchMode) _buildSuggestionOverlay(),
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          switchInCurve: Curves.easeInOut,
                          switchOutCurve: Curves.easeInOut,
                          child: _isSearchMode
                              ? Row(
                                  key: const ValueKey('search-mode'),
                                  children: [
                                    IconButton(
                                      icon:
                                          const Icon(Icons.arrow_back_rounded),
                                      tooltip: 'Back',
                                      onPressed: _exitSearchMode,
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        textInputAction: TextInputAction.search,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                        decoration: InputDecoration(
                                          hintText: 'Search verses or keywords',
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.5),
                                          ),
                                        ),
                                        onChanged: _onSearchChanged,
                                        onSubmitted: _onSearchSubmitted,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.tune_rounded),
                                      tooltip: 'Advanced search',
                                      onPressed: _openAdvancedSearch,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: 'Close search',
                                      onPressed: _exitSearchMode,
                                    ),
                                  ],
                                )
                              : Row(
                                  key: const ValueKey('default-mode'),
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.menu_rounded),
                                      tooltip: 'Surahs',
                                      onPressed: () => _scaffoldKey.currentState
                                          ?.openDrawer(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
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
                                      icon: const Icon(
                                          Icons.calendar_month_rounded),
                                      tooltip: 'Verse of the Day',
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
                                              result['surah']!,
                                              result['verse']!);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.search_rounded),
                                      tooltip: 'Search',
                                      onPressed: _enterSearchMode,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings_rounded),
                                      tooltip: 'Settings',
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
      ),
    );
  }

  Widget _buildMushafView(ScrollMode mode) {
    // Use Stack with Offstage to keep views alive but only render the visible one
    final isHorizontal = mode == ScrollMode.horizontal;
    return Stack(
      children: [
        Offstage(
          offstage: !isHorizontal,
          child: RepaintBoundary(
            child: HorizontalMushafView(
              controller: _controller,
              onOverlayVisibilityChanged: _onOverlayVisibilityChanged,
              onDragDown: _enterSearchModeFromGesture,
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

  void _enterSearchMode() {
    setState(() {
      _isSearchMode = true;
      _appBarVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _enterSearchModeFromGesture() {
    if (_controller.scrollMode != ScrollMode.horizontal) return;
    _enterSearchMode();
  }

  void _exitSearchMode() {
    setState(() {
      _isSearchMode = false;
      _suggestions.clear();
    });
    _searchFocusNode.unfocus();
  }

  void _onSearchSubmitted(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _exitSearchMode();
      return;
    }
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          query: trimmed,
          filters: const SearchFilters(),
        ),
      ),
    );
    if (result != null && result is Map<String, int> && mounted) {
      _controller.navigateToVerse(result['surah']!, result['verse']!);
    }
  }

  void _openAdvancedSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final queryController =
            TextEditingController(text: _searchController.text);
        final surahController = TextEditingController();
        final verseRangeController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Advanced Search',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: queryController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Keyword',
                  hintText: 'Type a word or phrase',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: surahController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Surah (optional)',
                  hintText: 'e.g. 1 - 114',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: verseRangeController,
                decoration: const InputDecoration(
                  labelText: 'Verse range (optional)',
                  hintText: 'e.g. 1-7',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.text = queryController.text;
                      Navigator.pop(context);
                      _onSearchSubmitted(queryController.text);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    _suggestionDebounce?.cancel();
    _suggestionDebounce = Timer(const Duration(milliseconds: 250), () async {
      final list = await SearchRepository.instance.suggestions(value);
      if (!mounted) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(list);
      });
    });
  }

  Widget _buildSuggestionOverlay() {
    if (_suggestions.isEmpty) return const SizedBox.shrink();
    return Positioned(
      top: MediaQuery.of(context).padding.top + kToolbarHeight + 12,
      left: 12,
      right: 12,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: ListView.separated(
            shrinkWrap: true,
            itemBuilder: (context, index) {
              final s = _suggestions[index];
              return ListTile(
                title: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  _searchController.text = s;
                  _onSearchSubmitted(s);
                },
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: _suggestions.length,
          ),
        ),
      ),
    );
  }
}
