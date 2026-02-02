import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';

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
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);
    final hPadding = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    final descPadding = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
    final tileHPad = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
    final titleSize = ResponsiveLayout.scaled(context, 16, min: 14, max: 18);

    final selectedCode = _languageService.currentLocale.languageCode;

    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: const SettingsAppBar(title: 'Language'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        children: [
          // Top bar (title is in AppBar like About)
          // Description
          Padding(
            padding: EdgeInsets.only(
              left: ResponsiveLayout.scaled(context, 4, min: 2, max: 6),
              right: ResponsiveLayout.scaled(context, 4, min: 2, max: 6),
              bottom: descPadding,
            ),
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
                  indent:
                      ResponsiveLayout.scaled(context, 18, min: 14, max: 22),
                  endIndent:
                      ResponsiveLayout.scaled(context, 18, min: 14, max: 22),
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
          SizedBox(
              height: ResponsiveLayout.scaled(context, 20, min: 14, max: 28)),
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
    final tileHPad = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
    final titleSize = ResponsiveLayout.scaled(context, 16, min: 14, max: 18);
    final hPad = ResponsiveLayout.scaled(context, tileHPad, min: 14, max: 24);
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: titleSize,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing:
          isSelected ? Icon(Icons.check_circle_rounded, color: accent) : null,
      onTap: () async {
        await _languageService.setLocale(Locale(code));
        setState(() {});
      },
    );
  }
}
