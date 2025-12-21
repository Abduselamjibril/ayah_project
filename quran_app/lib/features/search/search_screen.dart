import 'package:flutter/material.dart';
import 'package:quran_app/data/repositories/search_repository.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';

class SearchScreen extends StatefulWidget {
  final String query;
  final SearchFilters? filters;

  const SearchScreen({super.key, required this.query, this.filters});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  List<SearchResultItem> _results = [];
  final _repo = SearchRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _runSearch();
  }

  Future<void> _runSearch() async {
    setState(() => _loading = true);
    final res = await _repo.search(widget.query, filters: widget.filters);
    setState(() {
      _results = res;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search: ${widget.query}'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Arabic'),
            Tab(text: 'Translations'),
            Tab(text: 'Tafsir'),
            Tab(text: 'Topics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _runSearch,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(SearchType.arabic),
                _buildList(SearchType.translation),
                _buildList(SearchType.tafsir),
                _buildTopics(),
              ],
            ),
    );
  }

  Widget _buildList(SearchType type) {
    final items = _results.where((r) => r.type == type).toList();
    if (items.isEmpty) {
      return const Center(child: Text('No results'));
    }
    return ListView.separated(
      itemBuilder: (context, index) {
        final r = items[index];
        return ListTile(
          title: Text(r.text, textAlign: TextAlign.right),
          subtitle: Text(
              'Surah ${r.surah}:${r.ayah}${r.source != null ? ' • ${r.source}' : ''}'),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () => _openVerse(r.surah, r.ayah),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: items.length,
    );
  }

  Widget _buildTopics() {
    // Basic placeholder; integrate with thematic index provider later
    final topics = {
      'Faith': 'Verses related to belief and creed',
      'Prayer': 'Obligations and etiquettes of Salah',
      'Charity': 'Zakat and voluntary giving',
      'Patience': 'Perseverance and trust in Allah',
    };
    return ListView.separated(
      itemBuilder: (context, index) {
        final k = topics.keys.elementAt(index);
        final v = topics[k]!;
        return ListTile(
          leading: const Icon(Icons.label_outline),
          title: Text(k),
          subtitle: Text(v),
          onTap: () {},
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemCount: topics.length,
    );
  }

  void _openVerse(int surah, int ayah) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerseDetailsScreen(
          surahNumber: surah,
          ayahNumber: ayah,
        ),
      ),
    );
  }
}
