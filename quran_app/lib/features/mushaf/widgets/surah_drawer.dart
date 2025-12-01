import 'package:flutter/material.dart';
import '../controller/mushaf_controller.dart';
import '../../../core/quran/data/suwar.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer header with tabs
          Container(
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
                    unselectedLabelColor: Theme.of(context)
                        .colorScheme
                        .onPrimary
                        .withOpacity(0.6),
                    tabs: const [
                      Tab(text: 'Surah'),
                      Tab(text: 'Bookmarks'),
                      Tab(text: 'More'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSurahList(),
                _buildBookmarksList(),
                _buildMoreTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    return ListView.builder(
      itemCount: 114,
      itemBuilder: (context, index) {
        final surahNumber = index + 1;
        final surahInfo = surah[index]; // Get from suwar.dart

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
            child: Text(
              '$surahNumber',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          title: Text(
            '${surahInfo['name']}',
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
            surahInfo['arabic'],
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          onTap: () {
            widget.onSurahSelected(surahNumber);
            Navigator.pop(context); // Close the drawer
          },
        );
      },
    );
  }

  Widget _buildBookmarksList() {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final bookmarks = widget.controller.bookmarkedVerses;

        if (bookmarks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 64,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No bookmarks yet',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: bookmarks.length,
          itemBuilder: (context, index) {
            final verseKey = bookmarks.elementAt(index);
            final parts = verseKey.split(':');
            final surah = int.parse(parts[0]);
            final verse = int.parse(parts[1]);

            return ListTile(
              leading: const Icon(Icons.bookmark),
              title: Text('Surah $surah, Verse $verse'),
              trailing: IconButton(
                icon: const Icon(Icons.bookmark_remove),
                onPressed: () {
                  widget.controller.toggleBookmark(surah, verse);
                },
              ),
              onTap: () {
                widget.onSurahSelected(surah);
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildMoreTab() {
    return Center(
      child: Text(
        'More features coming soon...',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          fontSize: 16,
        ),
      ),
    );
  }
}
