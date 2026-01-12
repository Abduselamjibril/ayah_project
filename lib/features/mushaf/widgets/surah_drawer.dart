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
  int _selectedTabIndex = 0; // 0: Surah, 1: Bookmarks, 2: Khatmah, 3: Notes
  final TextEditingController _noteSearchController = TextEditingController();
  List<NoteModel> _noteResults = [];
  bool _isSearchingNotes = false;
  NavigationMode _navigationMode = NavigationMode.surah;
  final Map<int, String> _verseTextCache = {};

  @override
  void dispose() {
    _noteSearchController.dispose();
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

  // Sidebar for Surah numbers with scroll/jump effect
  Widget _buildSurahSidebar(BuildContext context) {
    return Container(
      width: 26,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          bottomLeft: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 1.5,
            offset: const Offset(-1, 0),
          ),
        ],
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) => true,
        child: ListView.builder(
          itemCount: surah.length,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemBuilder: (context, index) {
            final isSelected = false; // Optionally highlight current
            return GestureDetector(
              onTap: () {
                widget.controller.navigateToSurah(index + 1);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                width: 22,
                height: 22,
                child: Center(
                  child: Text(
                    (index + 1).toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Increase drawer width to 85% of screen width (max 380px) for better content visibility
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.95).clamp(280.0, 380.0);

    return Drawer(
      width: drawerWidth,
      child: Stack(
        children: [
          Column(
            children: [
              // Only show header on Surah tab
              if (_selectedTabIndex == 0) _buildTopBar(context),
              Expanded(child: _buildCurrentTab()),
              _buildBottomBar(context),
            ],
          ),
          // Sidebar overlay for Surah numbers (only in Surah mode)
          if (_selectedTabIndex == 0 && _navigationMode == NavigationMode.surah)
            Positioned(
              top: 80, // below top bar
              right: 0,
              bottom: 60, // above bottom bar
              child: _buildSurahSidebar(context),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Surah/Juz toggle centered, 'Al-Quran' left-aligned below
    return Padding(
      padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTopToggleButton(
                    label:
                        AppLocalizations.of(
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
                    label:
                        AppLocalizations.of(context)?.translate('toggle_juz') ??
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
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.translate('drawer_title') ??
                'Al-Quran',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  // Drawer header removed, replaced by _buildTopBar

  Widget _buildCurrentTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSurahList();
      case 1:
        return _buildBookmarksList();
      case 2:
        return KhatmahTab(controller: widget.controller);
      case 3:
        return _buildNotesTab();
      default:
        return _buildSurahList();
    }
  }

  String _getLocalizedSurahName(Map<String, dynamic> surahInfo) {
    // If context is not available for some reason, fallback
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
    return _navigationMode == NavigationMode.surah
        ? ListView.builder(
            itemCount: surah.length,
            itemBuilder: (context, index) =>
                _buildSurahItem(index + 1, surah[index]),
          )
        : ListView.builder(
            itemCount: juz.length,
            itemBuilder: (context, index) => _buildJuzItem(juz[index]),
          );
  }

  Widget _buildSurahItem(int surahNumber, Map<String, dynamic> surahInfo) {
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
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          surahNumber.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // _buildSurahAvatar removed, replaced by _buildSurahCircleAvatar

  Widget _buildJuzItem(Map<String, dynamic> juzInfo) {
    final juzNumber = juzInfo['id'] as int;
    final surahs = juzInfo['surahs'] as List<dynamic>;
    final startingSurah = surahs.first as int;
    final surahInfo = surah[startingSurah - 1];
    final surahName = _getLocalizedSurahName(surahInfo);
    return ListTile(
      leading: _buildSurahCircleAvatar(juzNumber, context),
      title: Text(
        '${AppLocalizations.of(context)?.translate('juz_prefix') ?? 'Juz'} $juzNumber',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      subtitle: Text(surahName, style: const TextStyle(fontSize: 13)),
      onTap: () {
        widget.controller.navigateToSurah(startingSurah);
        Navigator.pop(context);
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildJuzAvatar(int juzNumber, BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          juzNumber.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // Navigation toggle moved to top bar

  // ToggleButton removed, replaced by _buildTopToggleButton
  Widget _buildBottomBar(BuildContext context) {
    // This is the BottomNavigationBar for the four tabs
    return SafeArea(
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedTabIndex,
        onTap: (index) {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        selectedItemColor: const Color(0xFF388E3C),
        unselectedItemColor: const Color(0xFF388E3C),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF388E3C)),
            label:
                AppLocalizations.of(context)?.translate('tab_surah') ??
                'Contents',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.bookmark, color: Color(0xFF388E3C)),
            label:
                AppLocalizations.of(context)?.translate('tab_bookmarks') ??
                'Khatmah',
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xFF388E3C),
            ),
            label:
                AppLocalizations.of(context)?.translate('tab_khatmah') ??
                'Bookmarks',
          ),
          BottomNavigationBarItem(
            icon: const Icon(
              Icons.sticky_note_2_outlined,
              color: Color(0xFF388E3C),
            ),
            label:
                AppLocalizations.of(context)?.translate('tab_notes') ??
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
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        if (state.bookmarks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border,
            message:
                AppLocalizations.of(context)?.translate('no_bookmarks') ??
                'No bookmarks yet',
          );
        }

        return ListView.builder(
          itemCount: state.bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = state.bookmarks[index];
            final surahName = surah[bookmark.surahId - 1]['name'] ?? 'Surah';
            final verseText = _getVerseTextCached(
              bookmark.surahId,
              bookmark.ayahId,
            );

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: Color(
                  _parseColor(bookmark.colorHex),
                ).withOpacity(0.2),
                child: Icon(
                  bookmark.isKhatmahPin ? Icons.push_pin : Icons.bookmark,
                  color: Color(_parseColor(bookmark.colorHex)),
                ),
              ),
              title: Text(
                '$surahName • ${bookmark.surahId}:${bookmark.ayahId}',
              ),
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
                  if (bookmark.categoryName != null &&
                      bookmark.categoryName!.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(
                          _parseColor(bookmark.colorHex),
                        ).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Color(
                            _parseColor(bookmark.colorHex),
                          ).withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        bookmark.categoryName!.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(_parseColor(bookmark.colorHex)),
                        ),
                        // Show full text without truncation
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => state.toggleBookmark(
                  surahId: bookmark.surahId,
                  ayahId: bookmark.ayahId,
                ),
              ),
              onTap: () {
                widget.controller.navigateToVerse(
                  bookmark.surahId,
                  bookmark.ayahId,
                );
                Navigator.pop(context);
              },
            );
          },
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
            message:
                AppLocalizations.of(context)?.translate('no_notes') ??
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
                  hintText:
                      AppLocalizations.of(
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
                            maxLines: 4, // Increased from 2 to 4 lines
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
      return int.parse('FFFFC107', radix: 16); // Amber fallback
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
