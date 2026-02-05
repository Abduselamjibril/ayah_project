import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../../core/quran/widgets/quran_pageview.dart';
import '../../core/services/mushaf_settings_service.dart';
import '../../core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';
import 'package:quran_app/features/settings/widgets/settings_app_bar.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final mushafSettings = MushafSettingsService();
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final isLight = theme.brightness == Brightness.light;
    final paddingAll = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    final sectionGap = ResponsiveLayout.scaled(context, 12, min: 8, max: 16);
    final headerGap = ResponsiveLayout.scaled(context, 24, min: 18, max: 28);
    final titleSpacing = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);

    return Scaffold(
      backgroundColor:
          isLight ? theme.colorScheme.surface : theme.scaffoldBackgroundColor,
      appBar: SettingsAppBar(
        title: AppLocalizations.of(context)?.translate('app_appearance') ??
            'App Appearance',
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([themeService, mushafSettings]),
        builder: (context, child) {
          return ListView(
            padding: EdgeInsets.all(paddingAll),
            children: [
              // Theme Mode Selection
              Padding(
                padding: EdgeInsets.only(bottom: titleSpacing),
                child: Text(
                  AppLocalizations.of(context)?.translate('theme_mode') ??
                      'Theme Mode',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveLayout.scaled(context, 18,
                          min: 16, max: 20)),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildThemeModeCard(
                      context,
                      mode: ThemeMode.light,
                      label: AppLocalizations.of(context)?.translate('light') ??
                          'Light',
                      icon: Icons.wb_sunny,
                      isSelected: themeService.themeMode == ThemeMode.light,
                      onTap: () => themeService.setThemeMode(ThemeMode.light),
                    ),
                  ),
                  SizedBox(width: sectionGap),
                  Expanded(
                    child: _buildThemeModeCard(
                      context,
                      mode: ThemeMode.dark,
                      label: AppLocalizations.of(context)?.translate('dark') ??
                          'Dark',
                      icon: Icons.nightlight_round,
                      isSelected: themeService.themeMode == ThemeMode.dark,
                      onTap: () => themeService.setThemeMode(ThemeMode.dark),
                    ),
                  ),
                ],
              ),

              // Pure Black Background - Only show in Dark mode
              if (themeService.themeMode == ThemeMode.dark) ...[
                SizedBox(height: headerGap),
                Padding(
                  padding: EdgeInsets.only(bottom: titleSpacing),
                  child: Text(
                    AppLocalizations.of(context)
                            ?.translate('dark_mode_options') ??
                        'Dark Mode Options',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveLayout.scaled(context, 18,
                            min: 16, max: 20)),
                  ),
                ),
                Card(
                  margin: EdgeInsets.symmetric(vertical: sectionGap / 2),
                  color:
                      isLight ? theme.scaffoldBackgroundColor : theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: Text(
                      AppLocalizations.of(context)
                              ?.translate('pure_black_background') ??
                          'Pure Black Background',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(context)
                              ?.translate('pure_black_mushaf_subtitle') ??
                          'Use pure black for Mushaf background',
                    ),
                    value: themeService.pureBlackBackground,
                    onChanged: (value) =>
                        themeService.setPureBlackBackground(value),
                    activeColor: accent,
                  ),
                ),
              ],

              // Surah Name Holder - Only show if current effective mode allows choice
              if (themeService.themeMode != ThemeMode.dark) ...[
                SizedBox(height: headerGap),
                Padding(
                  padding: EdgeInsets.only(bottom: titleSpacing),
                  child: Text(
                    AppLocalizations.of(context)
                            ?.translate('surah_header_style') ??
                        'Surah Header Style',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveLayout.scaled(context, 18,
                            min: 16, max: 20)),
                  ),
                ),
                _buildSurahHeaderStyleSelector(
                  context,
                  selectedStyle: themeService.surahHeaderStyle,
                  onSelect: themeService.setSurahHeaderStyle,
                ),
              ],

              SizedBox(height: headerGap),
              Padding(
                padding: EdgeInsets.fromLTRB(
                    0,
                    ResponsiveLayout.scaled(context, 8, min: 6, max: 12),
                    0,
                    ResponsiveLayout.scaled(context, 8, min: 6, max: 12)),
                child: Text(
                  AppLocalizations.of(context)?.translate('mushaf_layout') ??
                      'Mushaf Layout',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveLayout.scaled(context, 18,
                          min: 16, max: 20)),
                ),
              ),
              _buildMushafLayoutOption(
                context,
                title: AppLocalizations.of(context)
                        ?.translate('page_view_horizontal') ??
                    'Page View (Horizontal)',
                subtitle: AppLocalizations.of(context)
                        ?.translate('page_view_subtitle') ??
                    'Swipe pages one by one',
                mode: ScrollMode.horizontal,
                isSelected: mushafSettings.scrollMode == ScrollMode.horizontal,
                icon: Icons.view_day,
                onSelect: () =>
                    mushafSettings.setScrollMode(ScrollMode.horizontal),
              ),
              _buildMushafLayoutOption(
                context,
                title: AppLocalizations.of(context)
                        ?.translate('continuous_scroll_vertical') ??
                    'Continuous Scroll (Vertical)',
                subtitle: AppLocalizations.of(context)
                        ?.translate('continuous_scroll_subtitle') ??
                    'Scroll vertically through the mushaf',
                mode: ScrollMode.vertical,
                isSelected: mushafSettings.scrollMode == ScrollMode.vertical,
                icon: Icons.view_stream,
                onSelect: () =>
                    mushafSettings.setScrollMode(ScrollMode.vertical),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeModeCard(
    BuildContext context, {
    required ThemeMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final height = ResponsiveLayout.scaled(context, 80, min: 68, max: 96);
    final primary = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: isSelected ? primary.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected ? primary : Colors.grey,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahHeaderStyleSelector(
    BuildContext context, {
    required SurahHeaderStyle selectedStyle,
    required ValueChanged<SurahHeaderStyle> onSelect,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    final divider = theme.dividerColor.withOpacity(isLight ? 0.22 : 0.28);
    final radius = BorderRadius.circular(20);
    final selectedBg = theme.colorScheme.primary.withOpacity(isLight ? 0.06 : 0.12);

    final rowHeight = ResponsiveLayout.scaled(context, 72, min: 62, max: 80);
    final previewHeight =
        ResponsiveLayout.scaled(context, 40, min: 34, max: 46);
    final previewWidth =
        ResponsiveLayout.scaled(context, 160, min: 130, max: 190);

    Widget row({
      required SurahHeaderStyle style,
      required String label,
      required String assetPath,
      required bool isTop,
      required bool isBottom,
    }) {
      final isSelected = selectedStyle == style;
      final rowRadius = BorderRadius.vertical(
        top: isTop ? const Radius.circular(20) : Radius.zero,
        bottom: isBottom ? const Radius.circular(20) : Radius.zero,
      );

      return Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Material(
          color: isSelected ? selectedBg : Colors.transparent,
          child: InkWell(
            borderRadius: rowRadius,
            onTap: () => onSelect(style),
            child: SizedBox(
              height: rowHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: previewWidth,
                        height: previewHeight,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withOpacity(isLight ? 0.6 : 0.25),
                        child: Image.asset(
                          assetPath,
                          fit: BoxFit.cover,
                          alignment: Alignment.centerLeft,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    const Spacer(),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              key: ValueKey(style),
                              size: 30,
                              color: BrandColors.accent,
                            )
                          : const SizedBox(width: 30, height: 30),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          row(
            style: SurahHeaderStyle.golden,
            label: AppLocalizations.of(context)?.translate('style_golden') ??
                'Golden',
            assetPath: 'assets/images/mainframe.png',
            isTop: true,
            isBottom: false,
          ),
          Divider(height: 1, thickness: 1, color: divider),
          row(
            style: SurahHeaderStyle.green,
            label: AppLocalizations.of(context)?.translate('style_green') ??
                'Green',
            assetPath: 'assets/images/green_mainframe.png',
            isTop: false,
            isBottom: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMushafLayoutOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required ScrollMode mode,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onSelect,
  }) {
    final margin = ResponsiveLayout.scaled(context, 8, min: 6, max: 12);
    final iconSize = ResponsiveLayout.scaled(context, 24, min: 20, max: 28);
    final titleSize = ResponsiveLayout.scaled(context, 15, min: 14, max: 17);
    final subtitleSize = ResponsiveLayout.scaled(context, 13, min: 12, max: 15);
    final trailingSize = ResponsiveLayout.scaled(context, 24, min: 20, max: 28);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final cardBg = isLight ? theme.scaffoldBackgroundColor : theme.cardColor;
    return Card(
      margin: EdgeInsets.symmetric(vertical: margin),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSelected
              ? Theme.of(context).primaryColor.withOpacity(0.1)
              : Colors.grey.withOpacity(0.1),
          child: Icon(
            icon,
            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            size: iconSize,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : null,
            fontSize: titleSize,
          ),
        ),
        subtitle: Text(subtitle, style: TextStyle(fontSize: subtitleSize)),
        trailing: isSelected
            ? Icon(Icons.check_circle,
                color: Theme.of(context).primaryColor, size: trailingSize)
            : null,
        onTap: onSelect,
      ),
    );
  }
}
