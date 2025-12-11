// lib/core/utils/language_utils.dart

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
  };

  /// Map of language codes to flag emojis
  /// Note: Using representative country flags for languages
  static const Map<String, String> languageFlags = {
    'ar': '🇸🇦', // Saudi Arabia for Arabic
    'am': '🇪🇹', // Ethiopia for Amharic
    'az': '🇦🇿', // Azerbaijan
    'ber': '🇲🇦', // Morocco for Berber
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
    'ps': '🇦🇫', // Afghanistan for Pashto
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
