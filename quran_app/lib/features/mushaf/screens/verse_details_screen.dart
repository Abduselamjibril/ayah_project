// lib/features/mushaf/screens/verse_details_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/quran/data/suwar.dart';
import 'package:quran_app/core/quran/data/quran_text.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';

class VerseDetailsScreen extends StatefulWidget {
  final int surahNumber;
  final int ayahNumber;

  const VerseDetailsScreen({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
  });

  @override
  State<VerseDetailsScreen> createState() => _VerseDetailsScreenState();
}

class _VerseDetailsScreenState extends State<VerseDetailsScreen> {
  final TranslationService _translationService = TranslationService.instance;
  final TafsirService _tafsirService = TafsirService.instance;

  List<Map<String, dynamic>> _allTranslations = [];
  List<Map<String, dynamic>> _allTafsirs = [];

  List<String> _downloadedTranslations = [];
  List<String> _downloadedTafsirs = [];

  String? _selectedTranslationId;
  String? _selectedTafsirId;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Load downloaded editions
      final translations =
          await _translationService.getDownloadedTranslations();
      final tafsirs = await _tafsirService.getDownloadedTafsirs();

      print('VerseDetails: Downloaded translations: $translations');
      print('VerseDetails: Downloaded tafsirs: $tafsirs');

      // Load all translations for this verse
      final allTrans = await _translationService.getAllTranslations(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
      );

      // Load all tafsirs for this verse
      final allTafs = await _tafsirService.getAllTafsirs(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
      );

      print(
          'VerseDetails: All translations for ${widget.surahNumber}:${widget.ayahNumber}: ${allTrans.length} found');
      print(
          'VerseDetails: All tafsirs for ${widget.surahNumber}:${widget.ayahNumber}: ${allTafs.length} found');

      if (allTrans.isNotEmpty) {
        print('VerseDetails: First translation: ${allTrans.first}');
      }
      if (allTafs.isNotEmpty) {
        print('VerseDetails: First tafsir: ${allTafs.first}');
      }

      setState(() {
        _downloadedTranslations = translations;
        _downloadedTafsirs = tafsirs;
        _allTranslations = allTrans;
        _allTafsirs = allTafs;

        // Auto-select first if available
        if (_allTranslations.isNotEmpty) {
          _selectedTranslationId = _allTranslations.first['edition_identifier'];
          print(
              'VerseDetails: Auto-selected translation: $_selectedTranslationId');
        }
        if (_allTafsirs.isNotEmpty) {
          _selectedTafsirId = _allTafsirs.first['edition_identifier'];
          print('VerseDetails: Auto-selected tafsir: $_selectedTafsirId');
        }

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
    }
  }

  String _getArabicText() {
    try {
      final verse = quranText.firstWhere(
        (v) =>
            v['surah_number'] == widget.surahNumber &&
            v['verse_number'] == widget.ayahNumber,
      );
      return verse['content'] as String? ?? '';
    } catch (e) {
      return 'Verse not found';
    }
  }

  String _getSurahName() {
    try {
      final surahData = surah.firstWhere((s) => s['id'] == widget.surahNumber);
      return surahData['name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${_getSurahName()} ${widget.surahNumber}:${widget.ayahNumber}',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Arabic Text Card
                    _buildArabicTextCard(),
                    const SizedBox(height: 20),

                    // Translation Section
                    _buildTranslationSection(),
                    const SizedBox(height: 20),

                    // Tafsir Section
                    _buildTafsirSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildArabicTextCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Arabic Text',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _getArabicText(),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(
                fontSize: 28,
                height: 2.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Translation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (_allTranslations.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.translate),
                    onSelected: (editionId) {
                      setState(() => _selectedTranslationId = editionId);
                    },
                    itemBuilder: (context) {
                      return _allTranslations.map((trans) {
                        final editionId =
                            trans['edition_identifier'] as String?;
                        final translator =
                            trans['translator'] as String? ?? 'Unknown';
                        return PopupMenuItem<String>(
                          value: editionId,
                          child: Text(translator),
                        );
                      }).toList();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _allTranslations.isEmpty
                ? Column(
                    children: [
                      const Text(
                        'No translations downloaded',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DownloadsScreen(),
                            ),
                          ).then((_) => _loadData());
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download Translations'),
                      ),
                    ],
                  )
                : _buildTranslationText(),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationText() {
    if (_selectedTranslationId == null) {
      return const Text('Please select a translation');
    }

    final translation = _allTranslations.firstWhere(
      (t) => t['edition_identifier'] == _selectedTranslationId,
      orElse: () => {},
    );

    if (translation.isEmpty) {
      return const Text('Translation not found');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translation['translator'] as String? ?? 'Unknown',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          translation['text'] as String? ?? 'No text available',
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTafsirSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tafsir (Interpretation)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                if (_allTafsirs.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu_book),
                    onSelected: (editionId) {
                      setState(() => _selectedTafsirId = editionId);
                    },
                    itemBuilder: (context) {
                      return _allTafsirs.map((tafsir) {
                        final editionId =
                            tafsir['edition_identifier'] as String?;
                        final scholar =
                            tafsir['scholar'] as String? ?? 'Unknown';
                        return PopupMenuItem<String>(
                          value: editionId,
                          child: Text(scholar),
                        );
                      }).toList();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _allTafsirs.isEmpty
                ? Column(
                    children: [
                      const Text(
                        'No tafsir downloaded',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DownloadsScreen(),
                            ),
                          ).then((_) => _loadData());
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download Tafsir'),
                      ),
                    ],
                  )
                : _buildTafsirText(),
          ],
        ),
      ),
    );
  }

  Widget _buildTafsirText() {
    if (_selectedTafsirId == null) {
      return const Text('Please select a tafsir');
    }

    final tafsir = _allTafsirs.firstWhere(
      (t) => t['edition_identifier'] == _selectedTafsirId,
      orElse: () => {},
    );

    if (tafsir.isEmpty) {
      return const Text('Tafsir not found');
    }

    final language = tafsir['language'] as String? ?? 'unknown';
    final isArabic =
        language.toLowerCase() == 'ar' || language.toLowerCase() == 'arabic';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tafsir['scholar'] as String? ?? 'Unknown',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tafsir['text'] as String? ?? 'No text available',
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        ),
      ],
    );
  }
}
