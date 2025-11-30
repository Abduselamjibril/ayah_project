// app/app.dart
import 'package:flutter/material.dart';
import 'router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran App',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      // Use the generated route system
      onGenerateRoute: AppRouter.generateRoute,
      initialRoute:
          '/mushaf', // Start with mushaf screen, or change to your home
      debugShowCheckedModeBanner: false,
    );
  }
}
