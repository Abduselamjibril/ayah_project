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
import 'core/services/audio_notification_service.dart';
import 'core/services/verse_of_the_day_service.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and seed initial data
  await DatabaseInitializer.initializeDatabase();

  // Initialize theme service and load saved theme
  await ThemeService().initialize();

  // Initialize mushaf settings (scroll mode, etc.)
  await MushafSettingsService().initialize();

  // Initialize audio notification handling
  await AudioNotificationService.instance.init();

  // Initialize Verse of the Day service
  await VerseOfTheDayService.instance.initialize();

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

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, child) {
        return MaterialApp(
          title: 'Quran App',
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
