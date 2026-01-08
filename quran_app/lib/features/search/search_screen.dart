import 'package:flutter/material.dart';
import 'package:quran_app/data/repositories/search_repository.dart';

import 'package:quran_app/core/ui/glassmorphic_card.dart';
import 'package:quran_app/core/ui/loading_indicator.dart';
import 'package:quran_app/core/ui/empty_state.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/utils/arabic_normalizer.dart';

class SearchScreen extends StatefulWidget {
  final String query;
  final SearchFilters? filters;

  const SearchScreen({super.key, required this.query, this.filters});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  bool _loading = false;
  bool _searching = false;
  List<SearchResultItem> _results = [];
  List<String> _suggestions = [];
  List<String> _history = [];
  final _repo = SearchRepository.instance;

  int _page = 0;
  static const int _pageSize = 20;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.query;
    _scrollController.addListener(_onScroll);
    _loadHistory();
    if (widget.query.isNotEmpty) {
      _runSearch(initial: true);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _runSearch();
    }
  }

  Future<void> _loadHistory() async {
    final history = await _repo.getSearchHistory();
    setState(() => _history = history);
  }

  Future<void> _runSearch({bool initial = false}) async {
    if (initial) {
      setState(() {
        _results = [];
        _page = 0;
        _hasMore = true;
        _searching = true;
      });
    }

    if (_loading || !_hasMore) return;

    setState(() => _loading = true);
    final res = await _repo.search(
      _searchController.text,
      filters: widget.filters,
      limit: _pageSize,
      offset: _page * _pageSize,
    );

    setState(() {
      _results.addAll(res);
      _loading = false;
      _searching = false;
      _page++;
      if (res.length < _pageSize) _hasMore = false;
    });
  }

  Future<void> _updateSuggestions(String val) async {
    if (val.isEmpty) {
      await _loadHistory();
      setState(() => _suggestions = []);
      return;
    }
    final suggestions = await _repo.suggestions(val);
    setState(() => _suggestions = suggestions);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFocused = _focusNode.hasFocus;
    // Show suggestions if focused OR if we have text but haven't executed a full search yet
    final showSuggestions = isFocused ||
        (_searchController.text.isNotEmpty && _results.isEmpty && !_searching);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildSearchBar(context),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: showSuggestions ? _buildSuggestionsList() : _buildResultsBody(),
    );
  }

  Widget _buildSuggestionsList() {
    final showHistory = _searchController.text.isEmpty;
    final items = showHistory ? _history : _suggestions;

    if (items.isEmpty) {
      // Optional: show "Type to search..." placeholder if needed
      return const SizedBox.shrink();
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (context, index) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Theme.of(context).dividerColor.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final item = items[index];
          final isHistory = showHistory;
          return ListTile(
            leading: Icon(
              isHistory ? Icons.history_rounded : Icons.search_rounded,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
              size: 22,
            ),
            title: Text(
              item,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            onTap: () {
              _searchController.text = item;
              _runSearch(initial: true);
              _focusNode.unfocus();
            },
            trailing: isHistory
                ? Icon(Icons.north_west_rounded,
                    size: 16, color: Theme.of(context).disabledColor)
                : null,
          );
        },
      ),
    );
  }

  Widget _buildResultsBody() {
    if (_searching) {
      return Container(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.7),
        child: const ModernLoadingIndicator(),
      );
    }

    if (_results.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildUnifiedList();
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.onSurface.withOpacity(0.05),
          ),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _updateSuggestions,
          onSubmitted: (v) {
            _runSearch(initial: true);
            _focusNode.unfocus();
          },
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)?.translate('search_hint') ??
                'Search Quran...',
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _updateSuggestions('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildUnifiedList() {
    final theme = Theme.of(context);

    // We display all results in a single list
    if (_results.isEmpty && !_loading) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: AppLocalizations.of(context)?.translate('no_results') ??
            'No Results Found',
        message: AppLocalizations.of(context)?.translate('search_hint_sub') ??
            'Try different keywords',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _results.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final r = _results[index];
        return _buildResultItem(r);
      },
    );
  }

  Widget _buildResultItem(SearchResultItem r) {
    if (r.type == SearchType.topic) {
      // Special rendering for topic if needed, or normal item
      // We can treat topics similarly or give them a distinct look
    }

    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
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
          child: Container(
            decoration: r.type == SearchType.navigation
                ? BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  )
                : null,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Verse text with highlighting
                if (r.type == SearchType.navigation)
                  Row(
                    children: [
                      Icon(Icons.directions_run_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        r.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  _buildHighlightedText(
                    r.text,
                    _searchController.text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: r.type == SearchType.arabic ? 20 : 16,
                      height: 1.8,
                    ),
                    textAlign: r.type == SearchType.arabic
                        ? TextAlign.right
                        : TextAlign.left,
                    isArabic: r.type == SearchType.arabic,
                  ),
                if (r.type != SearchType.navigation) ...[
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
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.6),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query, {
    required TextStyle? style,
    required TextAlign textAlign,
    bool isArabic = false,
  }) {
    if (query.isEmpty) return Text(text, style: style, textAlign: textAlign);

    final normalizedText = isArabic ? ArabicNormalizer.normalize(text) : text;
    final normalizedQuery =
        isArabic ? ArabicNormalizer.normalize(query) : query;

    final List<TextSpan> spans = [];
    final lowerText = normalizedText.toLowerCase();
    final lowerQuery = normalizedQuery.toLowerCase();

    int start = 0;
    int indexOfMatch;

    while (true) {
      indexOfMatch = lowerText.indexOf(lowerQuery, start);
      if (indexOfMatch == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }

      final matchText =
          text.substring(indexOfMatch, indexOfMatch + query.length);
      spans.add(TextSpan(
        text: matchText,
        style: style?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
      ));

      start = indexOfMatch + query.length;
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
      textAlign: textAlign,
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  void _openVerse(int surah, int ayah) {
    // Return the selected verse to the calling screen (typically MushafScreen)
    Navigator.of(context).pop({'surah': surah, 'ayah': ayah});
  }
}
