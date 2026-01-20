// lib/core/database/init_database.dart
import 'package:sqflite/sqflite.dart';
import 'app_database.dart';
import 'package:quran_app/core/services/translation_service.dart';
import 'package:quran_app/core/services/tafsir_service.dart';

class DatabaseInitializer {
  static Future<void> initializeDatabase() async {
    try {
      // This will create/initialize the database
      final database = await AppDatabase.instance.database;

      // Verify database is initialized
      print('Database initialized successfully');
      print('Database path: ${database.path}');

      // Initialize Translation and Tafsir Services
      await _initializeServices();

      // Optional: Seed initial data
      // await _seedInitialData(database);
    } catch (e) {
      print('Error initializing database: $e');
      rethrow; // Re-throw to prevent app from running with failed database
    }
  }

  /// Initialize app services
  static Future<void> _initializeServices() async {
    try {
      // Initialize Translation Service
      await TranslationService.instance.initialize();

      // Initialize Tafsir Service
      await TafsirService.instance.initialize();

      // Optional: Seed common translations and tafsir
      // Uncomment the lines below to pre-load common verses
      // await TranslationService.instance.seedCommonTranslations();
      // await TafsirService.instance.seedCommonTafsirs();

      print('Translation and Tafsir services initialized successfully');
    } catch (e) {
      print('Error initializing services: $e');
      // Don't re-throw - app can still work without translations
    }
  }

  /// Optional: Method to seed initial data
  static Future<void> _seedInitialData(Database db) async {
    try {
      // Check if data already exists
      final count = await db.rawQuery('SELECT COUNT(*) as count FROM metadata');
      final recordCount = count[0]['count'] as int;

      if (recordCount == 0) {
        // Seed initial metadata
        await db.insert('metadata', {
          'key': 'app_version',
          'value': '1.0.0',
        });

        await db.insert('metadata', {
          'key': 'data_version',
          'value': '1.0.0',
        });

        print('Initial data seeded successfully');
      }
    } catch (e) {
      print('Error seeding initial data: $e');
    }
  }
}
