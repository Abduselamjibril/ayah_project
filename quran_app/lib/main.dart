// main.dart
import 'package:flutter/material.dart';
import 'app/app.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quran App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const App(), // Your main app widget
      debugShowCheckedModeBanner: false,
    );
  }
}
