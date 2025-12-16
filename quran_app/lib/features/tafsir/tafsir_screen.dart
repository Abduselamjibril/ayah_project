// lib/features/tafsir/tafsir_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/data/models/tafsir_model.dart';
import 'package:quran_app/data/models/translation_model.dart';
import 'package:quran_app/features/downloads/downloads_screen.dart';

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

  TranslationEdition? _selectedTranslation;
  TafsirEdition? _selectedTafsir;
  String? _content;
  bool _isLoading = true;
  String _activeType = 'none'; // 'translation', 'tafsir', or 'none'

  @override
  void initState() {
    super.initState();
    _loadContent();
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
        _content = tafsirText;
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
        _content = transText;
      } else {
        print('No tafsir or translation selected');
        _activeType = 'none';
        _content =
            'No translation or tafsir selected. Please select one from settings.';
      }

      print('Active type: $_activeType');
      print('=== TafsirScreen: Load complete ===');
    } catch (e) {
      print('ERROR in _loadContent: $e');
      _content = 'Error loading content: $e';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tafsir & Translation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Manage Downloads',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DownloadsScreen()),
              );
              // Refresh content on return as selection might have changed
              _loadContent();
            },
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
                      child: Text(
                        _content ?? 'Content not available',
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.6,
                        ),
                        textAlign: _activeType == 'none'
                            ? TextAlign.center
                            : TextAlign.start,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
