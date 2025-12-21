// lib/features/tafsir/tafsir_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:quran_app/data/models/translation_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TafsirScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const TafsirScreen({
    super.key,
    this.surahNumber = 1,
    this.ayahNumber = 1,
  });

  @override
  State<TafsirScreen> createState() => _TafsirScreenState();
}

class _TafsirScreenState extends State<TafsirScreen> {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;
  final HtmlUnescape _unescaper = HtmlUnescape();

  TranslationEdition? _selectedTranslation;
  TafsirEdition? _selectedTafsir;
  String? _content;
  bool _isLoading = true;
  String _activeType = 'none';
  String _contentSource = 'unknown';

  List<TafsirEdition> _tafsirEditions = [];
  List<TranslationEdition> _translationEditions = [];
  Set<String> _downloadedTafsirs = <String>{};
  Set<String> _downloadedTranslations = <String>{};
  bool _isFetchingEditions = true;
  bool _isDownloading = false;
  String? _downloadingType;
  int? _downloadingId;
  double _downloadProgress = 0.0;

  bool get _contentHasHtml =>
      _content != null && RegExp(r'<[^>]+>').hasMatch(_content!);

  String _normalizeContent(String? raw) {
    if (raw == null) return '';
    String current = raw;
    for (int i = 0; i < 5; i++) {
      final decoded = _unescaper.convert(current);
      if (decoded == current) break;
      current = decoded;
    }
    return current.trim();
  }

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  Future<void> _initPage() async {
    await _loadEditions();
    await _loadContent();
  }

  Future<void> _loadEditions() async {
    setState(() => _isFetchingEditions = true);
    try {
      final tafsirs = await _tafsirService.getAvailableTafsirs();
      final translations =
          await _translationService.getAllTranslationEditions();
      final downloadedTafsirs = await _tafsirService.getDownloadedTafsirs();
      final downloadedTranslations =
          await _translationService.getDownloadedTranslations();
      setState(() {
        _tafsirEditions = tafsirs;
        _translationEditions = translations;
        _downloadedTafsirs = downloadedTafsirs.toSet();
        _downloadedTranslations = downloadedTranslations.toSet();
      });
    } catch (e) {
      debugPrint('Error loading editions: $e');
    } finally {
      if (mounted) setState(() => _isFetchingEditions = false);
    }
  }

  Future<void> _loadContent() async {
    setState(() => _isLoading = true);
    try {
      _selectedTafsir = await _tafsirService.getSelectedTafsir();
      _selectedTranslation = await _translationService.getSelectedTranslation();

      if (_selectedTafsir != null) {
        _activeType = 'tafsir';
        final tafsirText = await _tafsirService.getTafsirByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTafsir!.id.toString(),
        );
        _content = _normalizeContent(tafsirText);
        _contentSource = 'tafsir-db-${_selectedTafsir!.id}';
      } else if (_selectedTranslation != null) {
        _activeType = 'translation';
        final transText = await _translationService.getTranslationByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTranslation!.id.toString(),
        );
        _content = _normalizeContent(transText);
        _contentSource = 'translation-db-${_selectedTranslation!.id}';
      } else {
        _activeType = 'none';
        _content =
            'No translation or tafsir selected. Please select one from settings.';
        _contentSource = 'none-selected';
      }
    } catch (e) {
      _content = 'Error loading content: $e';
      _contentSource = 'error';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _startDownloadTafsir(TafsirEdition edition) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadingType = 'tafsir';
      _downloadingId = edition.id;
      _downloadProgress = 0.0;
    });
    final ok = await _tafsirService.downloadTafsir(
      edition,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p.clamp(0.0, 1.0));
      },
    );
    if (ok) {
      await _tafsirService.setSelectedTafsirId(edition.id);
      await _loadEditions();
      await _loadContent();
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadingType = null;
        _downloadingId = null;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _startDownloadTranslation(TranslationEdition edition) async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
      _downloadingType = 'translation';
      _downloadingId = edition.id;
      _downloadProgress = 0.0;
    });
    final ok = await _translationService.downloadTranslation(
      edition,
      onProgress: (p) {
        if (!mounted) return;
        setState(() => _downloadProgress = p.clamp(0.0, 1.0));
      },
    );
    if (ok) {
      await _translationService.setSelectedTranslationId(edition.id);
      await _loadEditions();
      await _loadContent();
    }
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadingType = null;
        _downloadingId = null;
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _openDownloadedPicker(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final isTafsir = type == 'tafsir';
    final downloadedIds =
        isTafsir ? _downloadedTafsirs : _downloadedTranslations;
    final editions = isTafsir
        ? _tafsirEditions.cast<dynamic>()
        : _translationEditions.cast<dynamic>();

    final Set<String> langs = <String>{};
    for (final e in editions) {
      if (downloadedIds.contains(e.id.toString())) {
        final name = (e.languageName ?? '').trim();
        if (name.isNotEmpty) langs.add(name);
      }
    }
    final languages = langs.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (languages.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'No downloaded ${isTafsir ? 'tafsirs' : 'translations'} found')),
      );
      return;
    }

    final lastLangKey =
        isTafsir ? 'picker_last_lang_tafsir' : 'picker_last_lang_translation';
    String selectedLanguage = prefs.getString(lastLangKey) ?? languages.first;
    if (!languages.contains(selectedLanguage)) {
      selectedLanguage = languages.first;
    }

    final currentSelectedId =
        isTafsir ? _selectedTafsir?.id : _selectedTranslation?.id;
    String filter = '';

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            List<dynamic> filtered = editions
                .where((e) => downloadedIds.contains(e.id.toString()))
                .where((e) =>
                    (e.languageName ?? '').toLowerCase() ==
                    selectedLanguage.toLowerCase())
                .toList()
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (filter.isNotEmpty) {
              filtered = filtered
                  .where((e) =>
                      e.name.toLowerCase().contains(filter.toLowerCase()))
                  .toList();
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(isTafsir ? Icons.menu_book : Icons.translate,
                              color: Theme.of(ctx).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Choose ${isTafsir ? 'Tafsir' : 'Translation'}',
                              style: Theme.of(ctx)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.of(ctx).pop()),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemBuilder: (c, i) {
                          final lang = languages[i];
                          final selected = lang == selectedLanguage;
                          return ChoiceChip(
                            label: Text(lang),
                            selected: selected,
                            onSelected: (_) =>
                                setSheetState(() => selectedLanguage = lang),
                          );
                        },
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemCount: languages.length,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText:
                              'Search ${isTafsir ? 'tafsir' : 'translation'} editions',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (v) => setSheetState(() => filter = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                  'No downloaded files for $selectedLanguage'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(8),
                              itemBuilder: (c, i) {
                                final ed = filtered[i];
                                final bool isCurrent =
                                    ed.id == currentSelectedId;
                                return Card(
                                  child: ListTile(
                                    leading: Icon(isTafsir
                                        ? Icons.menu_book
                                        : Icons.translate),
                                    title: Text(ed.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Text(
                                        '${ed.languageName ?? ''} • ID: ${ed.id}'),
                                    trailing: isCurrent
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green)
                                        : const Icon(Icons.circle_outlined),
                                    onTap: () async {
                                      await prefs.setString(
                                          lastLangKey, selectedLanguage);
                                      if (isTafsir) {
                                        await _tafsirService
                                            .setSelectedTafsirId(ed.id);
                                        final chosen =
                                            _tafsirEditions.firstWhere(
                                          (e) => e.id == ed.id,
                                          orElse: () =>
                                              _selectedTafsir ??
                                              _tafsirEditions.first,
                                        );
                                        if (mounted) {
                                          setState(
                                              () => _selectedTafsir = chosen);
                                        }
                                      } else {
                                        await _translationService
                                            .setSelectedTranslationId(ed.id);
                                        final chosen =
                                            _translationEditions.firstWhere(
                                          (e) => e.id == ed.id,
                                          orElse: () =>
                                              _selectedTranslation ??
                                              _translationEditions.first,
                                        );
                                        if (mounted) {
                                          setState(() =>
                                              _selectedTranslation = chosen);
                                        }
                                      }
                                      await _loadContent();
                                      if (ctx.mounted) Navigator.of(ctx).pop();
                                    },
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemCount: filtered.length,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tafsir & Translation'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'pick-tafsir') {
                await _openDownloadedPicker('tafsir');
              } else if (value == 'pick-translation') {
                await _openDownloadedPicker('translation');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'pick-tafsir',
                child: Text('Choose Tafsir (Downloaded)'),
              ),
              PopupMenuItem<String>(
                value: 'pick-translation',
                child: Text('Choose Translation (Downloaded)'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Select Editions',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          // Tafsir selector
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _selectedTafsir?.id,
                                  hint: const Text('Choose Tafsir'),
                                  items: _tafsirEditions
                                      .map((e) => DropdownMenuItem<int>(
                                            value: e.id,
                                            child: Text(
                                              '${e.name}${_downloadedTafsirs.contains(e.id.toString()) ? ' (downloaded)' : ''}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) async {
                                    if (val == null) return;
                                    final chosen = _tafsirEditions
                                        .firstWhere((e) => e.id == val);
                                    await _tafsirService
                                        .setSelectedTafsirId(chosen.id);
                                    setState(() => _selectedTafsir = chosen);
                                    _loadContent();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_selectedTafsir != null &&
                                  !_downloadedTafsirs
                                      .contains(_selectedTafsir!.id.toString()))
                                _isDownloading &&
                                        _downloadingType == 'tafsir' &&
                                        _downloadingId == _selectedTafsir!.id
                                    ? _DownloadProgressChip(
                                        progress: _downloadProgress)
                                    : OutlinedButton.icon(
                                        onPressed: _isDownloading
                                            ? null
                                            : () => _startDownloadTafsir(
                                                _selectedTafsir!),
                                        icon: const Icon(Icons.download),
                                        label: const Text('Download'),
                                      ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Translation selector
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: _selectedTranslation?.id,
                                  hint: const Text('Choose Translation'),
                                  items: _translationEditions
                                      .map((e) => DropdownMenuItem<int>(
                                            value: e.id,
                                            child: Text(
                                              '${e.name}${_downloadedTranslations.contains(e.id.toString()) ? ' (downloaded)' : ''}',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (val) async {
                                    if (val == null) return;
                                    final chosen = _translationEditions
                                        .firstWhere((e) => e.id == val);
                                    await _translationService
                                        .setSelectedTranslationId(chosen.id);
                                    setState(
                                        () => _selectedTranslation = chosen);
                                    _loadContent();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_selectedTranslation != null &&
                                  !_downloadedTranslations.contains(
                                      _selectedTranslation!.id.toString()))
                                _isDownloading &&
                                        _downloadingType == 'translation' &&
                                        _downloadingId ==
                                            _selectedTranslation!.id
                                    ? _DownloadProgressChip(
                                        progress: _downloadProgress)
                                    : OutlinedButton.icon(
                                        onPressed: _isDownloading
                                            ? null
                                            : () => _startDownloadTranslation(
                                                _selectedTranslation!),
                                        icon: const Icon(Icons.download),
                                        label: const Text('Download'),
                                      ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_activeType != 'none') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Theme.of(context)
                                .primaryColor
                                .withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                              _activeType == 'tafsir'
                                  ? Icons.menu_book
                                  : Icons.translate,
                              color: Theme.of(context).primaryColor),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _activeType == 'tafsir'
                                      ? (_selectedTafsir?.name ??
                                          'Unknown Tafsir')
                                      : (_selectedTranslation?.name ??
                                          'Unknown Translation'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Language: ${_activeType == 'tafsir' ? (_selectedTafsir?.languageName ?? '') : (_selectedTranslation?.languageName ?? '')}',
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Expanded(
                    child: SingleChildScrollView(
                      child: _content == null
                          ? const Text(
                              'Content not available',
                              style: TextStyle(fontSize: 18, height: 1.6),
                              textAlign: TextAlign.center,
                            )
                          : (_activeType != 'none' || _contentHasHtml)
                              ? Html(
                                  data: _content!,
                                  style: {
                                    'body': Style(
                                      fontSize: FontSize(18),
                                      lineHeight: const LineHeight(1.6),
                                      textAlign: TextAlign.justify,
                                    ),
                                  },
                                )
                              : Text(
                                  _content!,
                                  style: const TextStyle(
                                      fontSize: 18, height: 1.6),
                                  textAlign: TextAlign.center,
                                ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DownloadProgressChip extends StatelessWidget {
  final double progress;
  const _DownloadProgressChip({required this.progress});

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          child: LinearProgressIndicator(value: progress),
        ),
        const SizedBox(width: 8),
        Text('$percent%'),
      ],
    );
  }
}
