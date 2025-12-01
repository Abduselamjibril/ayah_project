import 'package:flutter/material.dart';
import '../../../core/quran/data/suwar.dart';
import '../../../core/quran/helpers/juz_helper.dart';
import '../../../core/services/translation_service.dart';

class BilingualVerseView extends StatelessWidget {
  final int surahNumber;
  final int ayahNumber;
  final String arabicText;
  final bool showSurahHeader;
  final VoidCallback? onLongPress;
  final Color? backgroundColor;

  const BilingualVerseView({
    super.key,
    required this.surahNumber,
    required this.ayahNumber,
    required this.arabicText,
    this.showSurahHeader = false,
    this.onLongPress,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final juzNumber = JuzHelper.getJuzNumber(surahNumber, ayahNumber);
    final surahInfo = surah[surahNumber - 1]; // Surah list is 0-indexed

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Surah header (only shown at the start of a Surah)
        if (showSurahHeader) _buildSurahHeader(context, surahInfo, juzNumber),

        // Verse content
        _buildVerseContent(context),
      ],
    );
  }

  Widget _buildSurahHeader(
    BuildContext context,
    Map<String, dynamic> surahInfo,
    int juzNumber,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Surah info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${surahInfo['name']} (${surahInfo['arabic']})',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${surahInfo['english']} • Surah $surahNumber • ${surahInfo['aya']} verses',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Juz number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Juz $juzNumber',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseContent(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // English translation (left side)
            Expanded(
              flex: 1,
              child: _buildEnglishSection(context),
            ),
            const SizedBox(width: 16),
            // Divider
            Container(
              width: 1,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(width: 16),
            // Arabic text (right side)
            Expanded(
              flex: 1,
              child: _buildArabicSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnglishSection(BuildContext context) {
    return FutureBuilder<String?>(
      future: TranslationService.instance.getTranslation(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        language: 'English',
      ),
      builder: (context, snapshot) {
        final translation = snapshot.data ?? 'Loading translation...';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$surahNumber:$ayahNumber',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // English translation text
            Text(
              translation,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        );
      },
    );
  }

  Widget _buildArabicSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Arabic text
        Text(
          arabicText,
          style: TextStyle(
            fontSize: 20,
            height: 1.8,
            fontFamily: 'Amiri', // Use Arabic font if available
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        // Transliteration placeholder
        Text(
          'Transliteration', // This can be enhanced later with actual transliteration
          style: TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          ),
          textAlign: TextAlign.right,
        ),
      ],
    );
  }
}
