// app/app.dart
import 'package:flutter/material.dart';
import 'package:quran_app/core/services/theme_service.dart';

import 'router.dart';

class BrandColors {
  // Global accent used across the app regardless of theme selection.
  static const Color accent = Color(0xFF0B7743);
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService();

    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Quran App',
          theme: themeService.themeData,
          // Use the generated route system
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/', // Start with mushaf screen, or change to your home
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
