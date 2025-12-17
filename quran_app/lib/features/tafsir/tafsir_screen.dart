// lib/features/tafsir/tafsir_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:quran_app/data/models/translation_model.dart';

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
  String _activeType = 'none'; // 'translation', 'tafsir', or 'none'
  String _contentSource = 'unknown';

  // Editions & download state
  List<TafsirEdition> _tafsirEditions = [];
  List<TranslationEdition> _translationEditions = [];
  Set<String> _downloadedTafsirs = <String>{};
  Set<String> _downloadedTranslations = <String>{};
  bool _isFetchingEditions = true;
  bool _isDownloading = false;
  String? _downloadingType; // 'tafsir' or 'translation'
  int? _downloadingId;
  double _downloadProgress = 0.0; // 0..1

  bool get _contentHasHtml =>
      _content != null && RegExp(r'<[^>]+>').hasMatch(_content!);

  String _normalizeContent(String? raw) {
    if (raw == null) return '';
    String current = raw;
    // Decode repeatedly to handle multi-escaped HTML such as &amp;lt;h2&amp;gt;.
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
      print(
          '=== TafsirScreen: Loading content for ${widget.surahNumber}:${widget.ayahNumber} ===');

      // 1. Check for selected Tafsir
      final selectedTafsirId = await _tafsirService.getSelectedTafsirId();
      print('Selected Tafsir ID: $selectedTafsirId');

      _selectedTafsir = await _tafsirService.getSelectedTafsir();
      print(
          'Selected Tafsir Edition: ${_selectedTafsir?.name} (ID: ${_selectedTafsir?.id})');

      // 2. Check for selected Translation
      final selectedTranslationId =
          await _translationService.getSelectedTranslationId();
      print('Selected Translation ID: $selectedTranslationId');

      _selectedTranslation = await _translationService.getSelectedTranslation();
      print(
          'Selected Translation Edition: ${_selectedTranslation?.name} (ID: ${_selectedTranslation?.id})');

      // 3. Determine what to show (Prioritize Tafsir if available, else Translation)
      if (_selectedTafsir != null) {
        print('Attempting to load Tafsir...');
        _activeType = 'tafsir';

        // Check if tafsir is downloaded
        final isDownloaded = await _tafsirService
            .isTafsirDownloaded(_selectedTafsir!.id.toString());
        print(
            'Is Tafsir downloaded? $isDownloaded (checking with ID: ${_selectedTafsir!.id})');

        final tafsirText = await _tafsirService.getTafsirByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTafsir!.id.toString(),
        );
        print(
            'Loaded Tafsir text: ${tafsirText?.substring(0, tafsirText.length > 50 ? 50 : tafsirText.length)}...');
        _content = _normalizeContent(tafsirText);
        _contentSource = 'tafsir-db-${_selectedTafsir!.id}';
      } else if (_selectedTranslation != null) {
        print('Attempting to load Translation...');
        _activeType = 'translation';

        // Check if translation is downloaded
        final isDownloaded = await _translationService
            .isTranslationDownloaded(_selectedTranslation!.id.toString());
        print(
            'Is Translation downloaded? $isDownloaded (checking with ID: ${_selectedTranslation!.id})');

        final transText = await _translationService.getTranslationByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTranslation!.id.toString(),
        );
        print(
            'Loaded Translation text: ${transText?.substring(0, transText.length > 50 ? 50 : transText.length)}...');
        _content = _normalizeContent(transText);
        _contentSource = 'translation-db-${_selectedTranslation!.id}';
      } else {
        print('No tafsir or translation selected');
        _activeType = 'none';
        _content =
            'No translation or tafsir selected. Please select one from settings.';
        _contentSource = 'none-selected';
      }

      print('Active type: $_activeType');
      if (_content != null) {
        print('Content source: $_contentSource');
        print('DEBUG HTML CHECK START');
        print(
            'DEBUG RAW CONTENT: ${_content!.substring(0, _content!.length > 500 ? 500 : _content!.length)}');
        print('DEBUG HTML CHECK END');
      }
      print('=== TafsirScreen: Load complete ===');
    } catch (e) {
      print('ERROR in _loadContent: $e');
      _content = 'Error loading content: $e';
      _contentSource = 'error';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tafsir & Translation'),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selection controls
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
                                  value: _selectedTafsir?.id,
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
                                        progress: _downloadProgress,
                                      )
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
                                  value: _selectedTranslation?.id,
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
                                        progress: _downloadProgress,
                                      )
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
                  // Header with Edition Name and Language
                  if (_activeType != 'none') ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _activeType == 'tafsir'
                                ? Icons.menu_book
                                : Icons.translate,
                            color: Theme.of(context).primaryColor,
                          ),
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
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Language: ${_activeType == 'tafsir' ? (_selectedTafsir?.languageName ?? '') : (_selectedTranslation?.languageName ?? '')}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: _content == null
                          ? const Text(
                              'Content not available',
                              style: TextStyle(
                                fontSize: 18,
                                height: 1.6,
                              ),
                              textAlign: TextAlign.center,
                            )
                          : (_activeType != 'none' || _contentHasHtml)
                              ? Html(
                                  data: _content!,
                                  style: {
                                    "body": Style(
                                      fontSize: FontSize(18),
                                      lineHeight: LineHeight(1.6),
                                      textAlign: TextAlign.justify,
                                    ),
                                  },
                                )
                              : Text(
                                  _content!,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    height: 1.6,
                                  ),
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
