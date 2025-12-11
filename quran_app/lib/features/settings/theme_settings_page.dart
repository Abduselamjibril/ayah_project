import 'package:flutter/material.dart';
import '../../core/quran/widgets/quran_pageview.dart';
import '../../core/services/mushaf_settings_service.dart';
import '../../core/services/theme_service.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final mushafSettings = MushafSettingsService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Appearance'),
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
              // Theme grid - 2x2 layout
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildThemeCard(
                    context,
                    theme: AppTheme.goldenParchment,
                    isSelected:
                        themeService.currentTheme == AppTheme.goldenParchment,
                  ),
                  _buildThemeCard(
                    context,
                    theme: AppTheme.midnightBlueprint,
                    isSelected:
                        themeService.currentTheme == AppTheme.midnightBlueprint,
                  ),
                  _buildThemeCard(
                    context,
                    theme: AppTheme.mintGarden,
                    isSelected:
                        themeService.currentTheme == AppTheme.mintGarden,
                  ),
                  _buildThemeCard(
                    context,
                    theme: AppTheme.forestRitual,
                    isSelected:
                        themeService.currentTheme == AppTheme.forestRitual,
                  ),
                ],
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
          child: Column(
            children: [
              // Half image preview
              Expanded(
                flex: 7,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Show top half of the mainframe image
                    Align(
                      alignment: Alignment.topCenter,
                      child: ClipRect(
                        child: Align(
                          alignment: Alignment.topCenter,
                          heightFactor: 0.5, // Show only top half
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ),
                    // Selection indicator overlay
                    if (isSelected)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Theme name
              Expanded(
                flex: 3,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: isSelected
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Theme.of(context).cardColor,
                  child: Center(
                    child: Text(
                      themeName,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
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
