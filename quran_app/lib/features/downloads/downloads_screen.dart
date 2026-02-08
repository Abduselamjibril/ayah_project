// lib/features/downloads/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../../core/i18n/app_localizations.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';
import 'downloads_translations_screen.dart';
import 'downloads_tafsir_screen.dart';
import 'downloads_audio_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            icon: Icons.translate,
            title: AppLocalizations.of(context)?.translate('tab_translations') ??
                'Translations',
            subtitle: AppLocalizations.of(context)
                    ?.translate('select_translation') ??
                'Select Translation',
            accent: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsTranslationsScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.menu_book_outlined,
            title: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                'Tafsir',
            subtitle: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                'Tafsir',
            accent: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsTafsirScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _SectionCard(
            icon: Icons.volume_up,
            title: AppLocalizations.of(context)?.translate('tab_audio') ??
                'Audio',
            subtitle: AppLocalizations.of(context)?.translate('tab_audio') ??
                'Audio',
            accent: accent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsAudioScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBackground = isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.dividerColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.hintColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.hintColor),
          ],
        ),
      ),
    );
  }
}
