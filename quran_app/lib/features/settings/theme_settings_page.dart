import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
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
        ResponsiveLayout.scaled(context, 132, min: 110, max: 150);
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
          label: Text(
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
              Padding(
                padding: EdgeInsets.only(bottom: titleSpacing),
                child: Text(
                  'Theme Selection',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: ResponsiveLayout.scaled(context, 18,
                          min: 16, max: 20)),
                ),
              ),
              // Theme list - vertical layout
              _buildThemeCard(
                context,
                theme: AppTheme.goldenParchment,
                isSelected:
                    themeService.currentTheme == AppTheme.goldenParchment,
              ),
              SizedBox(height: sectionGap),
              _buildThemeCard(
                context,
                theme: AppTheme.midnightBlueprint,
                isSelected:
                    themeService.currentTheme == AppTheme.midnightBlueprint,
              ),
              SizedBox(height: sectionGap),
              _buildThemeCard(
                context,
                theme: AppTheme.mintGarden,
                isSelected: themeService.currentTheme == AppTheme.mintGarden,
              ),
              SizedBox(height: sectionGap),
              _buildThemeCard(
                context,
                theme: AppTheme.ornateTwilight,
                isSelected:
                    themeService.currentTheme == AppTheme.ornateTwilight,
              ),
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

  Widget _buildThemeCard(
    BuildContext context, {
    required AppTheme theme,
    required bool isSelected,
  }) {
    final cardHeight = ResponsiveLayout.scaled(context, 80, min: 68, max: 96);
    final imagePath = ThemeService.getMainframeImagePath(theme);
    final themeName = ThemeService.getThemeName(theme);

    return GestureDetector(
      onTap: () {
        ThemeService().setTheme(theme);
      },
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Full width image showing right side
              Positioned.fill(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment
                        .centerLeft, // This shows the RIGHT side of the image
                    widthFactor: 0.5, // Show only right half
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                    ),
                  ),
                ),
              ),
              // Gradient overlay for smooth transition from text to image
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Theme.of(context).scaffoldBackgroundColor,
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.95),
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.8),
                        Theme.of(context)
                            .scaffoldBackgroundColor
                            .withOpacity(0.5),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.45, 0.6, 0.75],
                    ),
                  ),
                ),
              ),
              // Theme name and checkmark on top
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveLayout.scaled(context, 16,
                          min: 12, max: 20)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          themeName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: ResponsiveLayout.scaled(context, 16,
                                min: 14, max: 18),
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(
                          Icons.check_circle,
                          color: Theme.of(context).primaryColor,
                          size: ResponsiveLayout.scaled(context, 24,
                              min: 20, max: 28),
                        ),
                    ],
                  ),
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
