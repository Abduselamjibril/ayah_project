// lib/core/utils/language_utils.dart

/// Utility class for language code to full name mapping and flag emojis
class LanguageUtils {
  /// Map of language codes to full language names
  static const Map<String, String> languageNames = {
    'ar': 'Arabic',
    'en': 'English',
    'fr': 'French',
    'es': 'Spanish',
    'de': 'German',
    'tr': 'Turkish',
    'ur': 'Urdu',
    'id': 'Indonesian',
    'bn': 'Bengali',
    'fa': 'Persian',
    'ru': 'Russian',
    'hi': 'Hindi',
    'zh': 'Chinese',
    'pt': 'Portuguese',
    'it': 'Italian',
    'nl': 'Dutch',
    'pl': 'Polish',
    'sv': 'Swedish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'da': 'Danish',
    'ja': 'Japanese',
    'ko': 'Korean',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'ms': 'Malay',
    'sq': 'Albanian',
    'az': 'Azerbaijani',
    'bs': 'Bosnian',
    'cs': 'Czech',
    'ku': 'Kurdish',
    'ml': 'Malayalam',
    'ro': 'Romanian',
    'so': 'Somali',
    'sw': 'Swahili',
    'ta': 'Tamil',
    'tg': 'Tajik',
    'tt': 'Tatar',
    'ug': 'Uyghur',
    'uz': 'Uzbek',
  };

  /// Map of language codes to flag emojis
  /// Note: Using representative country flags for languages
  static const Map<String, String> languageFlags = {
    'ar': '🇸🇦', // Saudi Arabia for Arabic
    'en': '🇬🇧', // UK for English
    'fr': '🇫🇷', // France
    'es': '🇪🇸', // Spain
    'de': '🇩🇪', // Germany
    'tr': '🇹🇷', // Turkey
    'ur': '🇵🇰', // Pakistan for Urdu
    'id': '🇮🇩', // Indonesia
    'bn': '🇧🇩', // Bangladesh
    'fa': '🇮🇷', // Iran for Persian
    'ru': '🇷🇺', // Russia
    'hi': '🇮🇳', // India for Hindi
    'zh': '🇨🇳', // China
    'pt': '🇵🇹', // Portugal
    'it': '🇮🇹', // Italy
    'nl': '🇳🇱', // Netherlands
    'pl': '🇵🇱', // Poland
    'sv': '🇸🇪', // Sweden
    'no': '🇳🇴', // Norway
    'fi': '🇫🇮', // Finland
    'da': '🇩🇰', // Denmark
    'ja': '🇯🇵', // Japan
    'ko': '🇰🇷', // South Korea
    'vi': '🇻🇳', // Vietnam
    'th': '🇹🇭', // Thailand
    'ms': '🇲🇾', // Malaysia for Malay
    'sq': '🇦🇱', // Albania
    'az': '🇦🇿', // Azerbaijan
    'bs': '🇧🇦', // Bosnia
    'cs': '🇨🇿', // Czech Republic
    'ku': '🇮🇶', // Iraq for Kurdish (representative)
    'ml': '🇮🇳', // India for Malayalam
    'ro': '🇷🇴', // Romania
    'so': '🇸🇴', // Somalia
    'sw': '🇹🇿', // Tanzania for Swahili
    'ta': '🇮🇳', // India for Tamil
    'tg': '🇹🇯', // Tajikistan
    'tt': '🇷🇺', // Russia for Tatar
    'ug': '🇨🇳', // China for Uyghur
    'uz': '🇺🇿', // Uzbekistan
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
