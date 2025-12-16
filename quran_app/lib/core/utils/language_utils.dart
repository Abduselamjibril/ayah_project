/// Utility class for language code to full name mapping and flag emojis
class LanguageUtils {
  /// Map of language codes to full language names
  static const Map<String, String> languageNames = {
    'ar': 'Arabic',
    'am': 'Amharic',
    'az': 'Azerbaijani',
    'ber': 'Berber',
    'bn': 'Bengali',
    'bs': 'Bosnian',
    'ce': 'Chechen',
    'cs': 'Czech',
    'da': 'Danish',
    'de': 'German',
    'dv': 'Dhivehi',
    'en': 'English',
    'es': 'Spanish',
    'fa': 'Persian',
    'fi': 'Finnish',
    'fr': 'French',
    'ha': 'Hausa',
    'hi': 'Hindi',
    'id': 'Indonesian',
    'it': 'Italian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'ku': 'Kurdish',
    'ml': 'Malayalam',
    'ms': 'Malay',
    'nl': 'Dutch',
    'no': 'Norwegian',
    'pl': 'Polish',
    'ps': 'Pashto',
    'pt': 'Portuguese',
    'ro': 'Romanian',
    'ru': 'Russian',
    'sd': 'Sindhi',
    'so': 'Somali',
    'sq': 'Albanian',
    'sv': 'Swedish',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'tg': 'Tajik',
    'th': 'Thai',
    'tr': 'Turkish',
    'tt': 'Tatar',
    'ug': 'Uyghur',
    'ur': 'Urdu',
    'uz': 'Uzbek',
    'vi': 'Vietnamese',
    'zh': 'Chinese',

    // New languages added from the loaded list:
    'ast': 'Assamese', // ISO 639-3 'asm'
    'bgr': 'Bulgarian', // ISO 639-1 'bg'
    'dar': 'Dari', // ISO 639-3 'prs' or 639-1 'fa' (Persian/Farsi)
    'lug': 'Ganda', // Luganda (ISO 639-1 'lg')
    'gu': 'Gujarati', // ISO 639-1
    'he': 'Hebrew', // ISO 639-1 'iw' or 'he'
    'kn': 'Kannada', // ISO 639-1
    'kk': 'Kazakh', // ISO 639-1
    'km': 'Central Khmer', // ISO 639-1
    'rw': 'Kinyarwanda', // ISO 639-1
    'mrw': 'Maranao', // ISO 639-3 (No 2-letter code)
    'mr': 'Marathi', // ISO 639-1
    'ne': 'Nepali', // ISO 639-1
    'om': 'Oromo', // ISO 639-1
    'si': 'Sinhala', // Sinhala/Sinhalese (ISO 639-1)
    'tl': 'Tagalog', // ISO 639-1
    'te': 'Telugu', // ISO 639-1
    'uk': 'Ukrainian', // ISO 639-1
    'yo': 'Yoruba', // ISO 639-1
    'bm': 'Bambara', // ISO 639-1
    // Note: 'Amazigh' (Tamazight) is broadly covered by 'ber' (Berber)
    // 'albanian' and 'azeri' are covered by 'sq' and 'az'
    // 'divehi', 'dhivehi', 'maldivian' are covered by 'dv'
    // 'uighur' is covered by 'ug'
    // 'yuw' and 'yau' are likely misspellings or obscure/regional codes and are omitted for standardisation
  };

  /// Map of language codes to flag emojis
  /// Note: Using representative country flags for languages
  static const Map<String, String> languageFlags = {
    'ar': '🇸🇦', // Saudi Arabia for Arabic
    'am': '🇪🇹', // Ethiopia for Amharic
    'az': '🇦🇿', // Azerbaijan
    'ber': '🇲🇦', // Morocco for Berber (Amazigh)
    'bn': '🇧🇩', // Bangladesh
    'bs': '🇧🇦', // Bosnia
    'ce': '🇷🇺', // Russia for Chechen
    'cs': '🇨🇿', // Czech Republic
    'da': '🇩🇰', // Denmark
    'de': '🇩🇪', // Germany
    'dv': '🇲🇻', // Maldives for Dhivehi
    'en': '🇬🇧', // UK for English
    'es': '🇪🇸', // Spain
    'fa': '🇮🇷', // Iran for Persian
    'fi': '🇫🇮', // Finland
    'fr': '🇫🇷', // France
    'ha': '🇳🇬', // Nigeria for Hausa
    'hi': '🇮🇳', // India for Hindi
    'id': '🇮🇩', // Indonesia
    'it': '🇮🇹', // Italy
    'ja': '🇯🇵', // Japan
    'ko': '🇰🇷', // South Korea
    'ku': '🇮🇶', // Iraq for Kurdish
    'ml': '🇮🇳', // India for Malayalam
    'ms': '🇲🇾', // Malaysia for Malay
    'nl': '🇳🇱', // Netherlands
    'no': '🇳🇴', // Norway
    'pl': '🇵🇱', // Poland
    'ps': '🇦🇫', // Afghanistan for Pashto (Dari is also often spoken in AF)
    'pt': '🇵🇹', // Portugal
    'ro': '🇷🇴', // Romania
    'ru': '🇷🇺', // Russia
    'sd': '🇵🇰', // Pakistan for Sindhi
    'so': '🇸🇴', // Somalia
    'sq': '🇦🇱', // Albania
    'sv': '🇸🇪', // Sweden
    'sw': '🇹🇿', // Tanzania for Swahili
    'ta': '🇮🇳', // India for Tamil
    'tg': '🇹🇯', // Tajikistan
    'th': '🇹🇭', // Thailand
    'tr': '🇹🇷', // Turkey
    'tt': '🇷🇺', // Russia for Tatar
    'ug': '🇨🇳', // China for Uyghur
    'ur': '🇵🇰', // Pakistan for Urdu
    'uz': '🇺🇿', // Uzbekistan
    'vi': '🇻🇳', // Vietnam
    'zh': '🇨🇳', // China

    // New flags added:
    'ast': '🇮🇳', // India for Assamese
    'bgr': '🇧🇬', // Bulgaria for Bulgarian
    'dar': '🇦🇫', // Afghanistan for Dari
    'lug': '🇺🇬', // Uganda for Ganda
    'gu': '🇮🇳', // India for Gujarati
    'he': '🇮🇱', // Israel for Hebrew
    'kn': '🇮🇳', // India for Kannada
    'kk': '🇰🇿', // Kazakhstan for Kazakh
    'km': '🇰🇭', // Cambodia for Central Khmer
    'rw': '🇷🇼', // Rwanda for Kinyarwanda
    'mrw': '🇵🇭', // Philippines for Maranao
    'mr': '🇮🇳', // India for Marathi
    'ne': '🇳🇵', // Nepal for Nepali
    'om': '🇪🇹', // Ethiopia for Oromo
    'si': '🇱🇰', // Sri Lanka for Sinhala/Sinhalese
    'tl': '🇵🇭', // Philippines for Tagalog
    'te': '🇮🇳', // India for Telugu
    'uk': '🇺🇦', // Ukraine for Ukrainian
    'yo': '🇳🇬', // Nigeria for Yoruba
    'bm': '🇲🇱', // Mali for Bambara
  };

  /// Get full language name from code
  /// Returns the code itself if not found
  static String getLanguageName(String code) {
    final lowerCode = code.toLowerCase();
    return languageNames[lowerCode] ?? code.toUpperCase();
  }

  /// Get flag emoji for language code
  /// Returns empty string if not found
  static String getLanguageFlag(String code) {
    final lowerCode = code.toLowerCase();
    return languageFlags[lowerCode] ?? '';
  }

  /// Get combined display name with flag
  /// Format: "🇬🇧 English" or just "English" if no flag
  static String getDisplayName(String code) {
    final flag = getLanguageFlag(code);
    final name = getLanguageName(code);
    return flag.isNotEmpty ? '$flag $name' : name;
  }
}
