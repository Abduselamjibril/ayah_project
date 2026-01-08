// lib/core/utils/arabic_normalizer.dart

class ArabicNormalizer {
  /// Normalizes Arabic text for searching.
  /// 1. Removes Harakaat (diacritics/vowels).
  /// 2. Unifies Alifs (أ, إ, آ -> ا).
  /// 3. Unifies Yas (ى -> ي).
  /// 4. Unifies Tah Marbuta (ة -> ه) - Optional but often good for fuzzy search.
  static String normalize(String text) {
    if (text.isEmpty) return text;

    String normalized = text;

    // 1. Remove Harakaat (Unicode range U+064B to U+0652)
    final harakaatRegex = RegExp(r'[\u064B-\u0652]');
    normalized = normalized.replaceAll(harakaatRegex, '');

    // 2. Unify Alifs
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');

    // 3. Unify Yas (treating ى and ي as the same)
    normalized = normalized.replaceAll('ى', 'ي');

    // 4. Unify Tah Marbutas (Optional: treating ة and ه as the same)
    // normalized = normalized.replaceAll('ة', 'ه');

    return normalized;
  }

  /// Removes all non-Arabic characters except spaces.
  static String cleanNonArabic(String text) {
    return text.replaceAll(RegExp(r'[^\u0621-\u064A\s]'), '');
  }
}
