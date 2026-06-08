// main.dart
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:quran_app/app/router.dart';
import 'package:quran_app/core/database/init_database.dart';
import 'package:quran_app/core/services/mushaf_settings_service.dart';
import 'package:quran_app/core/services/theme_service.dart';
import 'package:quran_app/core/services/home_widget_service.dart';
import 'package:quran_app/features/bookmarks/state/bookmark_notes_notifier.dart';
import 'package:quran_app/features/highlights/state/highlight_notifier.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:quran_app/core/services/language_service.dart';
import 'package:quran_app/core/i18n/app_localizations.dart';
import 'package:quran_app/core/services/notification_service.dart';
import 'core/services/verse_of_the_day_service.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // CRITICAL: Initialize database and seed initial data
  // Must be done before UI to ensure data availability
  await DatabaseInitializer.initializeDatabase();

  // CRITICAL: Initialize theme service and load saved theme
  // Prevents theme flicker on startup
  await ThemeService().initialize();

  // CRITICAL: Initialize language service and load saved language
  // Prevents language flicker on startup
  await LanguageService().initialize();

  // CRITICAL: Initialize mushaf settings (scroll mode, etc.)
  // Affects initial layout logic
  await MushafSettingsService().initialize();

  // Run the app immediately after critical services are ready
  runApp(const AppBootstrap());

  // NON-CRITICAL: Initialize other services in the background
  // We use a slight delay to allow the first frame to render smoothly
  Future.delayed(const Duration(milliseconds: 500), () {
    _initBackgroundServices();
  });
}

/// Initialize services that are not required for the immediate first frame
Future<void> _initBackgroundServices() async {
  try {
    debugPrint('Starting background service initialization...');

    // Initialize Notification Service (important for timezones)
    await AppNotificationService.instance.initialize();

    // Request notification permissions immediately
    // Note: This might show a dialog, so ensuring it happens after UI is ready is good
    await AppNotificationService.instance.requestPermissionsIfNeeded();

    // Initialize Verse of the Day service
    await VerseOfTheDayService.instance.initialize();

    // Keep home widget in sync with local database
    await HomeWidgetService.instance.initializeBackgroundSync();

    // Keep the screen awake while the app is open
    await WakelockPlus.enable();

    debugPrint('Background service initialization completed.');
  } catch (e) {
    debugPrint('Error in background service initialization: $e');
  }
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
        ChangeNotifierProvider(
          create: (_) => HighlightNotifier()..initialize(),
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
          title: AppLocalizations.of(context)?.translate('app_name') ??
              'Quran App',
          locale: languageService.currentLocale,
          supportedLocales: LanguageService.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          // builder: DevicePreview.appBuilder,
          localeResolutionCallback: (locale, supportedLocales) {
            // Logic is already handled in LanguageService initialization,
            // but this callback is useful if valid locale is passed from OS that matches supported.
            // However, we are forcing locale based on LanguageService.
            // So this might be redundant if we pass `locale` property.
            // When `locale` is non-null, this callback is generally not used for resolution
            // in the same way, but let's leave it default for now as we are actively setting `locale`.
            return locale;
          },
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.themeMode,
          // Use the generated route system
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/',
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
