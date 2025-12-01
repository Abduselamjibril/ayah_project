// main.dart
import 'package:flutter/material.dart';

import 'package:quran_app/app/router.dart';
import 'package:quran_app/core/database/init_database.dart';
import 'package:quran_app/core/services/theme_service.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and seed initial data
  await DatabaseInitializer.initializeDatabase();

  // Initialize theme service and load saved theme
  await ThemeService().initialize();

  // Run the app
  runApp(const MyApp());
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
          theme: themeService.lightTheme,
          darkTheme: themeService.darkTheme,
          themeMode: themeService.themeMode,
          // Use the generated route system
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/mushaf',
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
