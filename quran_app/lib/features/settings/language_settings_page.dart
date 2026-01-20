import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/services/language_service.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  late LanguageService _languageService;

  @override
  void initState() {
    super.initState();
    _languageService = LanguageService();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final cardBg = theme.cardColor.withOpacity(0.5);

    final selectedCode = _languageService.currentLocale.languageCode;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 100,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 18),
          label: Text(
            'Settings',
            style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: Text(
          'Language',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Top bar (title is in AppBar like About)
          // Description
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 18),
            child: Text(
              'Quran App supports English and Arabic. Select your preferred language below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.35,
              ),
            ),
          ),
          // Language options card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _languageTile(
                  context,
                  title: 'English',
                  code: 'en',
                  selectedCode: selectedCode,
                ),
                Divider(
                  height: 0,
                  thickness: 0.7,
                  indent: 18,
                  endIndent: 18,
                  color: theme.dividerColor.withOpacity(0.25),
                ),
                _languageTile(
                  context,
                  title: 'العربية',
                  code: 'ar',
                  selectedCode: selectedCode,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _languageTile(
    BuildContext context, {
    required String title,
    required String code,
    required String selectedCode,
  }) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final isSelected = selectedCode == code;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: accent)
          : null,
      onTap: () async {
        await _languageService.setLocale(Locale(code));
        setState(() {});
      },
    );
  }
}
