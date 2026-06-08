import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/ui/responsive.dart';

class SettingsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? leadingLabel;

  const SettingsAppBar({super.key, required this.title, this.leadingLabel});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final leadingWidth =
        ResponsiveLayout.scaled(context, 120, min: 100, max: 140);
    final backIconSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 20);
    final backFontSize = ResponsiveLayout.scaled(context, 16, min: 14, max: 18);
    final titleFontSize =
        ResponsiveLayout.scaled(context, 18, min: 16, max: 20);

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leadingWidth: leadingWidth,
      leading: Padding(
        padding: EdgeInsets.only(
          left: ResponsiveLayout.scaled(context, 6, min: 4, max: 10),
        ),
        child: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: accent, size: backIconSize),
          label: Text(
            leadingLabel ??
              (AppLocalizations.of(context)?.translate('settings_title') ??
                'Settings'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: accent,
              fontSize: backFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: titleFontSize,
        ),
      ),
    );
  }
}
