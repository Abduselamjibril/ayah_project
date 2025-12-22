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
      version: 3, // Incremented version for bookmarks/notes module
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

    // Create Bookmarks and Notes tables used by the offline module
    await _createBookmarksTable(db);
    await _createNotesTable(db);

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

    if (oldVersion < 3) {
      // Recreate bookmarks table with color, category, khatmah pin and timestamps
      await db.execute('DROP TABLE IF EXISTS bookmarks');
      await _createBookmarksTable(db);

      // Notes table for personal reflections
      await _createNotesTable(db);

      debugPrint('Database upgraded to version 3 (bookmarks/notes)');
    }
  }

  Future<void> _createBookmarksTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS bookmarks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        color_hex TEXT NOT NULL DEFAULT '#FFD54F',
        category_name TEXT,
        is_khatmah_pin INTEGER NOT NULL DEFAULT 0 CHECK (is_khatmah_pin IN (0,1)),
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(surah_id, ayah_id)
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookmarks_surah_ayah ON bookmarks (surah_id, ayah_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_bookmarks_color ON bookmarks (color_hex)');
    await db.execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmarks_khatmah_pin ON bookmarks (is_khatmah_pin) WHERE is_khatmah_pin = 1');
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_id INTEGER NOT NULL,
        ayah_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_surah_ayah ON notes (surah_id, ayah_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_created_at ON notes (created_at DESC)');
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
