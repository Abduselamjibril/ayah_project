import 'package:flutter/material.dart';
import 'package:quran_app/core/quran/qcf_quran.dart';
import 'package:quran_app/core/utils/localization_helper.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';

/// A draggable bottom sheet that displays surah information.
///
/// Shows surah name, number, revelation place, verse count,
/// and a list of verses with navigation buttons.
class SurahInfoSheet extends StatelessWidget {
  final int surahNumber;
  final void Function(int verseNumber) onNavigateToVerse;

  const SurahInfoSheet({
    super.key,
    required this.surahNumber,
    required this.onNavigateToVerse,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Surah name header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  getBilingualSurahName(context, surahNumber),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Info cards row
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _InfoCard(
                      title: AppLocalizations.of(context)
                              ?.translate('surah_info_number') ??
                          'Number',
                      value: surahNumber.toString(),
                    ),
                    const SizedBox(width: 12),
                    _InfoCard(
                      title: AppLocalizations.of(context)
                              ?.translate('surah_info_revelation') ??
                          'Revelation',
                      value: _localizedRevelationPlace(context, surahNumber),
                    ),
                    const SizedBox(width: 12),
                    _InfoCard(
                      title: AppLocalizations.of(context)
                              ?.translate('surah_info_verse_count') ??
                          'Verse Count',
                      value: getVerseCount(surahNumber).toString(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 24),
              // Verse list
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: getVerseCount(surahNumber),
                  itemBuilder: (context, index) {
                    final verseNumber = index + 1;
                    return _VerseListTile(
                      verseNumber: verseNumber,
                      verseText: getVerse(surahNumber, verseNumber),
                      onNavigate: () => onNavigateToVerse(verseNumber),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// An info card displaying a title and value.
class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title at top
            Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Value in center
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// A verse list tile with verse number, text preview, and navigate button.
class _VerseListTile extends StatelessWidget {
  final int verseNumber;
  final String verseText;
  final VoidCallback onNavigate;

  const _VerseListTile({
    required this.verseNumber,
    required this.verseText,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Navigate button with fade effect on text
          IconButton(
            icon: Icon(
              Icons.chevron_left,
              color: Theme.of(context).colorScheme.primary,
            ),
            onPressed: onNavigate,
            tooltip: AppLocalizations.of(context)?.translate('go_to_verse') ??
                'Go to verse',
          ),
          // Verse text with fade effect
          Expanded(
            child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                  colors: [
                    Colors.white,
                    Colors.white,
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.7, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: Text(
                verseText,
                maxLines: 1,
                overflow: TextOverflow.clip,
                textDirection: TextDirection.rtl,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontFamily: 'Amiri',
                      fontSize: 16,
                      height: 1.8,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Verse number on the right
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            ),
            child: Text(
              verseNumber.toString(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

String _localizedRevelationPlace(BuildContext context, int surahNumber) {
  final raw = getPlaceOfRevelation(surahNumber).toLowerCase();
  if (raw.contains('makk') || raw.contains('mecc')) {
    return AppLocalizations.of(context)?.translate('place_meccan') ?? 'Meccan';
  }
  if (raw.contains('madan') || raw.contains('medin')) {
    return AppLocalizations.of(context)?.translate('place_medinan') ??
        'Medinan';
  }
  return getPlaceOfRevelation(surahNumber);
}

/// Shows the SurahInfoSheet as a modal bottom sheet.
Future<void> showSurahInfoSheet({
  required BuildContext context,
  required int surahNumber,
  required void Function(int verseNumber) onNavigateToVerse,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SurahInfoSheet(
      surahNumber: surahNumber,
      onNavigateToVerse: onNavigateToVerse,
    ),
  );
}
