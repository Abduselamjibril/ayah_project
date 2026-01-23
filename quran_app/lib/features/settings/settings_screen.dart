import 'package:flutter/material.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/ui/responsive.dart';

// Assuming these pages exist in your project structure
import 'daily_verse_settings_page.dart';
import 'about_screen.dart';
import '../downloads/downloads_screen.dart';
import 'notification_settings_page.dart';
import 'theme_settings_page.dart';
import 'language_settings_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // THEME AWARE: All styles are derived from the app's theme.
    final theme = Theme.of(context);
    final cardColor = theme.cardColor.withOpacity(0.5);
    final iconColor = theme.colorScheme.onSurface.withOpacity(0.85);
    final borderRadius = BorderRadius.circular(16);
    final hPadding = ResponsiveLayout.scaled(context, 16, min: 12, max: 22);
    final vSectionSpacing =
        ResponsiveLayout.scaled(context, 26, min: 18, max: 32);
    final toolbarHeight =
        ResponsiveLayout.scaled(context, 80, min: 64, max: 96);
    final titleSize = ResponsiveLayout.scaled(context, 32, min: 26, max: 36);
    final backIconSize = ResponsiveLayout.scaled(context, 22, min: 18, max: 26);
    final circleRadius = ResponsiveLayout.scaled(context, 20, min: 16, max: 24);
    final cardHPad = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
    final gestureVPad = ResponsiveLayout.scaled(context, 8, min: 6, max: 12);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // This is important for custom back buttons. It prevents the default one from appearing.
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: Padding(
          padding: EdgeInsets.only(
              left: ResponsiveLayout.scaled(context, 12, min: 8, max: 16)),
          // MODIFICATION: The leading widget is now part of the title's Row for better alignment.
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: CircleAvatar(
              backgroundColor: cardColor,
              radius: circleRadius,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: BrandColors.accent,
                size: backIconSize,
              ),
            ),
          ),
        ),
        toolbarHeight: toolbarHeight,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: 0,
              bottom: ResponsiveLayout.scaled(context, 24, min: 18, max: 30),
              left: ResponsiveLayout.scaled(context, 4, min: 2, max: 8),
            ),
            child: Text(
              AppLocalizations.of(context)?.translate('settings_title') ??
                  'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: titleSize,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // "Appearance" section
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              children: [
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.language_rounded,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('language_title') ??
                      'Language',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const LanguageSettingsPage()),
                  ),
                ),
                _divider(context),
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.palette_outlined,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('app_theme_title') ??
                      'App Theme',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const ThemeSettingsPage()),
                  ),
                ),
              ],
            ),
          ),
          // Gesture Toggle
          _buildGestureToggleContainer(
              context, iconColor, cardHPad, gestureVPad),
          SizedBox(height: vSectionSpacing),
          // "Content" section
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              children: [
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.download_rounded,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('downloads_title') ??
                      'Downloads',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const DownloadsScreen()),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vSectionSpacing),
          // "Notifications" section
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              children: [
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.notifications_active_outlined,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('reminders_title') ??
                      'Reminders',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const NotificationSettingsPage()),
                  ),
                ),
                _divider(context),
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.calendar_month_outlined,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('daily_inspiration_title') ??
                      'Daily Inspiration',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const DailyVerseSettingsPage()),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: vSectionSpacing),
          // "About" section
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: borderRadius,
            ),
            child: Column(
              children: [
                _settingsTile(
                  context: context,
                  iconColor: iconColor,
                  icon: Icons.info_outline_rounded,
                  label: AppLocalizations.of(
                        context,
                      )?.translate('about_app_title') ??
                      'About App',
                  onTap: () => Navigator.push(
                    context,
                    _createRoute(const AboutScreen()),
                  ),
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

  // --- HELPER WIDGETS ---

  Widget _settingsTile({
    required BuildContext context,
    required Color iconColor,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final iconSize = ResponsiveLayout.scaled(context, 26, min: 22, max: 30);
    final textSize = ResponsiveLayout.scaled(context, 16.5, min: 15, max: 18);
    final trailingSize = ResponsiveLayout.scaled(context, 18, min: 16, max: 22);
    final hPad = ResponsiveLayout.scaled(context, 18, min: 14, max: 22);
    return ListTile(
      leading: Icon(icon, color: iconColor, size: iconSize),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: textSize,
          color: theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        color: theme.colorScheme.onSurface.withOpacity(0.4),
        size: trailingSize,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: hPad, vertical: 0),
      minLeadingWidth: 0,
      dense: true,
    );
  }

  Widget _divider(BuildContext context) => Divider(
        height: 0,
        thickness: 0.7,
        indent: 60,
        endIndent: 0,
        color: Theme.of(context).dividerColor.withOpacity(0.3),
      );

  Widget _buildGestureToggleContainer(
      BuildContext context, Color iconColor, double hPad, double vPad) {
    final theme = Theme.of(context);
    bool enabled = false; // Mock; would read from SharedPreferences

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          margin: EdgeInsets.only(top: hPad + 2),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
          decoration: BoxDecoration(
            color: theme.cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(Icons.gesture_rounded,
                  color: iconColor,
                  size: ResponsiveLayout.scaled(context, 26, min: 22, max: 30)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Two-finger Search',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Drag down to search',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: (val) {
                  setState(() => enabled = val);
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setBool('search_gesture_enabled', val);
                  });
                },
                activeColor: theme.colorScheme.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  // --- HELPER METHODS ---

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        var tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              AppLocalizations.of(context)?.translate('language_title') ??
                  'Language',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          _buildLanguageOption(context, 'English', const Locale('en')),
          _buildLanguageOption(context, 'العربية', const Locale('ar')),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String name,
    Locale locale,
  ) {
    final languageService = LanguageService();
    final isSelected =
        languageService.currentLocale.languageCode == locale.languageCode;
    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).primaryColor,
            )
          : null,
      onTap: () {
        languageService.setLocale(locale);
        Navigator.pop(context);
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          AppLocalizations.of(context)?.translate('app_name') ?? 'Quran App',
        ),
        content: Text(
          AppLocalizations.of(context)?.translate('about_dialog_description') ??
              'Version 1.0.0',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('close') ?? 'Close',
            ),
          ),
        ],
      ),
    );
  }
}
