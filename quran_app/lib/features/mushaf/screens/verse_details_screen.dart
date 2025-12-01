// lib/features/mushaf/screens/verse_details_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/core/services/tafsir_service.dart';
import 'package:quran_app/core/quran/data/suwar.dart';
import 'package:quran_app/core/quran/data/quran_text.dart';

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

  String? _translation;
  String? _tafsir;
  bool _isLoadingTranslation = false;
  bool _isLoadingTafsir = false;

  String _selectedLanguage = 'English';
  String _selectedTafsirLanguage = 'Arabic';

  @override
  void initState() {
    super.initState();
    _loadTranslation();
    _loadTafsir();
  }

  Future<void> _loadTranslation() async {
    setState(() => _isLoadingTranslation = true);
    try {
      final translation = await _translationService.getTranslation(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        language: _selectedLanguage,
      );
      setState(() {
        _translation = translation;
        _isLoadingTranslation = false;
      });
    } catch (e) {
      setState(() => _isLoadingTranslation = false);
      print('Error loading translation: $e');
    }
  }

  Future<void> _loadTafsir() async {
    setState(() => _isLoadingTafsir = true);
    try {
      final tafsir = await _tafsirService.getTafsir(
        surahNumber: widget.surahNumber,
        ayahNumber: widget.ayahNumber,
        language: _selectedTafsirLanguage,
      );
      setState(() {
        _tafsir = tafsir;
        _isLoadingTafsir = false;
      });
    } catch (e) {
      setState(() => _isLoadingTafsir = false);
      print('Error loading tafsir: $e');
    }
  }

  String _getArabicText() {
    try {
      // Find the verse in quranText
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
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
      color: const Color(0xFFF5F5DC), // Parchment color
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Arabic Text',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
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
                fontFamily: 'Traditional Arabic',
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
                const Text(
                  'Translation',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedLanguage,
                  items: _translationService
                      .getAvailableLanguages()
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ))
                      .toList(),
                  onChanged: (newLang) {
                    if (newLang != null) {
                      setState(() => _selectedLanguage = newLang);
                      _loadTranslation();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoadingTranslation
                ? const Center(child: CircularProgressIndicator())
                : _translation != null
                    ? Text(
                        _translation!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                      )
                    : const Text(
                        'Translation not available',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tafsir (Interpretation)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedTafsirLanguage,
                  items: _tafsirService
                      .getAvailableLanguages()
                      .map((lang) => DropdownMenuItem(
                            value: lang,
                            child: Text(lang),
                          ))
                      .toList(),
                  onChanged: (newLang) {
                    if (newLang != null) {
                      setState(() => _selectedTafsirLanguage = newLang);
                      _loadTafsir();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _isLoadingTafsir
                ? const Center(child: CircularProgressIndicator())
                : _tafsir != null
                    ? Text(
                        _tafsir!,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.5,
                        ),
                        textDirection:
                            _selectedTafsirLanguage.toLowerCase() == 'arabic'
                                ? TextDirection.rtl
                                : TextDirection.ltr,
                      )
                    : const Text(
                        'Tafsir not available',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      ),
          ],
        ),
      ),
    );
  }
}
