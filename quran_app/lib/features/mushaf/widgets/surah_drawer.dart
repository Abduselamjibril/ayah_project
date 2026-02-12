import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/bookmarks/data/models/note.dart';
import 'package:quran_app/features/bookmarks/data/models/bookmark.dart';
import 'package:quran_app/features/highlights/state/highlight_notifier.dart';
import 'package:quran_app/features/highlights/data/models/highlight.dart';
import '../controller/mushaf_controller.dart';
import '../../../core/quran/data/suwar.dart';
import '../../../core/quran/data/juzs.dart';
import '../../khatmah/widgets/khatmah_tab.dart';
import '../../../core/quran/qcf_quran.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/utils/localization_helper.dart';

enum NavigationMode { surah, juz }

// Helper class for surah list entries
class _SurahListEntry {
  final bool isHeader;
  final int juzNumber;
  final Map<String, dynamic>? surahInfo;

  _SurahListEntry.header(this.juzNumber)
      : isHeader = true,
        surahInfo = null;

  _SurahListEntry.surah(this.juzNumber, this.surahInfo) : isHeader = false;
}

// Permanent app bar for all tabs
class PermanentAppBar extends StatelessWidget {
  final int selectedTabIndex;
  final NavigationMode navigationMode;
  final ValueChanged<NavigationMode> onNavigationModeChanged;
  final bool isEditingBookmarks;
  final VoidCallback? onEditBookmarks;
  final int highlightsMode;
  final ValueChanged<int>? onHighlightsModeChanged;

  const PermanentAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.navigationMode,
    required this.onNavigationModeChanged,
    this.isEditingBookmarks = false,
    this.onEditBookmarks,
    this.highlightsMode = 0,
    this.onHighlightsModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final background =
        isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor;
    final double topInset = MediaQuery.of(context).viewPadding.top;
    final double topPadding = topInset > 0 ? topInset + 8 : 32;
    return Container(
      padding:
          EdgeInsets.only(top: topPadding, left: 16, right: 16, bottom: 12),
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 80 (edit) + 38 (back) + 16*2 (padding) = 150, so available for toggle is constraints.maxWidth - 80 - 38
          const double toggleWidth = 195;
          final double leftSpace = constraints.maxWidth - 80 - 38 - toggleWidth;
          // Move the toggle a bit to the left of center (e.g., 24px)
          const double leftShift = 24;
          double leftPad = leftSpace > 0 ? (leftSpace / 2) - leftShift : 0;
          double rightPad = leftSpace > 0 ? (leftSpace / 2) + leftShift : 0;
          if (leftPad < 0) leftPad = 0;
          if (rightPad < 0) rightPad = 0;
          return Row(
            children: [
              // Left: Edit button space
              SizedBox(
                width: 80,
                child: const SizedBox.shrink(),
              ),
              // Center: Surah/Juz toggle or Highlights pills
              if (selectedTabIndex == 0)
                Padding(
                  padding: EdgeInsets.only(left: leftPad, right: rightPad),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < toggleWidth + 24) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: toggleWidth),
                            child: SizedBox(
                              width: toggleWidth,
                              child: _SurahJuzToggle(
                                navigationMode: navigationMode,
                                onChanged: onNavigationModeChanged,
                              ),
                            ),
                          ),
                        );
                      } else {
                        return SizedBox(
                          width: toggleWidth,
                          child: _SurahJuzToggle(
                            navigationMode: navigationMode,
                            onChanged: onNavigationModeChanged,
                          ),
                        );
                      }
                    },
                  ),
                )
              else if (selectedTabIndex == 3)
                Padding(
                  padding: EdgeInsets.only(left: leftPad, right: rightPad),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // If not enough space, allow horizontal scroll
                      if (constraints.maxWidth < toggleWidth + 24) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: toggleWidth),
                            child: Container(
                              width: toggleWidth,
                              height: 34,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.light
                                    ? const Color(0xFFE3E3E3)
                                    : const Color(0xFF2C2C2E),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: _ToggleButton(
                                      label: AppLocalizations.of(context)
                                              ?.translate('tab_contents') ??
                                          'Sūrahs',
                                      isSelected: highlightsMode == 0,
                                      onTap: () => onHighlightsModeChanged?.call(0),
                                    ),
                                  ),
                                  Expanded(
                                    child: _ToggleButton(
                                      label: AppLocalizations.of(context)
                                              ?.translate('colors') ??
                                          'Colors',
                                      isSelected: highlightsMode == 1,
                                      onTap: () => onHighlightsModeChanged?.call(1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      } else {
                        return SizedBox(
                          width: toggleWidth,
                          child: Container(
                            height: 34,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xFFE3E3E3)
                                  : const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: _ToggleButton(
                                    label: AppLocalizations.of(context)
                                            ?.translate('tab_contents') ??
                                        'Sūrahs',
                                    isSelected: highlightsMode == 0,
                                    onTap: () => onHighlightsModeChanged?.call(0),
                                  ),
                                ),
                                Expanded(
                                  child: _ToggleButton(
                                    label: AppLocalizations.of(context)
                                            ?.translate('colors') ??
                                        'Colors',
                                    isSelected: highlightsMode == 1,
                                    onTap: () => onHighlightsModeChanged?.call(1),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                  ),
                )
              else
                const SizedBox.shrink(),
              // Fill remaining space (toggle or spacer)
              if (selectedTabIndex == 0)
                const SizedBox.shrink()
              else
                Expanded(child: Container()),
              // Right: Back button
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right, size: 28),
                  color: BrandColors.accent,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SurahJuzToggle extends StatelessWidget {
  final NavigationMode navigationMode;
  final ValueChanged<NavigationMode> onChanged;
  const _SurahJuzToggle(
      {required this.navigationMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final trackColor =
        isLight ? const Color(0xFFE3E3E3) : const Color(0xFF2C2C2E);
    return SizedBox(
      width: 180,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: _ToggleButton(
                label:
                    AppLocalizations.of(context)?.translate('toggle_surahs') ??
                        'Sūrahs',
                isSelected: navigationMode == NavigationMode.surah,
                onTap: () => onChanged(NavigationMode.surah),
              ),
            ),
            Expanded(
              child: _ToggleButton(
                label: AppLocalizations.of(context)?.translate('toggle_juz') ??
                    'Quarters',
                isSelected: navigationMode == NavigationMode.juz,
                onTap: () => onChanged(NavigationMode.juz),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final selectedBg = isLight ? Colors.white : const Color(0xFF5A5A5D);
    final selectedText = isLight ? const Color(0xFF111111) : Colors.white;
    final unselectedText =
        isLight ? const Color(0xFF7A7A7A) : const Color(0xFFC8C8CC);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? selectedText : unselectedText,
          ),
        ),
      ),
    );
  }
}

class SurahDrawer extends StatefulWidget {
  final Function(int) onSurahSelected;
  final MushafController controller;

  const SurahDrawer({
    super.key,
    required this.onSurahSelected,
    required this.controller,
  });

  @override
  State<SurahDrawer> createState() => _SurahDrawerState();
}

class _SurahDrawerState extends State<SurahDrawer>
    with SingleTickerProviderStateMixin {
  int _selectedTabIndex = 0;
  String? _selectedBookmarkColor;
  final TextEditingController _noteSearchController = TextEditingController();
  List<NoteModel> _noteResults = [];
  bool _isSearchingNotes = false;
  NavigationMode _navigationMode = NavigationMode.surah;
  final Map<String, String> _verseTextCache = {};
  bool _isEditingBookmarks = false;
  bool _isEditingNotes = false;
  int _highlightsMode = 0; // 0: Surahs, 1: Colors
  final Set<int> _collapsedHighlightSurahs = {};
  final Set<String> _collapsedHighlightColors = {};

  final ScrollController _drawerScrollController = ScrollController();
  final Map<int, GlobalKey> _juzHeaderKeys = {};
  final Map<int, GlobalKey> _juzItemKeys = {};
  Timer? _overlayTimer;
  int? _centerOverlayNumber;

  final Map<String, TextEditingController> _categoryEditControllers = {};
  final Map<String, bool> _expandedCategories = {};

  static const List<Map<String, String>> _bookmarkColorCategories = [
    {'name': 'Red', 'hex': '#EF5350'},
    {'name': 'Yellow', 'hex': '#FFB300'},
    {'name': 'Green', 'hex': '#66BB6A'},
    {'name': 'Blue', 'hex': '#42A5F5'},
  ];

  static const Map<int, int> _surahStartPages = {
    1: 1,
    2: 2,
    3: 50,
    4: 77,
    5: 106,
    6: 128,
    7: 151,
    8: 177,
    9: 187,
    10: 208
  };

  @override
  void dispose() {
    _overlayTimer?.cancel();
    for (var controller in _categoryEditControllers.values) {
      controller.dispose();
    }
    _noteSearchController.dispose();
    _drawerScrollController.dispose();
    super.dispose();
  }

  void _showCenterOverlay(int number) {
    _overlayTimer?.cancel();
    setState(() {
      _centerOverlayNumber = number;
    });
    _overlayTimer = Timer(const Duration(milliseconds: 700), () {
      setState(() {
        _centerOverlayNumber = null;
      });
    });
  }

  Widget _buildEmptyState(
      {required IconData icon, required String title, String? message}) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 48, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36.0),
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            )
          ]
        ],
      ),
    );
  }

  String _getVerseTextCached(int surahId, int ayahId) {
    final key = '$surahId:$ayahId';
    if (_verseTextCache.containsKey(key)) return _verseTextCache[key]!;
    final verseText = getVerse(surahId, ayahId, verseEndSymbol: true);
    _verseTextCache[key] = verseText;
    return verseText;
  }

  String _getLatestBookmarkSubtitle(Bookmark? b) {
    if (b == null) {
      return AppLocalizations.of(context)?.translate('no_bookmarks_found') ??
          'No bookmarks found';
    }
    final hour = b.createdAt.hour > 12
        ? b.createdAt.hour - 12
        : (b.createdAt.hour == 0 ? 12 : b.createdAt.hour);
    final minute = b.createdAt.minute.toString().padLeft(2, '0');
    final isNight = b.createdAt.hour >= 18 || b.createdAt.hour < 5;
    final timeLabel = isNight
        ? (AppLocalizations.of(context)?.translate('time_night') ?? 'at night')
        : (AppLocalizations.of(context)?.translate('time_morning') ??
            'at morning');
    final timeStr = "$hour:$minute $timeLabel";
    final surahName = getBilingualSurahName(context, b.surahId);
    return "$timeStr $surahName: ${b.ayahId}";
  }

  Widget _buildNumberSidebar(
      {required int itemCount,
      required void Function(int number) onTapNumber}) {
    return SizedBox(
      width: 18,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: itemCount,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final number = index + 1;
          return GestureDetector(
            onTap: () => onTapNumber(number),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 0),
              child: Center(
                child: Text(
                  number.toString(),
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 9,
                      color: BrandColors.accent),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final background =
        isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor;
    final drawerWidth = MediaQuery.of(context).size.width;
    final textDirection = Directionality.of(context);

    final tabTitles = [
      AppLocalizations.of(context)?.translate('tab_contents') ?? 'Contents',
      AppLocalizations.of(context)?.translate('tab_khatmah') ?? 'Khatmah',
      AppLocalizations.of(context)?.translate('tab_bookmarks') ?? 'Bookmarks',
      AppLocalizations.of(context)?.translate('tab_notes') ?? 'Highlights',
    ];

    return Drawer(
      width: drawerWidth,
      backgroundColor: background,
      child: Column(
        children: [
          PermanentAppBar(
            selectedTabIndex: _selectedTabIndex,
            navigationMode: _navigationMode,
            onNavigationModeChanged: (mode) =>
                setState(() => _navigationMode = mode),
            isEditingBookmarks:
                (_selectedTabIndex == 2 && _isEditingBookmarks) ||
                    (_selectedTabIndex == 3 && _isEditingNotes),
            onEditBookmarks: () {
              if (_selectedTabIndex == 2) {
                if (_isEditingBookmarks) {
                  final state = context.read<BookmarkNotesNotifier>();
                  _categoryEditControllers.forEach((color, ctrl) =>
                      state.updateCategoryName(color, ctrl.text));
                }
                setState(() => _isEditingBookmarks = !_isEditingBookmarks);
              } else if (_selectedTabIndex == 3) {
                setState(() => _isEditingNotes = !_isEditingNotes);
              }
            },
            highlightsMode: _highlightsMode,
            onHighlightsModeChanged: (m) => setState(() => _highlightsMode = m),
          ),
          // Heading is moved into the lists so it scrolls away with content.
          Expanded(
            child: _selectedTabIndex == 0
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      const double sidebarWidth = 22 + 6;
                      EdgeInsets contentPadding =
                          textDirection == TextDirection.rtl
                              ? const EdgeInsets.only(left: sidebarWidth)
                              : const EdgeInsets.only(right: sidebarWidth);
                      return Stack(
                        children: [
                          Padding(
                              padding: contentPadding,
                              child: _buildCurrentTab()),
                          Align(
                            alignment: textDirection == TextDirection.rtl
                                ? Alignment(-1.0, -0.15)
                                : Alignment(1.0, -0.15),
                            child: Padding(
                              padding: EdgeInsets.only(
                                right:
                                    textDirection == TextDirection.rtl ? 0 : 4,
                                left:
                                    textDirection == TextDirection.rtl ? 4 : 0,
                              ),
                              child: SizedBox(
                                height: constraints.maxHeight * 0.6,
                                child: _buildNumberSidebar(
                                  itemCount: juz.length,
                                  onTapNumber: (number) {
                                    _showCenterOverlay(number);
                                    if (_navigationMode ==
                                        NavigationMode.surah) {
                                      _scrollToJuzInSurahList(number);
                                    } else {
                                      _scrollToJuzItem(number);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                          // Centered overlay showing tapped number
                          Positioned.fill(
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                opacity: _centerOverlayNumber == null ? 0 : 1,
                                duration: const Duration(milliseconds: 120),
                                child: Center(
                                  child: _centerOverlayNumber == null
                                      ? const SizedBox.shrink()
                                      : Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.06),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '$_centerOverlayNumber',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: BrandColors.accent,
                                                  fontSize: 56,
                                                ),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                : _buildCurrentTab(),
          ),
          _buildBottomBar(context, background),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSurahList();
      case 1:
        return KhatmahTab(controller: widget.controller);
      case 2:
        return _buildBookmarksList();
      case 3:
        return _buildNotesTab();
      default:
        return _buildSurahList();
    }
  }

  Widget _buildSurahList() {
    return _navigationMode == NavigationMode.surah
        ? _buildSurahListGroupedByJuz()
        : ListView.builder(
            controller: _drawerScrollController,
            padding: EdgeInsets.zero,
            itemCount: juz.length + 1, // plus header
            itemBuilder: (context, index) {
              if (index == 0) {
                final theme = Theme.of(context);
                return Container(
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.only(left: 24, top: 20, bottom: 8),
                  child: Text(
                    AppLocalizations.of(context)?.translate('tab_contents') ??
                        'Contents',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onBackground,
                      fontSize: 34,
                    ),
                  ),
                );
              }
              final info = juz[index - 1];
              final juzNumber = info['id'] as int;
              _juzItemKeys.putIfAbsent(juzNumber, () => GlobalKey());
              return Column(
                children: [
                  Container(
                      key: _juzItemKeys[juzNumber], child: _buildJuzItem(info)),
                  if (index - 1 < juz.length - 1)
                    Divider(
                        height: 1,
                        indent: 76,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.08)),
                ],
              );
            },
          );
  }

  Widget _buildSurahListGroupedByJuz() {
    final entries = _buildSurahEntries();
    // include a top header item so the Contents title scrolls away
    return ListView.builder(
      padding: EdgeInsets.zero,
      controller: _drawerScrollController,
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          final theme = Theme.of(context);
          return Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24, top: 20, bottom: 8),
            child: Text(
              AppLocalizations.of(context)?.translate('tab_contents') ??
                  'Contents',
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onBackground,
                fontSize: 34,
              ),
            ),
          );
        }
        final entry = entries[index - 1];
        if (entry.isHeader) {
          _juzHeaderKeys.putIfAbsent(entry.juzNumber, () => GlobalKey());
          final double topPad = index == 1 ? 20.0 : 16.0;
          return Container(
            key: _juzHeaderKeys[entry.juzNumber],
            padding: EdgeInsets.fromLTRB(24.0, topPad, 16.0, 4.0),
            child: Builder(builder: (ctx) {
              final theme = Theme.of(ctx);
              return Text(
                (AppLocalizations.of(ctx)?.translate('part_label') ??
                        'PART {number}')
                    .replaceAll('{number}', '${entry.juzNumber}'),
                style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ) ??
                    TextStyle(
                        fontSize: 12,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withOpacity(0.6)),
              );
            }),
          );
        }
        final surahInfo = entry.surahInfo!;
        final isNextHeader =
            (index < entries.length && entries[index].isHeader);
        return Column(
          children: [
            _buildSurahItem(surahInfo['id'], surahInfo),
            if (!isNextHeader)
              Divider(
                  height: 1,
                  indent: 84,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.08)),
          ],
        );
      },
    );
  }

  void _scrollToJuzInSurahList(int juzNumber) {
    final entries = _buildSurahEntries();
    final index = entries
        .indexWhere((entry) => entry.isHeader && entry.juzNumber == juzNumber);
    if (index != -1) {
      _drawerScrollController.animateTo(index * 60.0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _scrollToJuzItem(int juzNumber) {
    final index = juz.indexWhere((j) => j['id'] == juzNumber);
    if (index != -1) {
      _drawerScrollController.animateTo(index * 72.0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  List<_SurahListEntry> _buildSurahEntries() {
    final List<_SurahListEntry> entries = [];
    for (final juzInfo in juz) {
      entries.add(_SurahListEntry.header(juzInfo['id']));
      final surahsInJuz = (juzInfo['surahs'] as List<dynamic>?) ?? [];
      for (final s in surahsInJuz) {
        entries.add(_SurahListEntry.surah(juzInfo['id'], surah[s - 1]));
      }
    }
    return entries;
  }

  Widget _buildSurahItem(int surahNumber, Map<String, dynamic> surahInfo) {
    final theme = Theme.of(context);
    String surahName = getBilingualSurahName(context, surahNumber);
    int startPage = _surahStartPages[surahNumber] ?? (surahNumber * 10);
    final place = surahInfo['place'] == 'Makkah'
        ? (AppLocalizations.of(context)?.translate('place_meccan') ?? 'Meccan')
        : (AppLocalizations.of(context)?.translate('place_medinan') ??
            'Medinan');
    final subtitle =
        (AppLocalizations.of(context)?.translate('surah_list_subtitle') ??
                'Page {page} - {count} verses - {place}')
            .replaceAll('{page}', '$startPage')
            .replaceAll('{count}', '${surahInfo['aya']}')
            .replaceAll('{place}', place);

    return ListTile(
      // Reduced vertical padding to match screenshot denseness
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: _buildSurahCircleAvatar(surahNumber, context),
      title: Text(surahName,
          style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface) ??
              TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.colorScheme.onSurface)),
      subtitle: Text(subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.2,
              ) ??
              TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.2)),
      onTap: () {
        widget.controller.navigateToSurah(surahNumber);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSurahCircleAvatar(int number, BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Center(
          child: Text(number.toString(),
              style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12))),
    );
  }

  Widget _buildJuzItem(Map<String, dynamic> juzInfo) {
    final juzNumber = juzInfo['id'] as int;
    final startingSurah = (juzInfo['surahs'] as List).first;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: _buildSurahCircleAvatar(juzNumber, context),
      title: Text(
        (AppLocalizations.of(context)?.translate('part_label') ??
                'PART {number}')
            .replaceAll('{number}', '$juzNumber'),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
      ),
      subtitle: Text(getBilingualSurahName(context, startingSurah),
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
      onTap: () {
        widget.controller.navigateToSurah(startingSurah);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, Color background) {
    final activeColor = BrandColors.accent;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final double baseHeight = isIOS ? 28.0 : 72.0;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: baseHeight + bottomInset,
          child: BottomNavigationBar(
            currentIndex: _selectedTabIndex,
            onTap: (index) => setState(() {
              _selectedTabIndex = index;
              if (index != 2) _isEditingBookmarks = false;
            }),
            selectedItemColor: activeColor,
            unselectedItemColor: Colors.grey.shade500,
            showUnselectedLabels: true,
            selectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            type: BottomNavigationBarType.fixed,
            elevation: 0, // Handled by wrapping container shadow
            backgroundColor: Colors.transparent, // Uses container background
            items: [
              BottomNavigationBarItem(
                  icon: const Icon(Icons.format_list_bulleted, size: 28),
                  label:
                      AppLocalizations.of(context)?.translate('tab_contents') ??
                          'Contents'),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.check_circle_rounded, size: 28),
                  label:
                      AppLocalizations.of(context)?.translate('tab_khatmah') ??
                          'Khatmah'),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.bookmark_rounded, size: 28),
                  label: AppLocalizations.of(context)
                          ?.translate('tab_bookmarks') ??
                      'Bookmarks'),
              BottomNavigationBarItem(
                  icon: const Icon(Icons.edit_rounded, size: 28),
                  label: AppLocalizations.of(context)?.translate('tab_notes') ??
                      'Highlights'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarksList() {
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        final theme = Theme.of(context);
        final isLight = theme.brightness == Brightness.light;

        if (!state.isInitialized && !state.isLoading) {
          state.initialize();
        }

        final filteredBookmarks = _selectedBookmarkColor == null
            ? state.bookmarks
            : state.bookmarks
                .where((b) => _isSameColor(b.colorHex, _selectedBookmarkColor!))
                .toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  AppLocalizations.of(context)?.translate('bookmarks_title') ??
                      'Bookmarks',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 36,
                      ),
                ),
              ),
              _buildBookmarkGroupedContainer(
                context,
                isLight,
                children: _bookmarkColorCategories.map((cat) {
                  final latest = state.bookmarks.firstWhere(
                    (b) => _isSameColor(b.colorHex, cat['hex']!),
                    orElse: () => Bookmark(
                      surahId: 0,
                      ayahId: 0,
                      colorHex: cat['hex']!,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );

                  return _buildBookmarkCategoryTile(
                    context,
                    isLight,
                    cat['name']!,
                    cat['hex']!,
                    latest,
                    state,
                    onTap: () {
                      setState(() {
                        _selectedBookmarkColor =
                            (_selectedBookmarkColor == cat['hex'])
                                ? null
                                : cat['hex'];
                      });
                    },
                    isSelected: _selectedBookmarkColor == cat['hex'],
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              if (filteredBookmarks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                  child: Text(
                    _selectedBookmarkColor == null
                        ? 'All Bookmarks'
                        : 'Filtered Bookmarks',
                    style: TextStyle(
                      color: isLight
                          ? theme.colorScheme.onSurface.withOpacity(0.6)
                          : Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              _buildBookmarkGroupedContainer(
                context,
                isLight,
                children: filteredBookmarks
                    .map((b) => _buildBookmarkEntryTile(
                          context,
                          isLight,
                          b,
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBookmarkGroupedContainer(
    BuildContext context,
    bool isLight, {
    required List<Widget> children,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color:
            isLight ? theme.scaffoldBackgroundColor : const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: List.generate(children.length, (index) {
          return Column(
            children: [
              children[index],
              if (index != children.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: isLight
                      ? theme.colorScheme.surface
                      : const Color(0xFF38383A),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildBookmarkCategoryTile(
    BuildContext context,
    bool isLight,
    String name,
    String hex,
    Bookmark latest,
    BookmarkNotesNotifier state, {
    required VoidCallback onTap,
    required bool isSelected,
  }) {
    final theme = Theme.of(context);
    final color = Color(_parseColor(hex));
    final hasData = latest.surahId != 0;
    final isQuickBookmarkColor =
        _isSameColor(state.quickBookmarkColor ?? '#EF5350', hex);

    return ListTile(
      onTap: onTap,
      dense: true,
      tileColor: isSelected
          ? (isLight
              ? theme.colorScheme.surfaceContainerHighest
              : Colors.white.withOpacity(0.05))
          : null,
      leading: GestureDetector(
        onTap: () => state.setQuickBookmarkColor(hex),
        child: Icon(
          isQuickBookmarkColor ? Icons.bookmark : Icons.bookmark_outline,
          color: color,
          size: 28,
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          color: isLight ? theme.colorScheme.onSurface : Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: hasData
          ? Text(
              '${_formatTime(latest.updatedAt)}  ${getBilingualSurahName(context, latest.surahId)}: ${latest.ayahId}',
              style: TextStyle(
                color: isLight
                    ? theme.colorScheme.onSurface.withOpacity(0.6)
                    : const Color(0xFF8E8E93),
                fontSize: 14,
              ),
            )
          : Text(
              'No items',
              style: TextStyle(
                color: isLight
                    ? theme.colorScheme.onSurface.withOpacity(0.4)
                    : const Color(0xFF48484A),
                fontSize: 14,
              ),
            ),
      trailing: isSelected
          ? const Icon(Icons.check, color: Color(0xFF4CAF50), size: 20)
          : null,
    );
  }

  Widget _buildBookmarkEntryTile(
    BuildContext context,
    bool isLight,
    Bookmark b,
  ) {
    final theme = Theme.of(context);
    final name = getBilingualSurahName(context, b.surahId);
    final color = Color(_parseColor(b.colorHex));

    return Dismissible(
      key: ValueKey('entry_${b.surahId}_${b.ayahId}_${b.updatedAt}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => context
          .read<BookmarkNotesNotifier>()
          .deleteBookmark(b.surahId, b.ayahId),
      child: ListTile(
        onTap: () {
          widget.controller.navigateToVerse(b.surahId, b.ayahId);
          Navigator.pop(context);
        },
        leading: Icon(Icons.bookmark, color: color, size: 24),
        title: Text(
          '$name: ${b.ayahId}',
          style: TextStyle(
            color: isLight ? theme.colorScheme.onSurface : Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          _formatTime(b.updatedAt),
          style: TextStyle(
            color: isLight
                ? theme.colorScheme.onSurface.withOpacity(0.6)
                : Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isLight
              ? theme.colorScheme.onSurface.withOpacity(0.4)
              : const Color(0xFF38383A),
        ),
      ),
    );
  }

  bool _isSameColor(String hex1, String hex2) {
    return hex1.replaceAll('#', '').toUpperCase() ==
        hex2.replaceAll('#', '').toUpperCase();
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final hour =
        date.hour == 0 ? 12 : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = (date.hour >= 18 || date.hour < 5) ? 'at night' : 'at day';
    return '$hour:$minute $period';
  }

  int _parseColor(String hex) {
    final normalized = hex.replaceAll('#', '');
    return int.tryParse('FF$normalized', radix: 16) ?? 0xFF8E8E93;
  }

  Widget _buildNotesTab() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBackground =
        isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    return Consumer<HighlightNotifier>(
      builder: (context, highlightState, _) {
        // Ensure highlights are loaded
        if (!highlightState.highlights.isNotEmpty &&
            highlightState is HighlightNotifier) {
          highlightState.initialize();
        }
        final highlights = highlightState.highlights;
        // Search logic
        String searchQuery = _noteSearchController.text.trim();
        List<Highlight> filteredHighlights = highlights;
        if (searchQuery.isNotEmpty) {
          filteredHighlights = highlights.where((h) {
            final verseText = _getVerseTextCached(h.surahId, h.ayahId);
            final surahName = getBilingualSurahName(context, h.surahId);
            return verseText
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase()) ||
                surahName.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }
        if (highlights.isEmpty) {
          return _buildEmptyState(
            icon: Icons.edit_rounded,
            title: AppLocalizations.of(context)
                    ?.translate('no_highlights_found') ??
                'No Highlights',
            message: AppLocalizations.of(context)
                    ?.translate('no_highlights_instruction') ??
                'Touch and hold a verse, then choose a highlight color.',
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 24, bottom: 0),
              child: Text(
                'Highlight',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 36,
                        ) ??
                    const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 36,
                    ),
                textAlign: TextAlign.left,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.12),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _noteSearchController,
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context)
                                  ?.translate('search_highlights') ??
                              'Search',
                          hintStyle:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.6),
                                  ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _highlightsMode == 0
                  ? _buildHighlightsGroupedBySurah(
                      filteredHighlights, theme, isLight)
                  : _buildHighlightsGroupedByColor(
                      filteredHighlights, theme, isLight),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightsGroupedBySurah(
      List<Highlight> highlights, ThemeData theme, bool isLight) {
    final Map<int, List<Highlight>> surahMap = {};
    for (final h in highlights) {
      surahMap.putIfAbsent(h.surahId, () => []).add(h);
    }
    final surahIds = surahMap.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      children: [
        for (final surahId in surahIds) ...[
          Padding(
            padding:
                const EdgeInsets.only(left: 4, top: 18, bottom: 6, right: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                final isCollapsed = _collapsedHighlightSurahs.contains(surahId);
                setState(() {
                  if (isCollapsed) {
                    _collapsedHighlightSurahs.remove(surahId);
                  } else {
                    _collapsedHighlightSurahs.add(surahId);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        getBilingualSurahName(context, surahId),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Icon(
                      _collapsedHighlightSurahs.contains(surahId)
                          ? Icons.chevron_right
                          : Icons.expand_more,
                      size: 22,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!_collapsedHighlightSurahs.contains(surahId))
            ...surahMap[surahId]!
                .map((h) => _buildHighlightTile(h, isLight, theme))
                .toList(),
        ]
      ],
    );
  }

  Widget _buildHighlightsGroupedByColor(
      List<Highlight> highlights, ThemeData theme, bool isLight) {
    final colorCategories = [
      {'name': 'Red', 'hex': '#EF5350'},
      {'name': 'Yellow', 'hex': '#FFB300'},
      {'name': 'Orange', 'hex': '#FFA726'},
      {'name': 'Green', 'hex': '#66BB6A'},
      {'name': 'Blue', 'hex': '#42A5F5'},
      {'name': 'Purple', 'hex': '#AB47BC'},
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      children: [
        for (final cat in colorCategories)
          if (highlights.any((h) => _isSameColor(h.colorHex, cat['hex']!)))
            ...(() {
              final isCollapsed =
                  _collapsedHighlightColors.contains(cat['hex']!);
              return [
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 16, bottom: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      setState(() {
                        if (isCollapsed) {
                          _collapsedHighlightColors.remove(cat['hex']!);
                        } else {
                          _collapsedHighlightColors.add(cat['hex']!);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cat['name']!,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Color(_parseColor(cat['hex']!))),
                            ),
                          ),
                          Icon(
                            isCollapsed
                                ? Icons.chevron_right
                                : Icons.expand_more,
                            size: 20,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isCollapsed)
                  ...highlights
                      .where((h) => _isSameColor(h.colorHex, cat['hex']!))
                      .map((h) => _buildHighlightTile(h, isLight, theme))
                      .toList(),
              ];
            })(),
      ],
    );
  }

  Widget _buildHighlightTile(Highlight h, bool isLight, ThemeData theme) {
    final color = Color(_parseColor(h.colorHex));
    final surahName = getBilingualSurahName(context, h.surahId);
    final verseText = _getVerseTextCached(h.surahId, h.ayahId);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 0),
      decoration: BoxDecoration(
        color: isLight
            ? const Color(0xFF232323).withOpacity(0.04)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            widget.controller.navigateToVerse(h.surahId, h.ayahId);
            Navigator.pop(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verseText,
                  style: TextStyle(
                    fontFamily: 'Amiri',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.7,
                    color: isLight ? theme.colorScheme.onSurface : Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$surahName: ${h.ayahId}',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onNoteSearchChanged(String query, BookmarkNotesNotifier state) async {
    setState(() => _isSearchingNotes = true);
    await Future.delayed(const Duration(milliseconds: 200));
    final results = state.notes
        .where((note) =>
            note.content.toLowerCase().contains(query.toLowerCase()) ||
            surah[note.surahId - 1]['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList();
    setState(() {
      _noteResults = results;
      _isSearchingNotes = false;
    });
  }
}
