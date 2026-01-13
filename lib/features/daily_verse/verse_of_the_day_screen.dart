import 'package:flutter/material.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../../core/quran/qcf_quran.dart';

import '../../core/services/verse_of_the_day_service.dart';
import '../../data/models/hijri_date_model.dart';
import '../../data/repositories/hijri_date_repository.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;

    if (surah == null || verse == null) {
      return Scaffold(
        appBar: AppBar(
            title: Text(AppLocalizations.of(context)
                    ?.translate('verse_of_the_day_title') ??
                'Verse of the Day')),
        body: Center(
            child: Text(
                AppLocalizations.of(context)?.translate('no_daily_verse') ??
                    'No daily verse selected yet.')),
      );
    }

    final verseText = getVerseQCF(surah, verse, verseEndSymbol: false);
    final verseNumberSymbol = getVerseNumberQCF(surah, verse);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: screenHeight * 0.96,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Spacer(),
                    Text(
                      AppLocalizations.of(context)
                              ?.translate('verse_of_the_day_title') ??
                          'Today',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.close,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.8)),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                FutureBuilder<HijriDateResponse?>(
                  future: _dateFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    final data = snapshot.data?.data;
                    final hijri = data?.hijri;
                    final greg = data?.gregorian;

                    Widget buildCard({required String month, required String day}) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                month,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                day,
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Row(
                      children: [
                        buildCard(
                          month: (hijri?.monthName ?? '').toUpperCase(),
                          day: hijri != null ? '${hijri.day}' : '--',
                        ),
                        buildCard(
                          month: (greg?.monthName ?? '').toUpperCase(),
                          day: greg != null ? '${greg.day}' : '--',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 28),
                Text(
                  AppLocalizations.of(context)
                          ?.translate('verse_of_the_day_title') ??
                      'Verse of the Day',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                  fontSize: 22,
                                  height: 1.7,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              TextSpan(
                                text: verseNumberSymbol,
                                style: TextStyle(
                                  fontFamily:
                                      'QCF_P${getPageNumber(surah, verse).toString().padLeft(3, '0')}',
                                  fontSize: 22,
                                  height: 1.7,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color:
                            theme.colorScheme.onSurface.withOpacity(0.08),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          if (_hasSelectedTranslation &&
                              _translationText != null) {
                            setState(() {
                              _showTranslation = !_showTranslation;
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              Text(
                                AppLocalizations.of(context)
                                        ?.translate('translation') ??
                                    'Translation',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showTranslation
                                    ? Icons.expand_less_rounded
                                    : Icons.chevron_right_rounded,
                                color: theme.primaryColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (!_isLoadingTranslation) ...[
                        if (_hasSelectedTranslation &&
                            _translationText != null)
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding:
                                  const EdgeInsets.only(top: 8, bottom: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _translationText ?? '',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      height: 1.6,
                                    ),
                                  ),
                                  if (_translatorName != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _translatorName!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            crossFadeState: _showTranslation
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(top: 8, bottom: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)?.translate(
                                          'no_translation_selected') ??
                                      'Select a translation to see it here',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 0),
                                    foregroundColor: theme.primaryColor,
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const DownloadsScreen(),
                                      ),
                                    );
                                    if (mounted) _loadTranslation();
                                  },
                                  icon:
                                      const Icon(Icons.download_for_offline),
                                  label: Text(
                                    AppLocalizations.of(context)?.translate(
                                            'select_translation') ??
                                        'Select Translation',
                                  ),
                                ),
                              ],
                            ),
                          )
                      ] else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop({
                        'surah': surah,
                        'verse': verse,
                      });
                    },
                    child: Text(
                      AppLocalizations.of(context)
                              ?.translate('read_in_mushaf') ??
                          'Read in Mushaf',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
