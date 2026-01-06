import 'package:flutter/material.dart';
import 'package:quran_app/data/repositories/search_repository.dart';
import 'package:quran_app/features/mushaf/screens/verse_details_screen.dart';
import 'package:quran_app/core/ui/glassmorphic_card.dart';
import 'package:quran_app/core/ui/loading_indicator.dart';
import 'package:quran_app/core/ui/empty_state.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)?.translate('search_results') ??
                'Search Results'),
            Text(
              '"${widget.query}"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size(double.infinity, 52),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withOpacity(0.3),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorWeight: 3,
              indicatorColor: theme.colorScheme.primary,
              labelColor: theme.colorScheme.primary,
              unselectedLabelColor:
                  theme.colorScheme.onSurface.withOpacity(0.6),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
              tabs: [
                _buildTab(
                    Icons.text_fields_rounded,
                    AppLocalizations.of(context)?.translate('tab_arabic') ??
                        'Arabic'),
                _buildTab(
                    Icons.translate_rounded,
                    AppLocalizations.of(context)
                            ?.translate('tab_translations') ??
                        'Translations'),
                _buildTab(
                    Icons.menu_book_rounded,
                    AppLocalizations.of(context)?.translate('tab_tafsir') ??
                        'Tafsir'),
                _buildTab(
                    Icons.label_rounded,
                    AppLocalizations.of(context)?.translate('tab_topics') ??
                        'Topics'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _runSearch,
            tooltip:
                AppLocalizations.of(context)?.translate('refresh') ?? 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const ModernLoadingIndicator()
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

  Widget _buildTab(IconData icon, String label) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildList(SearchType type) {
    final theme = Theme.of(context);
    final items = _results.where((r) => r.type == type).toList();

    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: AppLocalizations.of(context)?.translate('no_results') ??
            'No Results Found',
        message: AppLocalizations.of(context)?.translate('search_hint_sub') ??
            'Try different keywords or filters',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final r = items[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GlassmorphicCard(
            blur: 10.0,
            opacity: 0.08,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _openVerse(r.surah, r.ayah),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Verse text
                    Text(
                      r.text,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: type == SearchType.arabic ? 20 : 16,
                        height: 1.8,
                      ),
                      textAlign: type == SearchType.arabic
                          ? TextAlign.right
                          : TextAlign.left,
                    ),
                    const SizedBox(height: 12),
                    // Reference and source
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (AppLocalizations.of(context)
                                        ?.translate('surah_ref') ??
                                    'Surah {surah}:{ayah}')
                                .replaceAll('{surah}', '${r.surah}')
                                .replaceAll('{ayah}', '${r.ayah}'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (r.source != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.source!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopics() {
    final theme = Theme.of(context);
    // Basic placeholder; integrate with thematic index provider later
    final topics = {
      'Faith': 'Verses related to belief and creed',
      'Prayer': 'Obligations and etiquettes of Salah',
      'Charity': 'Zakat and voluntary giving',
      'Patience': 'Perseverance and trust in Allah',
    };

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: topics.length,
      itemBuilder: (context, index) {
        final k = topics.keys.elementAt(index);
        final v = topics[k]!;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: GlassmorphicCard(
            blur: 10.0,
            opacity: 0.08,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.label_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openVerse(int surah, int ayah) async {
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            VerseDetailsScreen(
          surahNumber: surah,
          ayahNumber: ayah,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null && result is Map<String, int> && mounted) {
      Navigator.pop(context, result);
    }
  }
}
