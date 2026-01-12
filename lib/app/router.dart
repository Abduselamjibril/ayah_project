// app/router.dart
import 'package:flutter/material.dart';
import '../features/mushaf/screens/mushaf_screen.dart';
import '../features/settings/settings_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MushafScreen());
      case '/settings':
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      // Add your other routes here
      // case '/bookmarks':
      //   return MaterialPageRoute(builder: (_) => const BookmarkScreen());
      // case '/tafsir':
      //   return MaterialPageRoute(builder: (_) => const TafsirScreen());
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('No route defined for ${settings.name}')),
          ),
        );
    }
  }

  // Optional: You can also define static route names for easy reference
  static const String mushaf = '/mushaf';
  static const String bookmarks = '/bookmarks';
  static const String tafsir = '/tafsir';
  static const String settings = '/settings';
  static const String audioPlayer = '/audio-player';
  static const String downloads = '/downloads';
  static const String search = '/search';
}
