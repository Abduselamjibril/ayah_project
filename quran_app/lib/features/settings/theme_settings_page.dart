import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import '../../core/quran/widgets/quran_pageview.dart';
import '../../core/services/mushaf_settings_service.dart';
import '../../core/services/theme_service.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final mushafSettings = MushafSettingsService();
    final theme = Theme.of(context);
    final accent = BrandColors.accent;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 120,
        leading: TextButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: accent, size: 18),
          label: Text(
            'Settings',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              color: accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: TextButton.styleFrom(padding: const EdgeInsets.only(left: 8)),
        ),
        title: Text(
          'App Appearance',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([themeService, mushafSettings]),
        builder: (context, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Theme Selection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              // Theme list - vertical layout
              _buildThemeCard(
                context,
                theme: AppTheme.goldenParchment,
                isSelected:
                    themeService.currentTheme == AppTheme.goldenParchment,
              ),
              const SizedBox(height: 12),
              _buildThemeCard(
                context,
                theme: AppTheme.midnightBlueprint,
                isSelected:
                    themeService.currentTheme == AppTheme.midnightBlueprint,
              ),
              const SizedBox(height: 12),
              _buildThemeCard(
                context,
                theme: AppTheme.mintGarden,
                isSelected: themeService.currentTheme == AppTheme.mintGarden,
              ),
              const SizedBox(height: 12),
              _buildThemeCard(
                context,
                theme: AppTheme.ornateTwilight,
                isSelected:
                    themeService.currentTheme == AppTheme.ornateTwilight,
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.fromLTRB(0, 8, 0, 8),
                child: Text(
                  'Mushaf Layout',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
    final imagePath = ThemeService.getMainframeImagePath(theme);
    final themeName = ThemeService.getThemeName(theme);

    return GestureDetector(
      onTap: () {
        ThemeService().setTheme(theme);
      },
      child: Container(
        height: 80,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          themeName,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
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
                          size: 24,
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
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
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
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).primaryColor : null,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
            : null,
        onTap: onSelect,
      ),
    );
  }
}
