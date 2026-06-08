import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface.withOpacity(0.12);
    final titleFontSize =
        ResponsiveLayout.scaled(context, 18, min: 16, max: 20);
    final listHPad = ResponsiveLayout.scaled(context, 20, min: 14, max: 26);
    final logoSize = ResponsiveLayout.scaled(context, 108, min: 90, max: 132);
    final logoRadius = ResponsiveLayout.scaled(context, 24, min: 18, max: 30);
    final logoPadding = ResponsiveLayout.scaled(context, 20, min: 14, max: 24);
    final appNameSize = ResponsiveLayout.scaled(context, 32, min: 26, max: 36);
    final versionSize = ResponsiveLayout.scaled(context, 14, min: 12, max: 16);
    final sectionGap = ResponsiveLayout.scaled(context, 18, min: 14, max: 24);
    final titleGap = ResponsiveLayout.scaled(context, 6, min: 4, max: 10);
    final headerGap = ResponsiveLayout.scaled(context, 16, min: 12, max: 22);
    final logoAsset = 'assets/images/Icon.jpg';

    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: const SettingsAppBar(title: 'About'),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: listHPad),
        children: [
          SizedBox(
              height: ResponsiveLayout.scaled(context, 10, min: 8, max: 14)),
          // App Logo
          Align(
            alignment: Alignment.center,
            child: Container(
              width: logoSize,
              height: logoSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(logoRadius),
                child: Image.asset(
                  logoAsset,
                  fit: BoxFit.cover,
                  width: logoSize,
                  height: logoSize,
                ),
              ),
            ),
          ),
          SizedBox(height: headerGap),
          // App Name
          Align(
            alignment: Alignment.center,
            child: Text(
              'Quran App',
              style: TextStyle(
                fontSize: appNameSize,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(height: titleGap),
          Align(
            alignment: Alignment.center,
            child: Text(
              'Version 1.0.0',
              style: TextStyle(
                fontSize: versionSize,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          SizedBox(height: sectionGap),
          // Policy links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {},
                child: Text(
                  AppLocalizations.of(context)?.translate('privacy_policy') ??
                      'Privacy Policy',
                ),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
              SizedBox(
                  width: ResponsiveLayout.scaled(context, 12, min: 8, max: 16)),
              TextButton(
                onPressed: () {},
                child: Text(
                  AppLocalizations.of(context)?.translate('terms_of_use') ??
                      'Terms of Use',
                ),
                style: TextButton.styleFrom(foregroundColor: accent),
              ),
            ],
          ),
          SizedBox(height: sectionGap),
          // Description card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: EdgeInsets.all(
                ResponsiveLayout.scaled(context, 16, min: 12, max: 20)),
            child: Text(
              'Quran App is a focused, distraction-free Mushaf experience with'
              ' clear Arabic text, tafsir, translations, and audio recitation. '
              'Save your progress, bookmark verses, and explore daily inspiration '
              'with a clean, modern interface built for reflection and reading.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: sectionGap),
          // Share/Review card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.scaled(context, 16,
                          min: 12, max: 20),
                      vertical: ResponsiveLayout.scaled(context, 10,
                          min: 8, max: 14)),
                  title: Text(
                    'Share App',
                    style:
                        TextStyle(color: accent, fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    final message =
                        'Check out Quran App — a beautiful Mushaf with audio, bookmarks, and daily inspiration.';
                    Share.share(message, subject: 'Quran App');
                  },
                ),
              ],
            ),
          ),
          SizedBox(
              height: ResponsiveLayout.scaled(context, 32, min: 22, max: 42)),
        ],
      ),
    );
  }
}
