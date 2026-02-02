import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/bookmarks/data/models/note.dart';
import 'package:quran_app/features/bookmarks/data/models/bookmark.dart';
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
          const double toggleWidth = 180;
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
                child: (selectedTabIndex == 2 || selectedTabIndex == 3)
                    ? TextButton(
                        onPressed: onEditBookmarks,
                        style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft),
                        child: Text(
                          isEditingBookmarks
                              ? (AppLocalizations.of(context)
                                      ?.translate('done') ??
                                  'Done')
                              : (AppLocalizations.of(context)
                                      ?.translate('edit') ??
                                  'Edit'),
                          style: const TextStyle(
                              color: BrandColors.accent,
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Center: Surah/Juz toggle or Highlights pills
              if (selectedTabIndex == 0)
                Padding(
                  padding: EdgeInsets.only(left: leftPad, right: rightPad),
                  child: SizedBox(
                    width: toggleWidth,
                    child: _SurahJuzToggle(
                      navigationMode: navigationMode,
                      onChanged: onNavigationModeChanged,
                    ),
                  ),
                )
              else if (selectedTabIndex == 3)
                Padding(
                  padding: EdgeInsets.only(left: leftPad, right: rightPad),
                  child: SizedBox(
                    width: toggleWidth,
                    child: Center(
                      child: SizedBox(
                        width: toggleWidth,
                        child: Container(
                          height: 34,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
                    ),
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
    return SizedBox(
      width: 180,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              isSelected ? Theme.of(context).canvasColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1))
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
  final TextEditingController _noteSearchController = TextEditingController();
  List<NoteModel> _noteResults = [];
  bool _isSearchingNotes = false;
  NavigationMode _navigationMode = NavigationMode.surah;
  final Map<String, String> _verseTextCache = {};
  bool _isEditingBookmarks = false;
  bool _isEditingNotes = false;
  int _highlightsMode = 0; // 0: Surahs, 1: Colors

  final ScrollController _drawerScrollController = ScrollController();
  final Map<int, GlobalKey> _juzHeaderKeys = {};
  final Map<int, GlobalKey> _juzItemKeys = {};
  Timer? _overlayTimer;
  int? _centerOverlayNumber;

  final Map<String, TextEditingController> _categoryEditControllers = {};
  final Map<String, bool> _expandedCategories = {};

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
        final cardBackground =
            isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
        final categoryMap = state.categoryNames;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
              Container(
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: categoryMap.entries.map((entry) {
                    final colorHex = entry.key;
                    final displayName = entry.value;
                    final matching = state.bookmarks
                        .where((b) =>
                            b.colorHex.toUpperCase() == colorHex.toUpperCase())
                        .toList();
                    Bookmark? latest;
                    if (matching.isNotEmpty) {
                      matching
                          .sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
                      latest = matching.first;
                    } else {
                      latest = null;
                    }

                    if (!_categoryEditControllers.containsKey(colorHex)) {
                      _categoryEditControllers[colorHex] =
                          TextEditingController(text: displayName);
                    }

                    final expanded = _expandedCategories[colorHex] ?? false;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category header tile
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: (() {
                            final color = Color(
                                int.parse(colorHex.replaceAll('#', '0xFF')));
                            return Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child:
                                  Icon(Icons.bookmark, color: color, size: 20),
                            );
                          })(),
                          title: _isEditingBookmarks
                              ? TextField(
                                  controller:
                                      _categoryEditControllers[colorHex],
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                      border: InputBorder.none, isDense: true),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17),
                                )
                              : Text(displayName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17)),
                          subtitle: _isEditingBookmarks
                              ? null
                              : Text(
                                  latest != null
                                      ? _getLatestBookmarkSubtitle(latest)
                                      : (AppLocalizations.of(context)
                                              ?.translate(
                                                  'no_bookmarks_found') ??
                                          'No bookmarks'),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5))),
                          onTap: _isEditingBookmarks
                              ? null
                              : () {
                                  setState(() {
                                    final cur =
                                        _expandedCategories[colorHex] ?? false;
                                    _expandedCategories[colorHex] = !cur;
                                  });
                                },
                          trailing: Icon(
                            _expandedCategories[colorHex] == true
                                ? Icons.expand_less
                                : Icons.expand_more,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.5),
                          ),
                        ),

                        // List all bookmarks in this category (if any) when expanded
                        if (expanded && matching.isNotEmpty)
                          ...matching.map((bm) {
                            final bmColor = Color(
                                int.parse(colorHex.replaceAll('#', '0xFF')));
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding:
                                      const EdgeInsets.fromLTRB(72, 6, 16, 6),
                                  leading: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: bmColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(Icons.bookmark,
                                        color: bmColor, size: 18),
                                  ),
                                  title: Text(
                                    getBilingualSurahName(context, bm.surahId) +
                                        ' : ${bm.ayahId}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    _getLatestBookmarkSubtitle(bm),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withOpacity(0.6)),
                                  ),
                                  onTap: () {
                                    widget.controller
                                        .navigateToVerse(bm.surahId, bm.ayahId);
                                    Navigator.pop(context);
                                  },
                                ),
                                if (matching.last != bm)
                                  Divider(
                                      height: 1,
                                      indent: 84,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.06)),
                              ],
                            );
                          }).toList(),

                        if (entry.key != categoryMap.keys.last)
                          Divider(
                              height: 1,
                              indent: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.06)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotesTab() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBackground =
        isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 20, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              (AppLocalizations.of(context)?.translate('tab_notes') ??
                  'Highlights'),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 34,
              ),
            ),
          ),
        ),

        // Search field
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(0.12),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.search,
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteSearchController,
                    decoration: InputDecoration(
                      hintText:
                          AppLocalizations.of(context)?.translate('search') ??
                              'Search',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) => _onNoteSearchChanged(
                        val, context.read<BookmarkNotesNotifier>()),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isSearchingNotes) const LinearProgressIndicator(),
        Expanded(
          child: Consumer<BookmarkNotesNotifier>(
            builder: (context, state, _) {
              final notes = _noteSearchController.text.isEmpty
                  ? state.notes
                  : _noteResults;
              if (notes.isEmpty)
                return _buildEmptyState(
                    icon: Icons.note_alt_outlined,
                    title: AppLocalizations.of(context)
                            ?.translate('no_highlights_found') ??
                        'No Highlights',
                    message: AppLocalizations.of(context)
                            ?.translate('no_highlights_instruction') ??
                        'Touch and hold a verse, then choose a highlight color.');
              return ListView.separated(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: notes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  return ListTile(
                    title: Text(
                        '${surah[note.surahId - 1]['name']} (${note.surahId}:${note.ayahId})'),
                    subtitle: Text(note.content,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      widget.controller
                          .navigateToVerse(note.surahId, note.ayahId);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
