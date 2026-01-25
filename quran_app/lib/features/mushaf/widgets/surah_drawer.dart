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
  final Map<int, String> _verseTextCache = {};
  bool _isEditingBookmarks = false;
  // Controller and keys for scrolling within the drawer list
  final ScrollController _drawerScrollController = ScrollController();
  final Map<int, GlobalKey> _juzHeaderKeys = {};
  final Map<int, GlobalKey> _juzItemKeys = {};

  @override
  void dispose() {
    _noteSearchController.dispose();
    _drawerScrollController.dispose();
    super.dispose();
  }

  String _getVerseTextCached(int surahId, int ayahId) {
    final key = (surahId * 1000) + ayahId;
    final cached = _verseTextCache[key];
    if (cached != null) return cached;
    final verseText = getVerse(surahId, ayahId, verseEndSymbol: true);
    _verseTextCache[key] = verseText;
    return verseText;
  }

  // Compact sidebar for quick Surah/Juz jumps (Your UI feature from HEAD)
  Widget _buildNumberSidebar({
    required int itemCount,
    required void Function(int number) onTapNumber,
  }) {
    return SizedBox(
      width: 18,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        padding: const EdgeInsets.symmetric(vertical: 1),
        itemBuilder: (context, index) {
          final number = index + 1;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              // Scroll within the drawer list; do not close the drawer
              onTapNumber(number);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 0.5),
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
    final mediaQuery = MediaQuery.of(context);
    final drawerWidth = mediaQuery.size.width;
    final double sidebarRightInset = 6;

    // Place sidebar inside content area: under app bar and above bottom nav
    return Drawer(
      width: drawerWidth,
      child: Column(
        children: [
          if (_selectedTabIndex == 0) _buildTopBar(context),
          Expanded(
            child: _selectedTabIndex == 0
                ? Stack(
                    children: [
                      _buildCurrentTab(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: sidebarRightInset),
                          child: _navigationMode == NavigationMode.surah
                              ? _buildNumberSidebar(
                                  itemCount: juz.length,
                                  onTapNumber: (number) {
                                    _scrollToJuzInSurahList(number);
                                  },
                                )
                              : _buildNumberSidebar(
                                  itemCount: juz.length,
                                  onTapNumber: (number) {
                                    _scrollToJuzItem(number);
                                  },
                                ),
                        ),
                      ),
                    ],
                  )
                : _buildCurrentTab(),
          ),
          _buildBottomBar(context),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Your custom top bar UI from HEAD
    final double topInset = MediaQuery.of(context).viewPadding.top;
    final double topPadding = topInset > 0 ? topInset + 8 : 32;
    final double backIconLift = topPadding - 32;
    return Padding(
      padding:
          EdgeInsets.only(top: topPadding, left: 16, right: 16, bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTopToggleButton(
                          label: AppLocalizations.of(
                                context,
                              )?.translate('toggle_surahs') ??
                              'Sūrahs',
                          isSelected: _navigationMode == NavigationMode.surah,
                          onTap: () {
                            setState(() {
                              _navigationMode = NavigationMode.surah;
                            });
                          },
                        ),
                        _buildTopToggleButton(
                          label: AppLocalizations.of(context)
                                  ?.translate('toggle_juz') ??
                              'Quarters',
                          isSelected: _navigationMode == NavigationMode.juz,
                          onTap: () {
                            setState(() {
                              _navigationMode = NavigationMode.juz;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Transform.translate(
                offset: Offset(0, -backIconLift),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.chevron_right,
                      color: BrandColors.accent,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            thickness: 0.8,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
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

  Widget _buildCurrentTab() {
    // Your tab logic from HEAD, tied to your bottom nav bar
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

  String _getLocalizedSurahName(Map<String, dynamic> surahInfo) {
    if (!mounted) return surahInfo['name'];
    final locale = AppLocalizations.of(context)?.locale.languageCode;
    if (locale == 'ar' || locale == 'ur') {
      return surahInfo['arabic'] ?? surahInfo['name'];
    }
    return surahInfo['name'];
  }

  String _getLocalizedSurahMeaning(Map<String, dynamic> surahInfo) {
    if (!mounted) return surahInfo['english'] ?? '';
    int surahNumber = surahInfo['id'];
    String meaningKey = 'surah_meaning_$surahNumber';
    String? localizedMeaning = AppLocalizations.of(
      context,
    )?.translate(meaningKey);
    if (localizedMeaning != null && localizedMeaning != meaningKey) {
      return localizedMeaning;
    }
    return surahInfo['english'] ?? '';
  }

  Widget _buildSurahList() {
    // Your ListView implementation from HEAD
    return _navigationMode == NavigationMode.surah
        ? _buildSurahListGroupedByJuz()
        : ListView.separated(
            controller: _drawerScrollController,
            itemCount: juz.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 0.6,
              indent: 76,
              endIndent: 0,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
            itemBuilder: (context, index) {
              final info = juz[index];
              final juzNumber = info['id'] as int;
              _juzItemKeys.putIfAbsent(juzNumber, () => GlobalKey());
              return Container(
                key: _juzItemKeys[juzNumber],
                child: _buildJuzItem(info),
              );
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ),
          );
        }

        final surahInfo = entry.surahInfo!;
        final surahNumber = surahInfo['id'] as int;
        return Column(
          children: [
            _buildSurahItem(surahNumber, surahInfo),
            Divider(
              height: 1,
              thickness: 0.6,
              indent: 76,
              endIndent: 0,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
          ],
        );
      },
    );
  }

  void _scrollToJuzInSurahList(int juzNumber) {
    final entries = _buildSurahEntries();
    final index = entries.indexWhere(
      (e) => e.isHeader && e.juzNumber == juzNumber,
    );
    if (index == -1) return;

    // Try precise scroll if the header is already built
    final key = _juzHeaderKeys[juzNumber];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      return;
    }

    // Fallback: approximate scroll by index
    const double itemExtent = 76.0; // avg combined height of header/items
    _drawerScrollController.animateTo(
      index * itemExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _scrollToJuzItem(int juzNumber) {
    final juzIndex = juz.indexWhere((j) => j['id'] == juzNumber);
    if (juzIndex == -1) return;

    final key = _juzItemKeys[juzNumber];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
      return;
    }

    const double itemExtent = 76.0;
    _drawerScrollController.animateTo(
      juzIndex * itemExtent,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  List<_SurahListEntry> _buildSurahEntries() {
    final List<_SurahListEntry> entries = [];
    for (final juzInfo in juz) {
      final juzNumber = juzInfo['id'] as int;
      entries.add(_SurahListEntry.header(juzNumber));
      final surahsInJuz = (juzInfo['surahs'] as List<dynamic>?) ?? [];
      for (final s in surahsInJuz) {
        final surahNumber = s as int;
        final surahInfo = surah[surahNumber - 1];
        entries.add(_SurahListEntry.surah(juzNumber, surahInfo));
      }
    }
    return entries;
  }

  Widget _buildSurahItem(int surahNumber, Map<String, dynamic> surahInfo) {
    // Your custom Surah item styling from HEAD
    String surahName = _getLocalizedSurahName(surahInfo);
    String surahMeaning = _getLocalizedSurahMeaning(surahInfo);
    String versesText =
        AppLocalizations.of(context)?.translate('verses_suffix') ?? 'verses';
    String subtitle = surahMeaning.isNotEmpty
        ? '$surahMeaning • ${surahInfo['aya']} $versesText'
        : '${surahInfo['aya']} $versesText';
    return ListTile(
      leading: _buildSurahCircleAvatar(surahNumber, context),
      title: Text(
        surahName,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
          ),
        ),
      ),
      onTap: () {
        widget.controller.navigateToSurah(surahNumber);
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildSurahCircleAvatar(int surahNumber, BuildContext context) {
    // Your custom circular avatar styling from HEAD
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          surahNumber.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildJuzItem(Map<String, dynamic> juzInfo) {
    // Your custom Juz item styling from HEAD
    final juzNumber = juzInfo['id'] as int;
    final surahs = juzInfo['surahs'] as List<dynamic>;
    final startingSurah = surahs.first as int;
    final surahInfo = surah[startingSurah - 1];
    final surahName = _getLocalizedSurahName(surahInfo);
    return ListTile(
      leading: _buildSurahCircleAvatar(juzNumber, context),
      title: Text(
        '${AppLocalizations.of(context)?.translate('juz_prefix') ?? 'Juz'} $juzNumber',
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(surahName, style: const TextStyle(fontSize: 12)),
      ),
      onTap: () {
        widget.controller.navigateToSurah(startingSurah);
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // Keep original theme color and restore elevation-based shadow
    final theme = Theme.of(context);
    final Color navBg = theme.bottomNavigationBarTheme.backgroundColor ??
        theme.colorScheme.surface;
    final double navElevation = theme.bottomNavigationBarTheme.elevation ?? 8.0;

    return SafeArea(
      top: false,
      bottom: false,
      minimum: EdgeInsets.zero,
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: navBg,
        elevation: navElevation,
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        selectedItemColor: BrandColors.accent,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_rounded),
            label: AppLocalizations.of(context)?.translate('tab_surah') ??
                'Contents',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.check_circle_outline),
            label: AppLocalizations.of(context)?.translate('tab_khatmah') ??
                'Khatmah',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark),
            label: AppLocalizations.of(context)?.translate('tab_bookmarks') ??
                'Bookmarks',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.sticky_note_2_outlined),
            label: AppLocalizations.of(context)?.translate('tab_notes') ??
                'Highlights',
          ),
        ],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        showUnselectedLabels: true,
      ),
    );
  }

  Widget _buildBookmarksList() {
    // Your advanced bookmarks tab UI from HEAD
    const brandGreen = BrandColors.accent;
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        final header = Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              TextButton(
                onPressed: () {
                  setState(() => _isEditingBookmarks = !_isEditingBookmarks);
                },
                style: TextButton.styleFrom(
                  foregroundColor: brandGreen,
                  padding: EdgeInsets.zero,
                  textStyle: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                child: Text(_isEditingBookmarks ? 'Done' : 'Edit'),
              ),
              const Spacer(),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_forward_ios,
                      size: 18, color: brandGreen),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ],
          ),
        );

        final title = Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            'Bookmarks',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );

        final categories = Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 56,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
            itemBuilder: (context, index) {
              const labels = ['Red', 'Yellow', 'Green', 'Blue'];
              const colors = [0xFFF44336, 0xFFFFC107, 0xFF4CAF50, 0xFF2196F3];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                leading: Icon(
                  Icons.bookmark_border_rounded,
                  color: Color(colors[index]),
                  size: 24,
                ),
                title: Text(
                  labels[index],
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                onTap: () {},
              );
            },
          ),
        );

        Widget bookmarksSection;
        if (state.bookmarks.isEmpty) {
          bookmarksSection = Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: _buildEmptyState(
              icon: Icons.bookmark_border,
              message:
                  AppLocalizations.of(context)?.translate('no_bookmarks') ??
                      'No bookmarks yet',
            ),
          );
        } else {
          bookmarksSection = ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.bookmarks.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 72,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
            itemBuilder: (context, index) {
              final bookmark = state.bookmarks[index];
              final surahName = surah[bookmark.surahId - 1]['name'] ?? 'Surah';
              final verseText =
                  _getVerseTextCached(bookmark.surahId, bookmark.ayahId);
              final color = Color(_parseColor(bookmark.colorHex));

              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                leading: Icon(
                  bookmark.isKhatmahPin
                      ? Icons.push_pin
                      : Icons.bookmark_outline_rounded,
                  color: color,
                ),
                title: Text(
                  '$surahName • ${bookmark.surahId}:${bookmark.ayahId}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                subtitle: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text(
                    verseText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                trailing: _isEditingBookmarks
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => state.toggleBookmark(
                          surahId: bookmark.surahId,
                          ayahId: bookmark.ayahId,
                        ),
                      )
                    : null,
                onTap: () {
                  widget.controller
                      .navigateToVerse(bookmark.surahId, bookmark.ayahId);
                  Navigator.pop(context);
                },
              );
            },
          );
        }

        return ListView(
          children: [
            header,
            title,
            categories,
            const SizedBox(height: 16),
            bookmarksSection,
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildNotesTab() {
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        final notes = _noteSearchController.text.trim().isNotEmpty
            ? _noteResults
            : state.notes;
        if (notes.isEmpty && !_isSearchingNotes) {
          return _buildEmptyState(
            icon: Icons.note_alt_outlined,
            message: AppLocalizations.of(context)?.translate('no_notes') ??
                'No notes yet',
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _noteSearchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: AppLocalizations.of(
                        context,
                      )?.translate('search_notes_hint') ??
                      'Search notes',
                  suffixIcon: _noteSearchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _noteSearchController.clear();
                            setState(() => _noteResults = []);
                          },
                        )
                      : null,
                ),
                onChanged: (value) => _onNoteSearchChanged(value, state),
              ),
            ),
            if (_isSearchingNotes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) {
                  final note = notes[index];
                  final surahName = surah[note.surahId - 1]['name'] ?? 'Surah';
                  final verseText = _getVerseTextCached(
                    note.surahId,
                    note.ayahId,
                  );
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: const Icon(Icons.sticky_note_2_outlined),
                    title: Text('${note.surahId}:${note.ayahId} • $surahName'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text(
                            verseText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            note.content,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          state.deleteNoteForVerse(note.surahId, note.ayahId),
                    ),
                    onTap: () {
                      widget.controller.navigateToVerse(
                        note.surahId,
                        note.ayahId,
                      );
                      Navigator.pop(context);
                    },
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: notes.length,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onNoteSearchChanged(
    String query,
    BookmarkNotesNotifier state,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _noteResults = [];
        _isSearchingNotes = false;
      });
      return;
    }
    setState(() => _isSearchingNotes = true);
    final results = await state.searchNotes(trimmed);
    if (!mounted) return;
    setState(() {
      _noteResults = results;
      _isSearchingNotes = false;
    });
  }

  int _parseColor(String value) {
    try {
      final normalized = value.replaceAll('#', '').padLeft(6, '0');
      return int.parse('FF$normalized', radix: 16);
    } catch (_) {
      return int.parse('FFFFC107', radix: 16);
    }
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurahListEntry {
  final bool isHeader;
  final int juzNumber;
  final Map<String, dynamic>? surahInfo;

  const _SurahListEntry._(this.isHeader, this.juzNumber, this.surahInfo);

  factory _SurahListEntry.header(int juzNumber) =>
      _SurahListEntry._(true, juzNumber, null);

  factory _SurahListEntry.surah(
          int juzNumber, Map<String, dynamic> surahInfo) =>
      _SurahListEntry._(false, juzNumber, surahInfo);
}
