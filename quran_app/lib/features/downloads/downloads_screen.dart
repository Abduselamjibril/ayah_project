// lib/features/downloads/downloads_screen.dart
import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../../core/i18n/app_localizations.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';
import 'downloads_translations_screen.dart';
import 'downloads_tafsir_screen.dart';

import '../../core/ui/responsive.dart';
import 'downloads_audio_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.light
          ? theme.colorScheme.surface
          : theme.scaffoldBackgroundColor,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('storage_title') ??
            'Storage',
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _downloadsTile(
            context: context,
            icon: Icons.translate,
            label:
                AppLocalizations.of(context)?.translate('tab_translations') ??
                    'Translations',
            subtitle:
                AppLocalizations.of(context)?.translate('select_translation') ??
                    'Select Translation',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsTranslationsScreen(),
                ),
              );
            },
            accent: accent,
          ),
          const SizedBox(height: 12),
          _downloadsTile(
            context: context,
            icon: Icons.menu_book_outlined,
            label: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                'Tafsir',
            subtitle: AppLocalizations.of(context)?.translate('tab_tafsir') ??
                'Tafsir',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsTafsirScreen(),
                ),
              );
            },
            accent: accent,
          ),
          const SizedBox(height: 12),
          _downloadsTile(
            context: context,
            icon: Icons.volume_up,
            label:
                AppLocalizations.of(context)?.translate('tab_audio') ?? 'Audio',
            subtitle:
                AppLocalizations.of(context)?.translate('tab_audio') ?? 'Audio',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DownloadsAudioScreen(),
                ),
              );
            },
            accent: accent,
          ),
        ],
      ),
    );
  }
}

Widget _downloadsTile({
  required BuildContext context,
  required IconData icon,
  required String label,
  required String subtitle,
  required VoidCallback onTap,
  required Color accent,
}) {
  final theme = Theme.of(context);
  final isLight = theme.brightness == Brightness.light;
  final iconColor = theme.colorScheme.onSurface.withOpacity(0.85);
  final iconSize = ResponsiveLayout.scaled(context, 26, min: 22, max: 30);
  final textSize = ResponsiveLayout.scaled(context, 16.5, min: 15, max: 18);
  final trailingSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 22);
  final hPad = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
  return Card(
    color: isLight
        ? theme.scaffoldBackgroundColor
        : theme.cardColor.withOpacity(0.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    margin: EdgeInsets.zero,
    child: ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
      leading: Icon(icon, color: iconColor, size: iconSize),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: textSize,
          color: theme.colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
        size: trailingSize,
      ),
      minLeadingWidth: 0,
      dense: true,
    ),
  );
}
