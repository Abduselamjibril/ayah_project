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
      final [translations, tafsirs] = await Future.wait([
        _translationService.getAllTranslations(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        ),
        _tafsirService.getAllTafsirs(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
        ),
      ]);

      setState(() {
        _allTranslations = translations;
        _allTafsirs = tafsirs;

        // Auto-select first available
        _selectedTranslationId = translations.isNotEmpty
            ? translations.first['edition_identifier']
            : null;
        _selectedTafsirId =
            tafsirs.isNotEmpty ? tafsirs.first['edition_identifier'] : null;

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
        orElse: () => {'content': ''},
      );
      return verse['content'] as String? ?? '';
    } catch (e) {
      return '';
    }
  }

  String _getSurahName() {
    try {
      final surahData = surah.firstWhere(
        (s) => s['id'] == widget.surahNumber,
        orElse: () => {'name': 'Unknown'},
      );
      return surahData['name'] as String? ?? 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle =
        '${_getSurahName()} ${widget.surahNumber}:${widget.ayahNumber}';

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildArabicTextCard(),
                  const SizedBox(height: 20),
                  _buildTranslationSection(),
                  const SizedBox(height: 20),
                  _buildTafsirSection(),
                ],
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
            _buildSectionTitle('Arabic Text'),
            const SizedBox(height: 16),
            Text(
              _getArabicText(),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontSize: 28, height: 2.0),
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
            _buildSectionHeader(
              title: 'Translation',
              items: _allTranslations,
              selectedId: _selectedTranslationId,
              onSelected: (id) => setState(() => _selectedTranslationId = id),
            ),
            const SizedBox(height: 12),
            _allTranslations.isEmpty
                ? _buildNoDataSection('translations')
                : _buildTranslationText(),
          ],
        ),
      ),
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
            _buildSectionHeader(
              title: 'Tafsir (Interpretation)',
              items: _allTafsirs,
              selectedId: _selectedTafsirId,
              onSelected: (id) => setState(() => _selectedTafsirId = id),
            ),
            const SizedBox(height: 12),
            _allTafsirs.isEmpty
                ? _buildNoDataSection('tafsir')
                : _buildTafsirText(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required List<Map<String, dynamic>> items,
    required String? selectedId,
    required Function(String?) onSelected,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSectionTitle(title),
        if (items.isNotEmpty)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: onSelected,
            itemBuilder: (context) => items.map((item) {
              final editionId = item['edition_identifier'] as String?;
              final name = item['translator'] ?? item['scholar'] ?? 'Unknown';
              return PopupMenuItem<String>(
                value: editionId,
                child: Text(name),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildNoDataSection(String type) {
    return Column(
      children: [
        Text(
          'No $type downloaded',
          style: const TextStyle(
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
              MaterialPageRoute(builder: (context) => const DownloadsScreen()),
            ).then((_) => _loadData());
          },
          icon: const Icon(Icons.download),
          label: Text('Download $type'),
        ),
      ],
    );
  }

  Widget _buildTranslationText() {
    if (_selectedTranslationId == null) {
      return const Text('Select a translation');
    }

    final translation = _allTranslations.firstWhere(
      (t) => t['edition_identifier'] == _selectedTranslationId,
      orElse: () => {},
    );

    if (translation.isEmpty) return const Text('Translation not found');

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
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildTafsirText() {
    if (_selectedTafsirId == null) return const Text('Select a tafsir');

    final tafsir = _allTafsirs.firstWhere(
      (t) => t['edition_identifier'] == _selectedTafsirId,
      orElse: () => {},
    );

    if (tafsir.isEmpty) return const Text('Tafsir not found');

    final language = (tafsir['language'] as String? ?? '').toLowerCase();
    final isArabic = language == 'ar' || language == 'arabic';

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
          style: const TextStyle(fontSize: 16, height: 1.5),
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        ),
      ],
    );
  }
}
