import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/quran/qcf_quran.dart';
import '../../core/services/verse_of_the_day_service.dart';
import '../../data/models/hijri_date_model.dart';
import '../../data/repositories/hijri_date_repository.dart';
import '../../core/ui/glassmorphic_card.dart';
import '../../core/services/translation_service.dart';
import '../downloads/downloads_screen.dart';

class VerseOfTheDayScreen extends StatefulWidget {
  const VerseOfTheDayScreen({super.key});

  @override
  State<VerseOfTheDayScreen> createState() => _VerseOfTheDayScreenState();
}

class _VerseOfTheDayScreenState extends State<VerseOfTheDayScreen> {
  final _service = VerseOfTheDayService.instance;
  final _hijriRepository = HijriDateRepository();

  Future<HijriDateResponse?>? _dateFuture;

  @override
  void initState() {
    super.initState();
    _dateFuture = _hijriRepository.getHijriDate(DateTime.now());
    _loadTranslation();
  }

  bool _isLoadingTranslation = true;
  bool _hasSelectedTranslation = false;
  String? _translationText;
  String? _translatorName;
  bool _showTranslation = false;

  Future<void> _loadTranslation() async {
    final service = TranslationService.instance;
    final selected = await service.getSelectedTranslation();

    if (selected != null) {
      final surah = _service.surahNumber;
      final verse = _service.verseNumber;
      if (surah != null && verse != null) {
        final text = await service.getTranslationByEdition(
          surahNumber: surah,
          ayahNumber: verse,
          editionIdentifier: selected.id.toString(),
        );

        if (mounted) {
          setState(() {
            _hasSelectedTranslation = true;
            _translatorName = selected.name;
            _translationText = text;
            _isLoadingTranslation = false;
          });
          return;
        }
      }
    }

    if (mounted) {
      setState(() {
        _hasSelectedTranslation = false;
        _isLoadingTranslation = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surah = _service.surahNumber;
    final verse = _service.verseNumber;

    if (surah == null || verse == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verse of the Day')),
        body: const Center(child: Text('No daily verse selected yet.')),
      );
    }

    final verseText = getVerseQCF(surah, verse, verseEndSymbol: false);
    final verseNumberSymbol = getVerseNumberQCF(surah, verse);
    final surahName = getSurahName(surah);
    final surahNameEn = getSurahNameEnglish(surah);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Daily Inspiration'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage(
                'assets/images/mainframe.png'), // Fallback/default background
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              theme.scaffoldBackgroundColor.withOpacity(0.9),
              BlendMode.srcOver,
            ),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Date Header
              FutureBuilder<HijriDateResponse?>(
                future: _dateFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LinearProgressIndicator(),
                    );
                  }

                  final data = snapshot.data?.data;
                  final hijri = data?.hijri.formatted ?? '';
                  final gregorian = data?.gregorian.formatted ?? '';

                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          hijri,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontFamily:
                                'Amiri', // Assuming an Arabic font is available or use default
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          gregorian,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(),

              // Verse Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: GlassmorphicCard(
                  blur: 10,
                  opacity: 0.1,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$surahName - $surahNameEn',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Directionality(
                          textDirection: TextDirection.rtl,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: verseText,
                                  style: TextStyle(
                                    fontFamily:
                                        'QCF_P${getPageNumber(surah, verse).toString().padLeft(3, '0')}',
                                    fontSize: 28,
                                    height: 1.8,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                TextSpan(
                                  text: verseNumberSymbol,
                                  style: TextStyle(
                                    fontFamily:
                                        'QCF_P${getPageNumber(surah, verse).toString().padLeft(3, '0')}',
                                    fontSize: 28,
                                    height: 1.8,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Translation Section
                        if (!_isLoadingTranslation) ...[
                          if (_hasSelectedTranslation &&
                              _translationText != null) ...[
                            AnimatedCrossFade(
                              firstChild: InkWell(
                                onTap: () =>
                                    setState(() => _showTranslation = true),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          theme.primaryColor.withOpacity(0.3),
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    color: theme.primaryColor.withOpacity(0.05),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.translate_rounded,
                                        size: 18,
                                        color: theme.primaryColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'See Translation',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                          color: theme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              secondChild: Column(
                                children: [
                                  Text(
                                    _translationText!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.5,
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '— $_translatorName',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface
                                          .withOpacity(0.5),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                              crossFadeState: _showTranslation
                                  ? CrossFadeState.showSecond
                                  : CrossFadeState.showFirst,
                              duration: const Duration(milliseconds: 300),
                            ),
                          ] else ...[
                            // Download Translation Button
                            InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DownloadsScreen(),
                                  ),
                                );
                                // Reload after returning
                                _loadTranslation();
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: theme.colorScheme.secondary
                                        .withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  color: theme.colorScheme.secondary
                                      .withOpacity(0.05),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.download_rounded,
                                      size: 18,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Download Translation',
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              onPressed: () {
                                Share.share(
                                  '$verseText\n\n$surahName ($surah:$verse)\nShared via Quran App',
                                );
                              },
                              icon: const Icon(Icons.share_rounded),
                              tooltip: 'Share',
                            ),
                            const SizedBox(width: 16),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.pop(context, {
                                  'surah': surah,
                                  'verse': verse,
                                });
                              },
                              icon: const Icon(Icons.menu_book_rounded),
                              label: const Text('Read in Mushaf'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Spacer(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
