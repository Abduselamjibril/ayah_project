// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quran_app/app/router.dart';
import 'package:quran_app/core/database/init_database.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/services/home_widget_service.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'core/services/verse_of_the_day_service.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and seed initial data
  await DatabaseInitializer.initializeDatabase();

  // Initialize theme service and load saved theme
  await ThemeService().initialize();

  // Initialize language service and load saved language
  await LanguageService().initialize();

  // Initialize mushaf settings (scroll mode, etc.)
  await MushafSettingsService().initialize();

  // Initialize Verse of the Day service
  await VerseOfTheDayService.instance.initialize();

  // Initialize Notification Service (important for timezones)
  await AppNotificationService.instance.initialize();

  // Request notification permissions immediately
  await AppNotificationService.instance.requestPermissionsIfNeeded();

  // Keep home widget in sync with local database
  await HomeWidgetService.instance.initializeBackgroundSync();

  // Keep the screen awake while the app is open
  await WakelockPlus.enable();

  // Run the app
  runApp(const AppBootstrap());
}

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BookmarkNotesNotifier()..initialize(),
        ),
      ],
      child: const MyApp(),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();
    final languageService = LanguageService();

    return AnimatedBuilder(
      animation: Listenable.merge([themeService, languageService]),
      builder: (context, child) {
        return MaterialApp(
          title: 'Quran App',
          locale: languageService.currentLocale,
          supportedLocales: LanguageService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            // Logic is already handled in LanguageService initialization,
            // but this callback is useful if valid locale is passed from OS that matches supported.
            // However, we are forcing locale based on LanguageService.
            // So this might be redundant if we pass `locale` property.
            // When `locale` is non-null, this callback is generally not used for resolution
            // in the same way, but let's leave it default for now as we are actively setting `locale`.
            return locale;
          },
          theme: themeService.themeData,
          // Use the generated route system
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/',
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
