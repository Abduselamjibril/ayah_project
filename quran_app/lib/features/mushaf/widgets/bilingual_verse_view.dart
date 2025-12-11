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
    final surahInfo = _getSurahInfo(surahNumber);
    final juzNumber = JuzHelper.getJuzNumber(surahNumber, ayahNumber);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showSurahHeader) _buildSurahHeader(context, surahInfo, juzNumber),
        _buildVerseContent(context),
      ],
    );
  }

  Map<String, dynamic> _getSurahInfo(int surahNumber) {
    try {
      return surah[surahNumber - 1];
    } catch (e) {
      return {
        'name': 'Unknown',
        'arabic': 'غير معروف',
        'english': 'Unknown',
        'aya': 0,
      };
    }
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
          _buildSurahInfo(context, surahInfo),
          _buildJuzBadge(context, juzNumber),
        ],
      ),
    );
  }

  Widget _buildSurahInfo(BuildContext context, Map<String, dynamic> surahInfo) {
    return Expanded(
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
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJuzBadge(BuildContext context, int juzNumber) {
    return Container(
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
            Expanded(
              flex: 1,
              child: _buildEnglishSection(context),
            ),
            _buildDivider(context),
            Expanded(
              flex: 1,
              child: _buildArabicSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      width: 1,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildEnglishSection(BuildContext context) {
    return FutureBuilder<String?>(
      future: TranslationService.instance.getTranslationByEdition(
        surahNumber: surahNumber,
        ayahNumber: ayahNumber,
        editionIdentifier: 'en.asad', // Use bundled English translation
      ),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVerseBadge(context),
            const SizedBox(height: 8),
            _buildTranslationText(snapshot),
          ],
        );
      },
    );
  }

  Widget _buildVerseBadge(BuildContext context) {
    return Container(
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
    );
  }

  Widget _buildTranslationText(AsyncSnapshot<String?> snapshot) {
    final translation = snapshot.data ?? 'Loading translation...';
    final isLoading = snapshot.connectionState == ConnectionState.waiting;

    return Text(
      translation,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: isLoading ? Colors.grey : null,
        fontStyle: isLoading ? FontStyle.italic : null,
      ),
      textAlign: TextAlign.left,
    );
  }

  Widget _buildArabicSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          arabicText,
          style: TextStyle(
            fontSize: 20,
            height: 1.8,
            fontFamily: 'Amiri',
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
        ),
        const SizedBox(height: 8),
        Text(
          'Transliteration',
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
