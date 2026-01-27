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
    return Container(
      padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
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
                child: selectedTabIndex == 2
                    ? TextButton(
                        onPressed: onEditBookmarks,
                        style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft),
                        child: Text(
                          isEditingBookmarks ? 'Done' : 'Edit',
                          style: const TextStyle(
                              color: Color(0xFF689F38),
                              fontWeight: FontWeight.bold),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Center: Surah/Juz toggle, slightly left of true center
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
              else
                const SizedBox.shrink(),
              // Fill remaining space if toggle not shown
              if (selectedTabIndex != 0) Expanded(child: Container()),
              // Right: Back button
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.chevron_right,
                      color: Color(0xFF689F38), size: 28),
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
    return SizedBox(
      width: 180,
      child: Container(
        height: 34,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: const Color(0xFFDCDCDC),
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
          color: isSelected ? Colors.white : Colors.transparent,
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
            color: isSelected ? Colors.black : Colors.black54,
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

  final ScrollController _drawerScrollController = ScrollController();
  final Map<int, GlobalKey> _juzHeaderKeys = {};
  final Map<int, GlobalKey> _juzItemKeys = {};

  final Map<String, TextEditingController> _categoryEditControllers = {};

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
    for (var controller in _categoryEditControllers.values) {
      controller.dispose();
    }
    _noteSearchController.dispose();
    _drawerScrollController.dispose();
    super.dispose();
  }

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

  String _getLatestBookmarkSubtitle(Bookmark? b) {
    if (b == null) return "No bookmarks found";
    final hour = b.createdAt.hour > 12
        ? b.createdAt.hour - 12
        : (b.createdAt.hour == 0 ? 12 : b.createdAt.hour);
    final minute = b.createdAt.minute.toString().padLeft(2, '0');
    final isNight = b.createdAt.hour >= 18 || b.createdAt.hour < 5;
    final timeStr = "$hour:$minute ${isNight ? 'at night' : 'at morning'}";
    final surahName = surah[b.surahId - 1]['name'];
    return "$timeStr $surahName: ${b.ayahId}";
  }

  Widget _buildNumberSidebar(
      {required int itemCount,
      required void Function(int number) onTapNumber}) {
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
              padding: const EdgeInsets.symmetric(vertical: 1.5),
              child: Center(
                child: Text(
                  number.toString(),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: Color(0xFF4CAF50)),
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
            onEditBookmarks: () {
              if (_isEditingBookmarks) {
                final state = context.read<BookmarkNotesNotifier>();
                _categoryEditControllers.forEach((color, ctrl) =>
                    state.updateCategoryName(color, ctrl.text));
              }
              setState(() => _isEditingBookmarks = !_isEditingBookmarks);
            },
          ),
          // Heading with reduced top and bottom space
          Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 24, top: 2, bottom: 0),
            child: Text(
              tabTitles[_selectedTabIndex],
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontSize: 34,
                  ),
            ),
          ),
          // Add a small space below the tab heading and above PART 1
          if (_selectedTabIndex == 0) const SizedBox(height: 8),
          Expanded(
            child: _selectedTabIndex == 0
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      const double sidebarWidth = 22 + 12;
                      EdgeInsets contentPadding =
                          textDirection == TextDirection.rtl
                              ? const EdgeInsets.only(left: sidebarWidth)
                              : const EdgeInsets.only(right: sidebarWidth);
                      return Stack(
                        children: [
                          Padding(
                              padding: contentPadding,
                              child: _buildCurrentTab()),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right:
                                textDirection == TextDirection.rtl ? null : 8,
                            left: textDirection == TextDirection.rtl ? 8 : null,
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: _buildNumberSidebar(
                                itemCount: juz.length,
                                onTapNumber: (number) {
                                  if (_navigationMode == NavigationMode.surah) {
                                    _scrollToJuzInSurahList(number);
                                  } else {
                                    _scrollToJuzItem(number);
                                  }
                                },
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
                height: 1, indent: 76, color: Colors.grey.withOpacity(0.1)),
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
      padding: EdgeInsets.zero,
      controller: _drawerScrollController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        if (entry.isHeader) {
          _juzHeaderKeys.putIfAbsent(entry.juzNumber, () => GlobalKey());
          // Reduced top padding (16) and bottom padding (4) for tight spacing
          return Container(
            key: _juzHeaderKeys[entry.juzNumber],
            padding: EdgeInsets.fromLTRB(24, index == 0 ? 20 : 16, 16, 4),
            child: Text(
              'PART ${entry.juzNumber}',
              style: const TextStyle(
                  fontSize: 12,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
          );
        }
        final surahInfo = entry.surahInfo!;
        return Column(
          children: [
            _buildSurahItem(surahInfo['id'], surahInfo),
            if (index < entries.length - 1 && !entries[index + 1].isHeader)
              Divider(
                  height: 1, indent: 84, color: Colors.grey.withOpacity(0.1)),
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
    String surahName = _getLocalizedSurahName(surahInfo);
    int startPage = _surahStartPages[surahNumber] ?? (surahNumber * 10);
    String place = surahInfo['place'] == 'Makkah' ? 'Meccan' : 'Medinan';
    String subtitle = 'Page $startPage - ${surahInfo['aya']} verses - $place';

    return ListTile(
      // Reduced vertical padding to match screenshot denseness
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
      leading: _buildSurahCircleAvatar(surahNumber, context),
      title: Text(surahName,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
      subtitle: Text(subtitle,
          style:
              const TextStyle(fontSize: 12, color: Colors.grey, height: 1.2)),
      onTap: () {
        widget.controller.navigateToSurah(surahNumber);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSurahCircleAvatar(int number, BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        shape: BoxShape.circle,
      ),
      child: Center(
          child: Text(number.toString(),
              style: const TextStyle(
                  color: Colors.black87,
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
      title: Text('PART $juzNumber',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
      subtitle: Text(_getLocalizedSurahName(surah[startingSurah - 1]),
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
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

  Widget _buildBottomBar(BuildContext context) {
    const activeColor = Color(0xFF2E7D32);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, -2), // Shadow on top to separate from page
          ),
        ],
      ),
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
              label: AppLocalizations.of(context)?.translate('tab_contents') ??
                  'Contents'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.check_circle_rounded, size: 28),
              label: AppLocalizations.of(context)?.translate('tab_khatmah') ??
                  'Khatmah'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.bookmark_rounded, size: 28),
              label: AppLocalizations.of(context)?.translate('tab_bookmarks') ??
                  'Bookmarks'),
          BottomNavigationBarItem(
              icon: const Icon(Icons.edit_rounded, size: 28),
              label: AppLocalizations.of(context)?.translate('tab_notes') ??
                  'Highlights'),
        ],
      ),
    );
  }

  Widget _buildBookmarksList() {
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        final categoryMap = state.categoryNames;
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: categoryMap.entries.map((entry) {
                    final colorHex = entry.key;
                    final displayName = entry.value;
                    final latest = state.bookmarks
                        .where((b) =>
                            b.colorHex.toUpperCase() == colorHex.toUpperCase())
                        .firstOrNull;

                    if (!_categoryEditControllers.containsKey(colorHex)) {
                      _categoryEditControllers[colorHex] =
                          TextEditingController(text: displayName);
                    }

                    return Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Icon(Icons.bookmark,
                              color: Color(
                                  int.parse(colorHex.replaceAll('#', '0xFF'))),
                              size: 30),
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
                              : Text(_getLatestBookmarkSubtitle(latest),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.5))),
                          trailing: const Icon(Icons.chevron_right,
                              color: Color(0xFF689F38), size: 26),
                          onTap: _isEditingBookmarks
                              ? null
                              : () {
                                  if (latest != null) {
                                    widget.controller.navigateToVerse(
                                        latest.surahId, latest.ayahId);
                                    Navigator.pop(context);
                                  }
                                },
                        ),
                        if (entry.key != categoryMap.keys.last)
                          Divider(
                              height: 1,
                              indent: 60,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.08)),
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12)),
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
                        isDense: true),
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
                    icon: Icons.note_alt_outlined, message: 'No notes found');
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
