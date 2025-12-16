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
      // 1. Check for selected Tafsir
      _selectedTafsir = await _tafsirService.getSelectedTafsir();

      // 2. Check for selected Translation
      _selectedTranslation = await _translationService.getSelectedTranslation();

      // 3. Determine what to show (Prioritize Tafsir if usually desired, or stick to last selection?)
      // For now: Show Tafsir if available, else Translation.
      // But user said "transletion name or tefsir name".
      // Let's check which one actually has content for this ayah?
      // Or better, check if we have persisted user preference for MODE.
      // For now, simple logic:

      if (_selectedTafsir != null) {
        _activeType = 'tafsir';
        final tafsirText = await _tafsirService.getTafsirByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTafsir!.id.toString(),
        );
        _content = tafsirText;
      } else if (_selectedTranslation != null) {
        _activeType = 'translation';
        final transText = await _translationService.getTranslationByEdition(
          surahNumber: widget.surahNumber,
          ayahNumber: widget.ayahNumber,
          editionIdentifier: _selectedTranslation!.id.toString(),
        );
        _content = transText;
      } else {
        _activeType = 'none';
        _content =
            'No translation or tafsir selected. Please select one from settings.';
      }
    } catch (e) {
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
