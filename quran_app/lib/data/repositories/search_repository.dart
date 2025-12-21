import 'dart:async';
import 'dart:convert';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:quran_app/core/database/app_database.dart';

/// Types of content the search can target
enum SearchType { arabic, translation, tafsir, topic }

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
      {SearchFilters? filters, int limit = 50}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final cacheKey = _searchCacheKey(trimmed, filters, limit);
    final cached = _getResultCache(cacheKey);
    if (cached != null) return cached;

    // Try remote ElasticSearch if configured
    if (config.elasticUrl != null && config.elasticUrl!.isNotEmpty) {
      try {
        final remote =
            await _searchElastic(trimmed, filters: filters, limit: limit);
        if (remote.isNotEmpty) return remote;
      } catch (e) {
        debugPrint('Elastic search failed: $e');
      }
    }

    // Fallback to local SQLite content
    final local = await _searchLocal(trimmed, filters: filters, limit: limit);
    _setResultCache(cacheKey, local);
    return local;
  }

  /// Provide suggestive search for auto-complete.
  Future<List<String>> suggestions(String prefix, {int limit = 8}) async {
    final p = prefix.trim();
    if (p.isEmpty) return [];

    // Do not hit remote providers for very short prefixes
    final useRemote = p.length >= 2;

    final cacheKey = 's:$p:$limit';
    final sc = _getSuggestCache(cacheKey);
    if (sc != null) return sc;

    // Priority: remote API suggestions if available (Quran.com or Elastic)
    final List<String> remote = [];
    if (useRemote && config.quranComApiBase != null) {
      try {
        final s = await _quranComSuggestions(p, limit: limit);
        remote.addAll(s);
      } catch (e) {
        debugPrint('Quran.com suggestions failed: $e');
      }
    }
    if (remote.isNotEmpty) {
      final r = remote.take(limit).toList();
      _setSuggestCache(cacheKey, r);
      return r;
    }

    // Fallback: local DB and heuristic suggestions
    final local = await _localSuggestions(p, limit: limit);
    final r = local.take(limit).toList();
    _setSuggestCache(cacheKey, r);
    return r;
  }

  // -------- Remote providers ---------

  Future<List<SearchResultItem>> _searchElastic(String query,
      {SearchFilters? filters, int limit = 50}) async {
    final url = Uri.parse(config.elasticUrl!);
    // Minimal example Elastic query; tailor to your index mapping
    final body = {
      'size': limit,
      'query': {
        'multi_match': {
          'query': query,
          'fields': ['arabic^3', 'translation^2', 'tafsir']
        }
      }
    };
    final headers = {
      'Content-Type': 'application/json',
      if (config.elasticApiKey?.isNotEmpty == true)
        'Authorization': 'ApiKey ${config.elasticApiKey}'
    };
    final resp = await http
        .post(url, headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Elastic status ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final hits =
        ((decoded['hits'] as Map<String, dynamic>?)?['hits'] as List?) ?? [];
    return hits.map<SearchResultItem>((h) {
      final src = h['_source'] as Map<String, dynamic>? ?? {};
      final type = src['type'] as String? ?? 'arabic';
      final t = switch (type) {
        'translation' => SearchType.translation,
        'tafsir' => SearchType.tafsir,
        'topic' => SearchType.topic,
        _ => SearchType.arabic,
      };
      return SearchResultItem(
        type: t,
        surah: (src['surah'] as num?)?.toInt() ?? 1,
        ayah: (src['ayah'] as num?)?.toInt() ?? 1,
        text: (src['text'] as String?) ?? '',
        source: src['source'] as String?,
      );
    }).toList(growable: false);
  }

  Future<List<String>> _quranComSuggestions(String prefix,
      {int limit = 8}) async {
    // Note: Quran.com API endpoints may change; this is a placeholder.
    final base = config.quranComApiBase!;
    final url = Uri.parse(
        '$base/search?query=${Uri.encodeQueryComponent(prefix)}&size=$limit');
    final resp = await http.get(url).timeout(const Duration(seconds: 10));
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Quran.com status ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is Map && decoded['suggestions'] is List) {
      return (decoded['suggestions'] as List).whereType<String>().toList();
    }
    // Fallback: extract verse text snippets if available
    final List<String> out = [];
    final results = decoded['results'];
    if (results is List) {
      for (final r in results) {
        if (r is Map && r['text'] is String) out.add(r['text'] as String);
      }
    }
    return out;
  }

  // -------- Local providers ---------

  Future<List<SearchResultItem>> _searchLocal(String query,
      {SearchFilters? filters, int limit = 50}) async {
    final db = await AppDatabase.instance.database;
    final out = <SearchResultItem>[];
    final like = '%${query.replaceAll('%', '')}%';

    bool includeArabic =
        filters == null || filters.types.contains(SearchType.arabic);
    bool includeTranslation =
        filters == null || filters.types.contains(SearchType.translation);
    bool includeTafsir =
        filters == null || filters.types.contains(SearchType.tafsir);

    final surahCond = filters?.surah != null ? 'AND surah_number = ?' : '';
    final verseCond =
        filters?.verseRange != null ? 'AND ayah_number BETWEEN ? AND ?' : '';

    if (includeArabic) {
      final args = <Object?>[like];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      final rows = await db.rawQuery(
          'SELECT surah_number, ayah_number, text FROM ayahs WHERE text LIKE ? $surahCond $verseCond LIMIT $limit',
          args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.arabic,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
          )));
    }

    if (includeTranslation) {
      final args = <Object?>[like];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      if (filters?.language != null) args.add(filters!.language);
      final langCond = filters?.language != null ? 'AND language = ?' : '';
      final rows = await db.rawQuery(
          'SELECT surah_number, ayah_number, text, translator FROM translations WHERE text LIKE ? $surahCond $verseCond $langCond LIMIT $limit',
          args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.translation,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
            source: (r['translator'] as String?) ?? 'translation',
          )));
    }

    if (includeTafsir) {
      final args = <Object?>[like];
      if (filters?.surah != null) args.add(filters!.surah);
      if (filters?.verseRange != null) {
        args.add(filters!.verseRange!.$1);
        args.add(filters.verseRange!.$2);
      }
      if (filters?.language != null) args.add(filters!.language);
      final langCond = filters?.language != null ? 'AND language = ?' : '';
      final rows = await db.rawQuery(
          'SELECT surah_number, ayah_number, text, scholar FROM tafsir WHERE text LIKE ? $surahCond $verseCond $langCond LIMIT $limit',
          args);
      out.addAll(rows.map((r) => SearchResultItem(
            type: SearchType.tafsir,
            surah: (r['surah_number'] as num).toInt(),
            ayah: (r['ayah_number'] as num).toInt(),
            text: (r['text'] as String),
            source: (r['scholar'] as String?) ?? 'tafsir',
          )));
    }

    return out;
  }

  Future<List<String>> _localSuggestions(String prefix, {int limit = 8}) async {
    final db = await AppDatabase.instance.database;
    final like = '%${prefix.replaceAll('%', '')}%';
    final out = <String>[];

    // Suggest surah names by heuristic
    out.addAll(_surahNameSuggestions(prefix));

    // Suggest snippets from Arabic verses
    final rows = await db.rawQuery(
        'SELECT substr(text, 1, 120) AS text FROM ayahs WHERE text LIKE ? LIMIT $limit',
        [like]);
    out.addAll(rows.map((r) => (r['text'] as String)));

    // Add topic suggestions
    out.addAll(_topicSuggestions(prefix));

    // Deduplicate while preserving order
    final seen = <String>{};
    final deduped = <String>[];
    for (final s in out) {
      if (seen.add(s)) deduped.add(s);
    }
    return deduped.take(limit).toList();
  }

  List<String> _surahNameSuggestions(String prefix) {
    // Minimal list; production should read from qcf_quran or localized assets
    const names = [
      'Al-Fatihah',
      'Al-Baqarah',
      'Ali Imran',
      'An-Nisa',
      'Al-Ma’idah',
      'Al-An’am',
      'Al-A’raf',
      'Al-Anfal',
      'At-Tawbah',
      'Yunus',
      'Hud',
      'Yusuf',
      'Ar-Ra’d',
      'Ibrahim',
      'Al-Hijr'
    ];
    final p = prefix.toLowerCase();
    return names
        .where((n) => n.toLowerCase().contains(p))
        .toList(growable: false);
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

String _searchCacheKey(String query, SearchFilters? f, int limit) {
  final types = f?.types.map((t) => t.name).join(',') ?? 'all';
  final sr = f?.surah?.toString() ?? '-';
  final vr =
      f?.verseRange != null ? '${f!.verseRange!.$1}-${f.verseRange!.$2}' : '-';
  final lang = f?.language ?? '-';
  return 'q:$query|t:$types|s:$sr|v:$vr|l:$lang|n:$limit';
}
