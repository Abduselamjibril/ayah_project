import 'package:flutter/material.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/quran/data/suwar.dart';

/// Returns the localized name of the Surah based on the current locale.
///
/// - For Arabic/Urdu: Returns the Arabic script name (e.g., الفاتحة).
/// - For others: Returns the localized meaning if available (e.g., "The Opening"),
///   or falls back to the transliterated name as a safety net.
String getLocalizedSurahName(BuildContext context, int surahNumber) {
  if (surahNumber < 1 || surahNumber > 114) return 'Unknown';

  final surahInfo = surah[surahNumber - 1];
  final locale = AppLocalizations.of(context)?.locale.languageCode;

  // Use Arabic script for Arabic and Urdu
  if (locale == 'ar' || locale == 'ur') {
    return surahInfo['arabic'] ?? surahInfo['name'];
  }

  // Try to get localized meaning from JSON
  String meaningKey = 'surah_meaning_$surahNumber';
  String? localizedMeaning =
      AppLocalizations.of(context)?.translate(meaningKey);

  // If translation exists and isn't just the key itself
  if (localizedMeaning != null &&
      localizedMeaning != meaningKey &&
      localizedMeaning.isNotEmpty) {
    return localizedMeaning;
  }

  // Fallback to English name (transliteration or translation per dataset)
  return surahInfo['english'] ?? surahInfo['name'];
}
