import 'dart:collection';
import 'package:quran_app/core/database/app_database.dart';
import 'package:quran_app/core/utils/arabic_normalizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/core/quran/data/suwar.dart' as suwar_data;

/// Types of content the search can target
enum SearchType { arabic, translation, tafsir, topic, navigation }

/// Optional filters for narrowing results
class SearchFilters {
  final int? surah; // 1..114
  final (int, int)? verseRange; // (start, end)
  final Set<SearchType> types;
  final String? language; // For translation/tafsir

  const SearchFilters({
    this.surah,
    this.verseRange,
    this.types = const {
      SearchType.arabic,
      SearchType.translation,
      SearchType.tafsir
    },
    this.language,
  });

  SearchFilters copyWith({
    int? surah,
    (int, int)? verseRange,
    Set<SearchType>? types,
    String? language,
  }) {
    return SearchFilters(
      surah: surah ?? this.surah,
      verseRange: verseRange ?? this.verseRange,
      types: types ?? this.types,
      language: language ?? this.language,
    );
  }
}

/// A single search hit
class SearchResultItem {
  final SearchType type;
  final int surah;
  final int ayah;
  final String text;
  final String? source; // e.g., edition/translator/scholar

  const SearchResultItem({
    required this.type,
    required this.surah,
    required this.ayah,
    required this.text,
    this.source,
  });
}

/// Configuration for remote search providers
class SearchConfig {
  final String? elasticUrl; // e.g. https://your-elastic/_search
  final String? elasticApiKey;
  final String? quranComApiBase; // e.g. https://api.quran.com/api/v4

  const SearchConfig({
    this.elasticUrl,
    this.elasticApiKey,
    this.quranComApiBase,
  });
}

/// Repository orchestrates local and remote search providers
class SearchRepository {
  static final SearchRepository instance =
      SearchRepository._(const SearchConfig());

  final SearchConfig config;
  SearchRepository._(this.config);

  static const String _historyKey = 'search_history';
  static const int _maxHistory = 5;

  // Simple LRU caches with TTL for performance
  static const Duration _cacheTtl = Duration(minutes: 10);
  static const int _maxCacheEntries = 64;
  final LinkedHashMap<String, _CacheEntry<List<SearchResultItem>>>
      _resultCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<String>>> _suggestCache =
      LinkedHashMap();

  // Cache helpers (LRU + TTL)
  List<SearchResultItem>? _getResultCache(String key) {
    final now = DateTime.now();
    final entry = _resultCache.remove(key);
    if (entry == null) return null;
    if (now.difference(entry.ts) > _cacheTtl) return null;
    // Re-insert to mark as most-recently used
    _resultCache[key] = entry;
    return entry.data;
  }

  void _setResultCache(String key, List<SearchResultItem> value) {
    // Enforce LRU size limit
    if (_resultCache.length >= _maxCacheEntries && _resultCache.isNotEmpty) {
      final firstKey = _resultCache.keys.first;
      _resultCache.remove(firstKey);
    }
    _resultCache[key] = _CacheEntry(value);
  }

  List<String>? _getSuggestCache(String key) {
    final now = DateTime.now();
    final entry = _suggestCache.remove(key);
    if (entry == null) return null;
    if (now.difference(entry.ts) > _cacheTtl) return null;
    _suggestCache[key] = entry;
    return entry.data;
  }

  void _setSuggestCache(String key, List<String> value) {
    if (_suggestCache.length >= _maxCacheEntries && _suggestCache.isNotEmpty) {
      final firstKey = _suggestCache.keys.first;
      _suggestCache.remove(firstKey);
    }
    _suggestCache[key] = _CacheEntry(value);
  }

  /// Perform a multi-content search across Arabic, translations, tafsir, topics.
  Future<List<SearchResultItem>> search(String query,
      {SearchFilters? filters, int limit = 50, int offset = 0}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // 1. Check for Numerical Jump (FR1)
    final jump = _parseNumericalJump(trimmed);
    if (jump != null) {
      _addToHistory(trimmed);
      return [
        SearchResultItem(
          type: SearchType.navigation,
          surah: jump.$1,
          ayah: jump.$2,
          text: 'Jump to Surah ${jump.$1}, Ayah ${jump.$2}',
        )
      ];
    }

    // 2. Check for Surah Jump (Name or Number)
    final surahJump = _parseSurahJump(trimmed);
    if (surahJump != null) {
      _addToHistory(trimmed);
      return [surahJump];
    }

    final cacheKey = _searchCacheKey(trimmed, filters, limit, offset);
    final cached = _getResultCache(cacheKey);
    if (cached != null) return cached;

    _addToHistory(trimmed);

    // Fallback to local SQLite content using FTS5
    final local = await _searchLocal(trimmed,
        filters: filters, limit: limit, offset: offset);
    _setResultCache(cacheKey, local);
    return local;
  }

  (int, int)? _parseNumericalJump(String query) {
    // Matches "18:10", "18 10", "سورة 18 آية 10" etc.
    final reg = RegExp(r'(\d+)\s*[:\s-]\s*(\d+)');
    final match = reg.firstMatch(query);
    if (match != null) {
      final s = int.tryParse(match.group(1)!);
      final a = int.tryParse(match.group(2)!);
      if (s != null && s >= 1 && s <= 114 && a != null && a >= 1) {
        return (s, a);
      }
    }
    return null;
  }

  SearchResultItem? _parseSurahJump(String query) {
    // 1. Try parsing as number
    final num = int.tryParse(query);
    if (num != null && num >= 1 && num <= 114) {
      final name = suwar_data.surah.firstWhere((s) => s['id'] == num)['name'];
      return SearchResultItem(
        type: SearchType.navigation,
        surah: num,
        ayah: 1,
        text: 'Go to Surah $name',
      );
    }

    // 2. Search by name
    final q = query.toLowerCase();
    for (var s in suwar_data.surah) {
      final id = s['id'] as int;
      final name = s['name'].toString();
      final english = s['english'].toString().toLowerCase();
      final arabic = s['arabic'].toString();
      final turkish = s['turkish'].toString().toLowerCase();

      // Exact or close match
      if (name.toLowerCase() == q ||
          english == q ||
          arabic == query ||
          turkish == q) {
        return SearchResultItem(
          type: SearchType.navigation,
          surah: id,
          ayah: 1,
          text: 'Go to Surah $name',
        );
      }
    }
    return null;
  }

  Future<void> _addToHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_historyKey) ?? [];
    history.remove(query); // Remove if exists to move to top
    history.insert(0, query);
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    await prefs.setStringList(_historyKey, history);
  }

  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  /// Provide suggestive search for auto-complete.
  Future<List<String>> suggestions(String prefix, {int limit = 8}) async {
    final p = prefix.trim();
    if (p.isEmpty) {
      // Return recent history if empty prefix
      return await getSearchHistory();
    }

    final cacheKey = 's:$p:$limit';
    final sc = _getSuggestCache(cacheKey);
    if (sc != null) return sc;

    final out = <String>[];

    try {
      // 1. Surah Discovery (search names in suwar.dart)
      out.addAll(_surahNameSuggestions(p));

      // 2. Local DB Snippets (using FTS4/5 for speed)
      final db = await AppDatabase.instance.database;
      final normalized = ArabicNormalizer.normalize(p);

      // Arabic suggestions
      final aRows = await db.rawQuery('''
        SELECT substr(ayahs.text, 1, 60) as snippet 
        FROM ayahs_fts 
        JOIN ayahs ON ayahs.id = ayahs_fts.docid
        WHERE ayahs_fts.text MATCH ? 
        LIMIT 3
      ''', [normalized]);
      out.addAll(aRows.map((r) => r['snippet'] as String));

      // Translation suggestions
      final tRows = await db.rawQuery('''
        SELECT substr(text, 1, 60) as snippet 
        FROM translations_fts 
        WHERE text MATCH ? 
        LIMIT 3
      ''', [p]);
      out.addAll(tRows.map((r) => r['snippet'] as String));

      // 3. Topic suggestions
      out.addAll(_topicSuggestions(p));
    } catch (e) {
      // Fail silently for suggestions, just return what we have (e.g. Surah names which are memory based)
      // If DB failed, we still want Surah names if they were processed first.
      // But _surahNameSuggestions is memory, so it's safe.
      // The crash likely happens at DB await.
      print('Suggestion error: $e');
    }

    // Deduplicate while preserving order
    final seen = <String>{};
    final deduped = <String>[];
    for (final s in out) {
      final clean = s.trim();
      if (clean.isNotEmpty && seen.add(clean.toLowerCase())) {
        deduped.add(clean);
      }
    }

    return deduped;
  }

  // -------- Local providers ---------

  Future<List<SearchResultItem>> _searchLocal(String query,
      {SearchFilters? filters, int limit = 50, int offset = 0}) async {
    final db = await AppDatabase.instance.database;
    final out = <SearchResultItem>[];

    bool includeArabic =
        filters == null || filters.types.contains(SearchType.arabic);
    bool includeTranslation =
        filters == null || filters.types.contains(SearchType.translation);
    bool includeTafsir =
        filters == null || filters.types.contains(SearchType.tafsir);

    // Normalize Arabic query
    final normalizedArabic = ArabicNormalizer.normalize(query);

    final surahCond = filters?.surah != null ? 'AND surah_number = ?' : '';
    final verseCond =
        filters?.verseRange != null ? 'AND ayah_number BETWEEN ? AND ?' : '';

    if (includeArabic) {
      // Use FTS5 for Arabic search
      final args = <Object?>[normalizedArabic];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      final rows = await db.rawQuery('''
          SELECT ayahs.surah_number, ayahs.ayah_number, ayahs.text 
          FROM ayahs 
          JOIN ayahs_fts ON ayahs_fts.rowid = ayahs.id
          WHERE ayahs_fts MATCH ? $surahCond $verseCond 
          LIMIT $limit OFFSET $offset
          ''', args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.arabic,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
          )));
    }

    if (includeTranslation) {
      final args = <Object?>[query];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      if (filters?.language != null) args.add(filters!.language);
      final langCond = filters?.language != null ? 'AND language = ?' : '';

      final rows = await db.rawQuery('''
          SELECT translations.surah_number, translations.ayah_number, translations.text, translations.translator 
          FROM translations 
          JOIN translations_fts ON translations_fts.rowid = translations.id
          WHERE translations_fts MATCH ? $surahCond $verseCond $langCond 
          LIMIT $limit OFFSET $offset
          ''', args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.translation,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
            source: (r['translator'] as String?) ?? 'translation',
          )));
    }

    // Tafsir search (not using FTS yet for simplicity, or we can add it later)
    if (includeTafsir) {
      final like = '%${query.replaceAll('%', '')}%';
      final args = <Object?>[like];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      if (filters?.language != null) args.add(filters!.language);
      final langCond = filters?.language != null ? 'AND language = ?' : '';
      final rows = await db.rawQuery(
          'SELECT surah_number, ayah_number, text, scholar FROM tafsir WHERE text LIKE ? $surahCond $verseCond $langCond LIMIT $limit OFFSET $offset',
          args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.tafsir,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
            source: (r['scholar'] as String?) ?? 'tafsir',
          )));
    }

    // Special Topic Search (FR1)
    if (filters == null || filters.types.contains(SearchType.topic)) {
      final topicResults = await _searchTopics(query, limit, offset);
      out.addAll(topicResults);
    }

    return out;
  }

  Future<List<SearchResultItem>> _searchTopics(
      String query, int limit, int offset) async {
    // Thematic search: maps keywords to potential concepts
    final topicMap = {
      'parents': ['parent', 'father', 'mother', 'bequest', 'kindness'],
      'faith': ['believe', 'faith', 'iman', 'trust'],
      'prayer': ['salah', 'pray', 'prostrate', 'bow'],
      'charity': ['zakat', 'charity', 'alms', 'spend'],
    };

    final q = query.toLowerCase();
    final relatedKeywords = topicMap[q] ?? [q];

    final db = await AppDatabase.instance.database;
    final out = <SearchResultItem>[];

    for (final kw in relatedKeywords) {
      final rows = await db.rawQuery('''
        SELECT translations.surah_number, translations.ayah_number, translations.text 
        FROM translations 
        JOIN translations_fts ON translations_fts.rowid = translations.id
        WHERE translations_fts MATCH ? 
        LIMIT ${limit ~/ relatedKeywords.length}
      ''', [kw]);

      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.topic,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
            source: 'Thematic Search',
          )));
    }

    return out;
  }

  List<String> _surahNameSuggestions(String prefix) {
    final p = prefix.toLowerCase();
    final List<String> matches = [];

    for (var s in suwar_data.surah) {
      final name = s['name'].toString().toLowerCase();
      final english = s['english'].toString().toLowerCase();
      final arabic = s['arabic'].toString();

      if (name.contains(p) || english.contains(p) || arabic.contains(prefix)) {
        matches.add(s['name'].toString());
      }
    }
    return matches;
  }

  List<String> _topicSuggestions(String prefix) {
    const topics = [
      'Faith',
      'Prayer',
      'Charity',
      'Fasting',
      'Pilgrimage',
      'Mercy',
      'Justice',
      'Patience',
      'Knowledge',
      'Creation'
    ];
    final p = prefix.toLowerCase();
    return topics
        .where((t) => t.toLowerCase().contains(p))
        .toList(growable: false);
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime ts;
  _CacheEntry(this.data) : ts = DateTime.now();
}

String _searchCacheKey(String query, SearchFilters? f, int limit, int offset) {
  final types = f?.types.map((t) => t.name).join(',') ?? 'all';
  final sr = f?.surah?.toString() ?? '-';
  final vr =
      f?.verseRange != null ? '${f!.verseRange!.$1}-${f.verseRange!.$2}' : '-';
  final lang = f?.language ?? '-';
  return 'q:$query|t:$types|s:$sr|v:$vr|l:$lang|n:$limit|o:$offset';
}
