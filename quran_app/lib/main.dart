// main.dart
import 'package:flutter/material.dart';
import 'package:quran_app/app/app.dart';
import 'package:quran_app/core/database/init_database.dart';

Future<void> main() async {
  // Ensure Flutter widgets are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database and seed initial data
  await DatabaseInitializer.initializeDatabase();

  // Run the app
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran App',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: false, // As recommended by quran_library package
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor:
            const Color(0xFFF5F5DC), // Parchment-like background
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: false,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1B5E20), // Dark green
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      themeMode: ThemeMode.light, // You can change this to system or dark
      home: const App(), // Your main app widget
      debugShowCheckedModeBanner: false,
    );
  }
}
