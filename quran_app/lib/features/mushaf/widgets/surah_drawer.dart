import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/bookmarks/data/models/note.dart';
import '../controller/mushaf_controller.dart';
import '../../../core/quran/data/suwar.dart';
import '../../khatmah/widgets/khatmah_tab.dart';
import '../../../core/quran/qcf_quran.dart';
import '../../../core/quran/qcf_quran.dart';

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
  late TabController _tabController;
  final TextEditingController _noteSearchController = TextEditingController();
  List<NoteModel> _noteResults = [];
  bool _isSearchingNotes = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(child: _buildTabView()),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      color: Theme.of(context).primaryColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Al-Quran',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.onPrimary,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onPrimary.withOpacity(0.6),
              isScrollable: true,
              tabs: const [
                Tab(text: 'Surah'),
                Tab(text: 'Bookmarks'),
                Tab(text: 'Khatmah'),
                Tab(text: 'Note'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabView() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildSurahList(),
        _buildBookmarksList(),
        KhatmahTab(controller: widget.controller),
        _buildNotesTab(),
      ],
    );
  }

  Widget _buildSurahList() {
    return ListView.builder(
      itemCount: surah.length,
      itemBuilder: (context, index) => _buildSurahItem(index + 1, surah[index]),
    );
  }

  Widget _buildSurahItem(int surahNumber, Map<String, dynamic> surahInfo) {
    return ListTile(
      leading: _buildSurahAvatar(surahNumber, context),
      title: Text(
        surahInfo['name'] ?? 'Unknown',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${surahInfo['english']} • ${surahInfo['aya']} verses',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
      trailing: Text(
        surahInfo['arabic'] ?? '',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      onTap: () {
        widget.onSurahSelected(surahNumber);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSurahAvatar(int surahNumber, BuildContext context) {
    return CircleAvatar(
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
      child: Text(
        surahNumber.toString(),
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildBookmarksList() {
    return Consumer<BookmarkNotesNotifier>(
      builder: (context, state, _) {
        if (state.bookmarks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.bookmark_border,
            message: 'No bookmarks yet',
          );
        }

        return ListView.builder(
          itemCount: state.bookmarks.length,
          itemBuilder: (context, index) {
            final bookmark = state.bookmarks[index];
            final surahName = surah[bookmark.surahId - 1]['name'] ?? 'Surah';
            final verseText = getVerse(
              bookmark.surahId,
              bookmark.ayahId,
              verseEndSymbol: true,
            );

            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Color(_parseColor(bookmark.colorHex)).withOpacity(0.2),
                child: Icon(
                  bookmark.isKhatmahPin ? Icons.push_pin : Icons.bookmark,
                  color: Color(_parseColor(bookmark.colorHex)),
                ),
              ),
              title:
                  Text('$surahName • ${bookmark.surahId}:${bookmark.ayahId}'),
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
                    const SizedBox(height: 4),
                    Text(bookmark.categoryName!.trim()),
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
                widget.onSurahSelected(bookmark.surahId);
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
            message: 'No notes yet',
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
                  hintText: 'Search notes',
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
                  final verseText = getVerse(
                    note.surahId,
                    note.ayahId,
                    verseEndSymbol: true,
                  );
                  return ListTile(
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
                        const SizedBox(height: 4),
                        Text(
                          note.content,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => state.deleteNoteForVerse(
                        note.surahId,
                        note.ayahId,
                      ),
                    ),
                    onTap: () {
                      widget.onSurahSelected(note.surahId);
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
