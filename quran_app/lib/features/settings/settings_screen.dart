import 'package:flutter/material.dart';
import 'package:quran_app/core/ui/glassmorphic_card.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'theme_settings_page.dart';
import 'notification_settings_page.dart';
import 'daily_verse_settings_page.dart';
import '../downloads/downloads_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('settings_title') ??
            'Settings'),
        centerTitle: false,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // Header with icon
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context)
                                ?.translate('preferences_title') ??
                            'Preferences',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        AppLocalizations.of(context)
                                ?.translate('preferences_subtitle') ??
                            'Customize your experience',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Appearance Section
          _buildSectionHeader(
              context,
              AppLocalizations.of(context)?.translate('appearance_section') ??
                  'Appearance',
              Icons.palette_rounded),

          // Language Selector
          _buildSettingCard(
            context,
            icon: Icons.language_rounded,
            title: AppLocalizations.of(context)?.translate('language_title') ??
                'Language',
            subtitle:
                AppLocalizations.of(context)?.translate('language_subtitle') ??
                    'Change app language',
            gradientColors: [
              Colors.indigo.shade400,
              Colors.indigo.shade700,
            ],
            onTap: () {
              _showLanguageSelector(context);
            },
          ),

          _buildSettingCard(
            context,
            icon: Icons.palette_outlined,
            title: AppLocalizations.of(context)?.translate('app_theme_title') ??
                'App Theme',
            subtitle:
                AppLocalizations.of(context)?.translate('app_theme_subtitle') ??
                    'Customize colors and appearance',
            gradientColors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withOpacity(0.7),
            ],
            onTap: () {
              Navigator.push(
                context,
                _createRoute(const ThemeSettingsPage()),
              );
            },
          ),

          _buildGestureToggle(context),

          const SizedBox(height: 24),

          // Content Section
          _buildSectionHeader(
              context,
              AppLocalizations.of(context)?.translate('content_section') ??
                  'Content',
              Icons.library_books_rounded),
          _buildSettingCard(
            context,
            icon: Icons.download_rounded,
            title: AppLocalizations.of(context)?.translate('downloads_title') ??
                'Downloads',
            subtitle:
                AppLocalizations.of(context)?.translate('downloads_subtitle') ??
                    'Manage translations and tafsir',
            gradientColors: [
              Colors.teal,
              Colors.teal.shade300,
            ],
            onTap: () {
              Navigator.push(
                context,
                _createRoute(const DownloadsScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // Notifications Section
          _buildSectionHeader(
              context,
              AppLocalizations.of(context)
                      ?.translate('notifications_section') ??
                  'Notifications',
              Icons.notifications_rounded),
          _buildSettingCard(
            context,
            icon: Icons.notifications_active_outlined,
            title: AppLocalizations.of(context)?.translate('reminders_title') ??
                'Reminders',
            subtitle:
                AppLocalizations.of(context)?.translate('reminders_subtitle') ??
                    'Khatmah reminders and alerts',
            gradientColors: [
              Colors.amber.shade700,
              Colors.amber.shade400,
            ],
            onTap: () {
              Navigator.push(
                context,
                _createRoute(const NotificationSettingsPage()),
              );
            },
          ),
          _buildSettingCard(
            context,
            icon: Icons.calendar_month_outlined,
            title: AppLocalizations.of(context)
                    ?.translate('daily_inspiration_title') ??
                'Daily Inspiration',
            subtitle: AppLocalizations.of(context)
                    ?.translate('daily_inspiration_subtitle') ??
                'Verse of the day settings',
            gradientColors: [
              Colors.blue.shade700,
              Colors.blue.shade400,
            ],
            onTap: () {
              Navigator.push(
                context,
                _createRoute(const DailyVerseSettingsPage()),
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _buildSectionHeader(
              context,
              AppLocalizations.of(context)?.translate('about_section') ??
                  'About',
              Icons.info_rounded),
          _buildSettingCard(
            context,
            icon: Icons.info_outline_rounded,
            title: AppLocalizations.of(context)?.translate('about_app_title') ??
                'About App',
            subtitle:
                AppLocalizations.of(context)?.translate('about_app_subtitle') ??
                    'Version and information',
            gradientColors: [
              Colors.deepPurple,
              Colors.deepPurple.shade300,
            ],
            onTap: () {
              _showAboutDialog(context);
            },
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return GlassmorphicCard(
      blur: 12.0,
      opacity: 0.1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon with gradient background
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Title and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                AppLocalizations.of(context)?.translate('language_title') ??
                    'Language',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(),
            _buildLanguageOption(context, 'English', const Locale('en')),
            _buildLanguageOption(context, 'العربية', const Locale('ar')),
            _buildLanguageOption(context, 'اردو', const Locale('ur')),
            _buildLanguageOption(context, 'Français', const Locale('fr')),
            _buildLanguageOption(context, 'Español', const Locale('es')),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
      BuildContext context, String name, Locale locale) {
    final languageService = LanguageService();
    final isSelected =
        languageService.currentLocale.languageCode == locale.languageCode;

    return ListTile(
      title: Text(name),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded,
              color: Theme.of(context).primaryColor)
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
        title: Row(
          children: [
            Icon(
              Icons.menu_book_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(AppLocalizations.of(context)?.translate('app_name') ??
                'Quran App'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)
                      ?.translate('about_dialog_description') ??
                  'A beautiful and modern Quran reading app with translations, tafsir, audio, and more.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
                AppLocalizations.of(context)?.translate('close') ?? 'Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureToggle(BuildContext context) {
    final theme = Theme.of(context);
    // Note: In a real app, this should be managed by a SettingsNotifier/Provider
    // For now, using a local state or SharedPreferences directly if needed.
    // Using ValueNotifier for demonstration, but ideally it's in the app state.
    bool enabled = false; // Mock; would read from SharedPreferences

    return StatefulBuilder(
      builder: (context, setState) {
        return GlassmorphicCard(
          blur: 12.0,
          opacity: 0.1,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepOrange, Colors.orange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.gesture_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Two-finger Search',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Drag down with two fingers to search',
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
                      // Save to SharedPreferences
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.setBool('search_gesture_enabled', val);
                      });
                    },
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 56, top: 4),
                child: Text(
                  'Enabled only in horizontal view.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
