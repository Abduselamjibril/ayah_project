import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import '../../core/quran/widgets/quran_pageview.dart';
import '../../core/services/mushaf_settings_service.dart';
import '../../core/services/theme_service.dart';
import 'package:quran_app/core/ui/responsive.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final mushafSettings = MushafSettingsService();
    final theme = Theme.of(context);
    final accent = BrandColors.accent;
    final leadingWidth =
        ResponsiveLayout.scaled(context, 170, min: 140, max: 210);
    final backIconSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 22);
    final backFontSize = ResponsiveLayout.scaled(context, 15, min: 13, max: 17);
    final titleFontSize =
        ResponsiveLayout.scaled(context, 18, min: 16, max: 20);
    final paddingAll = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    final sectionGap = ResponsiveLayout.scaled(context, 12, min: 8, max: 16);
    final headerGap = ResponsiveLayout.scaled(context, 24, min: 18, max: 28);
    final titleSpacing = ResponsiveLayout.scaled(context, 16, min: 12, max: 20);
    final cardHeight = ResponsiveLayout.scaled(context, 80, min: 68, max: 96);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: leadingWidth,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: accent, size: backIconSize),
          label: ConstrainedBox(
            constraints: BoxConstraints(minWidth: 60, maxWidth: 120),
            child: Text(
              AppLocalizations.of(context)?.translate('settings_title') ??
                  'Settings',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: accent,
                fontSize: backFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          style: TextButton.styleFrom(
              padding: EdgeInsets.only(
                  left: ResponsiveLayout.scaled(context, 8, min: 6, max: 12))),
        ),
        title: Text(
          'App Appearance',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, fontSize: titleFontSize),
        ),
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
                      label: 'Light',
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
                      label: 'Dark',
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
                    'Dark Mode Options',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveLayout.scaled(context, 18,
                            min: 16, max: 20)),
                  ),
                ),
                Card(
                  margin: EdgeInsets.symmetric(vertical: sectionGap / 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    title: const Text(
                      'Pure Black Background',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle:
                        const Text('Use pure black for Mushaf background'),
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
                    'Surah Header Style',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveLayout.scaled(context, 18,
                            min: 16, max: 20)),
                  ),
                ),
                // Vertical List Layout
                _buildSurahStyleCard(
                  context,
                  style: SurahHeaderStyle.golden,
                  label: 'Golden',
                  assetPath: 'assets/images/mainframe.png',
                  isSelected:
                      themeService.surahHeaderStyle == SurahHeaderStyle.golden,
                  onTap: () =>
                      themeService.setSurahHeaderStyle(SurahHeaderStyle.golden),
                ),
                SizedBox(height: sectionGap),
                _buildSurahStyleCard(
                  context,
                  style: SurahHeaderStyle.green,
                  label: 'Green',
                  assetPath: 'assets/images/green_mainframe.png',
                  isSelected:
                      themeService.surahHeaderStyle == SurahHeaderStyle.green,
                  onTap: () =>
                      themeService.setSurahHeaderStyle(SurahHeaderStyle.green),
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
                  'Mushaf Layout',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveLayout.scaled(context, 18,
                          min: 16, max: 20)),
                ),
              ),
              _buildMushafLayoutOption(
                context,
                title: 'Page View (Horizontal)',
                subtitle: 'Swipe pages one by one',
                mode: ScrollMode.horizontal,
                isSelected: mushafSettings.scrollMode == ScrollMode.horizontal,
                icon: Icons.view_day,
                onSelect: () =>
                    mushafSettings.setScrollMode(ScrollMode.horizontal),
              ),
              _buildMushafLayoutOption(
                context,
                title: 'Continuous Scroll (Vertical)',
                subtitle: 'Scroll vertically through the mushaf',
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

  Widget _buildSurahStyleCard(
    BuildContext context, {
    required SurahHeaderStyle style,
    required String label,
    required String assetPath,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final height = ResponsiveLayout.scaled(context, 80, min: 68, max: 96);
    final primary = Theme.of(context).primaryColor;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1, // Thicker border for selection
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
          color: theme.cardColor,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 1. Image on the Right
              Positioned.fill(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 0.5, // Show right half of the image space
                    child: Image.asset(
                      assetPath,
                      fit: BoxFit.cover,
                      alignment: Alignment
                          .centerRight, // Effectively show the right side of the source image
                      height: double.infinity,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),

              // 2. Gradient Overlay (Left to Right) for text readability
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.scaffoldBackgroundColor,
                        theme.scaffoldBackgroundColor.withOpacity(0.95),
                        theme.scaffoldBackgroundColor.withOpacity(0.7),
                        theme.scaffoldBackgroundColor.withOpacity(0.4),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 0.6, 0.75, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Text & Selection Indicator on the Left
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        ResponsiveLayout.scaled(context, 16, min: 12, max: 20)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: ResponsiveLayout.scaled(context, 16,
                              min: 14, max: 18),
                          color: isSelected
                              ? primary
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    if (isSelected)
                      Icon(
                        Icons.check_circle,
                        color: primary,
                        size: ResponsiveLayout.scaled(context, 24,
                            min: 20, max: 28),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    return Card(
      margin: EdgeInsets.symmetric(vertical: margin),
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
