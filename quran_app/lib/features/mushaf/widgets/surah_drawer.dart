import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/bookmarks/data/models/note.dart';
import '../controller/mushaf_controller.dart';
import '../../../core/quran/data/suwar.dart';
import '../../../core/quran/data/juzs.dart';
import '../../khatmah/widgets/khatmah_tab.dart';
import '../../../core/quran/qcf_quran.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/app/app.dart';

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

  const PermanentAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.navigationMode,
    required this.onNavigationModeChanged,
    this.isEditingBookmarks = false,
    this.onEditBookmarks,
  });

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).viewPadding.top;
    final double topPadding = topInset > 0 ? topInset + 8 : 32;
    // Remove bottom padding to eliminate space under back icon
    return Container(
      padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          // Left: Edit button for Bookmarks tab
          SizedBox(
            width: 80,
            child: selectedTabIndex == 2
                ? TextButton(
                    onPressed: onEditBookmarks,
                    style:
                        TextButton.styleFrom(alignment: Alignment.centerLeft),
                    child: Text(
                      isEditingBookmarks ? 'Done' : 'Edit',
                      style: const TextStyle(
                          color: BrandColors.accent,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Center: Surah/Juz navigation for Contents tab
          Expanded(
            child: selectedTabIndex == 0
                ? Center(
                    child: _SurahJuzToggle(
                      navigationMode: navigationMode,
                      onChanged: onNavigationModeChanged,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Right: Back button
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.chevron_right,
                  color: BrandColors.accent, size: 28),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
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
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            label: AppLocalizations.of(context)?.translate('toggle_surahs') ??
                'Sūrahs',
            isSelected: navigationMode == NavigationMode.surah,
            onTap: () => onChanged(NavigationMode.surah),
          ),
          _ToggleButton(
            label: AppLocalizations.of(context)?.translate('toggle_juz') ??
                'Quarters',
            isSelected: navigationMode == NavigationMode.juz,
            onTap: () => onChanged(NavigationMode.juz),
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.28)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
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
  int _selectedTabIndex = 0; // 0: Surah, 1: Khatmah, 2: Bookmarks, 3: Notes
  final TextEditingController _noteSearchController = TextEditingController();
  List<NoteModel> _noteResults = [];
  bool _isSearchingNotes = false;
  NavigationMode _navigationMode = NavigationMode.surah;
  final Map<String, String> _verseTextCache = {};
  bool _isEditingBookmarks = false;
  String? _selectedBookmarkColor;

  final ScrollController _drawerScrollController = ScrollController();
  final Map<int, GlobalKey> _juzHeaderKeys = {};
  final Map<int, GlobalKey> _juzItemKeys = {};

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 48,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
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

  Widget _buildNumberSidebar({
    required int itemCount,
    required void Function(int number) onTapNumber,
  }) {
    return SizedBox(
      width: 22,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          final number = index + 1;
          return GestureDetector(
            onTap: () => onTapNumber(number),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Center(
                child: Text(
                  number.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                    color: BrandColors.accent,
                  ),
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
    final drawerWidth = MediaQuery.of(context).size.width;
    final textDirection = Directionality.of(context);

    // Tab titles for each tab (now all localized)
    final tabTitles = [
      AppLocalizations.of(context)?.translate('tab_contents') ?? 'Contents',
      AppLocalizations.of(context)?.translate('tab_khatmah') ?? 'Khatmah',
      AppLocalizations.of(context)?.translate('tab_bookmarks') ?? 'Bookmarks',
      AppLocalizations.of(context)?.translate('tab_notes') ?? 'Highlights',
    ];

    return Drawer(
      width: drawerWidth,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          PermanentAppBar(
            selectedTabIndex: _selectedTabIndex,
            navigationMode: _navigationMode,
            onNavigationModeChanged: (mode) =>
                setState(() => _navigationMode = mode),
            isEditingBookmarks: _isEditingBookmarks,
            onEditBookmarks: () =>
                setState(() => _isEditingBookmarks = !_isEditingBookmarks),
          ),
          // Bold tab/page name under app bar and above content, reduced vertical space
          Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(
              left: 24,
              top: 18,
              bottom: 0,
            ), // move title lower for all platforms
            child: Text(
              tabTitles[_selectedTabIndex],
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 28,
                  ),
            ),
          ),
          Expanded(
            child: _selectedTabIndex == 0
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      // Sidebar width + padding
                      const double sidebarWidth =
                          22 + 8; // 22 width + 4 padding each side
                      EdgeInsets contentPadding =
                          textDirection == TextDirection.rtl
                              ? EdgeInsets.only(left: sidebarWidth)
                              : EdgeInsets.only(right: sidebarWidth);
                      return Stack(
                        children: [
                          Padding(
                            padding: contentPadding,
                            child: _buildCurrentTab(),
                          ),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right:
                                textDirection == TextDirection.rtl ? null : 0,
                            left: textDirection == TextDirection.rtl ? 0 : null,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: SizedBox(
                                height: constraints.maxHeight,
                                child: _buildNumberSidebar(
                                  itemCount: juz.length,
                                  onTapNumber: (number) {
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
                        ],
                      );
                    },
                  )
                : _buildCurrentTab(),
          ),
          _buildBottomBar(context),
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
        : ListView.separated(
            controller: _drawerScrollController,
            itemCount: juz.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 76,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
            itemBuilder: (context, index) {
              final info = juz[index];
              final juzNumber = info['id'] as int;
              _juzItemKeys.putIfAbsent(juzNumber, () => GlobalKey());
              return Container(
                  key: _juzItemKeys[juzNumber], child: _buildJuzItem(info));
            },
          );
  }

  Widget _buildSurahListGroupedByJuz() {
    final entries = _buildSurahEntries();
    return ListView.builder(
      controller: _drawerScrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          final label =
              '${AppLocalizations.of(context)?.translate('juz_prefix') ?? 'Part'} ${entry.juzNumber}';
          _juzHeaderKeys.putIfAbsent(entry.juzNumber, () => GlobalKey());
          return Container(
            key: _juzHeaderKeys[entry.juzNumber],
            padding: EdgeInsets.fromLTRB(16, index == 0 ? 8 : 18, 16, 8),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          );
        }
        final surahInfo = entry.surahInfo!;
        return Column(
          children: [
            _buildSurahItem(surahInfo['id'], surahInfo),
            Divider(
                height: 1,
                indent: 76,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
          ],
        );
      },
    );
  }

  void _scrollToJuzInSurahList(int juzNumber) {
    // Find the index of the header for the selected Juz
    final entries = _buildSurahEntries();
    final index = entries.indexWhere(
      (entry) => entry.isHeader && entry.juzNumber == juzNumber,
    );
    if (index != -1) {
      _drawerScrollController.animateTo(
        index * 56.0, // Approximate item height (adjust if needed)
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _scrollToJuzItem(int juzNumber) {
    // In Juz mode, each Juz is a single item in the list
    final index = juz.indexWhere((j) => j['id'] == juzNumber);
    if (index != -1) {
      _drawerScrollController.animateTo(
        index * 72.0, // Approximate item height (adjust if needed)
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
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
    String surahName = _getLocalizedSurahName(surahInfo);
    String surahMeaning = _getLocalizedSurahMeaning(surahInfo);
    String subtitle =
        '$surahMeaning • ${surahInfo['aya']} ${AppLocalizations.of(context)?.translate('verses_suffix') ?? 'verses'}';
    return ListTile(
      leading: _buildSurahCircleAvatar(surahNumber, context),
      title: Text(surahName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      subtitle: Text(subtitle,
          style: TextStyle(
              fontSize: 12,
              color:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.65))),
      onTap: () {
        widget.controller.navigateToSurah(surahNumber);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSurahCircleAvatar(int number, BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
      ),
      child: Center(
          child: Text(number.toString(),
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14))),
    );
  }

  Widget _buildJuzItem(Map<String, dynamic> juzInfo) {
    final juzNumber = juzInfo['id'] as int;
    final startingSurah = (juzInfo['surahs'] as List).first;
    return ListTile(
      leading: _buildSurahCircleAvatar(juzNumber, context),
      title: Text(
          '${AppLocalizations.of(context)?.translate('juz_prefix') ?? 'Juz'} $juzNumber',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      subtitle: Text(_getLocalizedSurahName(surah[startingSurah - 1]),
          style: const TextStyle(fontSize: 12)),
      onTap: () {
        widget.controller.navigateToSurah(startingSurah);
        Navigator.pop(context);
      },
    );
  }

  String _getLocalizedSurahName(Map<String, dynamic> surahInfo) {
    final locale = AppLocalizations.of(context)?.locale.languageCode;
    return (locale == 'ar' || locale == 'ur')
        ? (surahInfo['arabic'] ?? surahInfo['name'])
        : surahInfo['name'];
  }

  String _getLocalizedSurahMeaning(Map<String, dynamic> surahInfo) {
    int surahNumber = surahInfo['id'];
    String? localized =
        AppLocalizations.of(context)?.translate('surah_meaning_$surahNumber');
    return (localized != null && localized != 'surah_meaning_$surahNumber')
        ? localized
        : (surahInfo['english'] ?? '');
  }

  Widget _buildBottomBar(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.08),
      child: BottomNavigationBar(
        currentIndex: _selectedTabIndex,
        onTap: (index) => setState(() {
          _selectedTabIndex = index;
          if (index != 2) _isEditingBookmarks = false;
        }),
        selectedItemColor: BrandColors.accent,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        items: [
          BottomNavigationBarItem(
              icon: const Icon(Icons.menu_book_rounded),
              label: AppLocalizations.of(context)?.translate('tab_contents') ??
                  'Contents'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.check_circle_outline),
              label: AppLocalizations.of(context)?.translate('tab_khatmah') ??
                  'Khatmah'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.bookmark),
              label: AppLocalizations.of(context)?.translate('tab_bookmarks') ??
                  'Bookmarks'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.sticky_note_2_outlined),
              label: AppLocalizations.of(context)?.translate('tab_notes') ??
                  'Highlights'),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        final filteredBookmarks = _selectedBookmarkColor == null
            ? state.bookmarks
            : state.bookmarks
                .where((b) => b.colorHex
                    .toUpperCase()
                    .contains(_selectedBookmarkColor!.toUpperCase()))
                .toList();

        if (filteredBookmarks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border,
            message: 'No bookmarks found',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount: filteredBookmarks.length,
          itemBuilder: (context, index) {
            final b = filteredBookmarks[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: Color(_parseColor(b.colorHex))
                  .withOpacity(0.55), // More visible color
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  widget.controller.navigateToVerse(b.surahId, b.ayahId);
                  Navigator.pop(context);
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(_parseColor(
                              b.colorHex)), // Full color for icon background
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(_parseColor(b.colorHex))
                                  .withOpacity(0.35),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.bookmark,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${surah[b.surahId - 1]['name']} • ${b.surahId}:${b.ayahId}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getVerseTextCached(b.surahId, b.ayahId),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkFilterRow() {
    const colors = {
      'Red': '#EF5350',
      'Yellow': '#FFB300',
      'Green': '#66BB6A',
      'Blue': '#42A5F5'
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: colors.entries.map((e) {
          final isSelected = _selectedBookmarkColor == e.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(e.key),
              selected: isSelected,
              onSelected: (val) =>
                  setState(() => _selectedBookmarkColor = val ? e.value : null),
              selectedColor: Color(_parseColor(e.value)).withOpacity(0.3),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotesTab() {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.search,
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _noteSearchController,
                    decoration: const InputDecoration(
                      hintText: 'Search notes...',
                      border: InputBorder.none,
                      isDense: true,
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
              if (notes.isEmpty) {
                return _buildEmptyState(
                    icon: Icons.note_alt_outlined, message: 'No notes found');
              }
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

  int _parseColor(String hexColor) {
    hexColor = hexColor.replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF$hexColor'; // Add alpha if missing
    }
    return int.parse(hexColor, radix: 16);
  }

  void _onNoteSearchChanged(String query, BookmarkNotesNotifier state) async {
    setState(() {
      _isSearchingNotes = true;
    });
    // Simulate search delay or perform actual search
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
