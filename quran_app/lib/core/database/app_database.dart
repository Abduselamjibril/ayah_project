// lib/core/database/app_database.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('quran_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // Incremented version for migration
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create Ayah table
    await db.execute('''
      CREATE TABLE ayahs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        page_number INTEGER,
        juz_number INTEGER,
        text TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create Translations table
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        language TEXT NOT NULL,
        translator TEXT,
        edition_identifier TEXT,
        text TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(surah_number, ayah_number, language, translator)
      )
    ''');

    // Create Tafsir table
    await db.execute('''
      CREATE TABLE tafsir (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        language TEXT NOT NULL,
        scholar TEXT,
        edition_identifier TEXT,
        text TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(surah_number, ayah_number, language, scholar)
      )
    ''');

    // Create Bookmarks table
    await db.execute('''
      CREATE TABLE bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        page_number INTEGER,
        note TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(surah_number, ayah_number)
      )
    ''');

    // Create Metadata table for app settings and cache
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    debugPrint('Database tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2: Add edition_identifier column
      // Check if column exists before adding to prevent duplicate column errors
      await _addColumnIfNotExists(
          db, 'translations', 'edition_identifier', 'TEXT');
      await _addColumnIfNotExists(db, 'tafsir', 'edition_identifier', 'TEXT');
      debugPrint('Database upgraded to version 2');
    }
  }

  /// Helper method to add a column only if it doesn't already exist
  Future<void> _addColumnIfNotExists(
    Database db,
    String tableName,
    String columnName,
    String columnType,
  ) async {
    try {
      // Get table info to check if column exists
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final columnExists = columns.any((col) => col['name'] == columnName);

      if (!columnExists) {
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN $columnName $columnType',
        );
        debugPrint('Added column $columnName to table $tableName');
      } else {
        debugPrint(
            'Column $columnName already exists in table $tableName, skipping');
      }
    } catch (e) {
      debugPrint('Error adding column $columnName to $tableName: $e');
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
