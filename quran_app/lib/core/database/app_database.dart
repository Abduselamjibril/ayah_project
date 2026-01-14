// lib/core/database/app_database.dart
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:quran_app/core/utils/arabic_normalizer.dart';

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
      version: 5, // Incremented version for FTS normalization
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

    // Create other core tables
    await _createTranslationsTable(db);
    await _createTafsirTable(db);
    await _createBookmarksTable(db);
    await _createNotesTable(db);

    // Create FTS tables
    await _createFtsTables(db);
  }

  Future<void> _createFtsTables(Database db) async {
    // FTS4 tables for ayahs and translations
    await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS ayahs_fts USING fts4(text, surah_number, ayah_number)');
    await db.execute(
        'CREATE VIRTUAL TABLE IF NOT EXISTS translations_fts USING fts4(text, surah_number, ayah_number, language)');

    // Triggers
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ayahs_ai AFTER INSERT ON ayahs BEGIN
        INSERT INTO ayahs_fts(docid, text, surah_number, ayah_number) VALUES (new.id, new.text, new.surah_number, new.ayah_number);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ayahs_ad AFTER DELETE ON ayahs BEGIN
        DELETE FROM ayahs_fts WHERE docid = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS ayahs_au AFTER UPDATE ON ayahs BEGIN
        DELETE FROM ayahs_fts WHERE docid = old.id;
        INSERT INTO ayahs_fts(docid, text, surah_number, ayah_number) VALUES (new.id, new.text, new.surah_number, new.ayah_number);
      END;
    ''');

    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS translations_ai AFTER INSERT ON translations BEGIN
        INSERT INTO translations_fts(docid, text, surah_number, ayah_number, language) VALUES (new.id, new.text, new.surah_number, new.ayah_number, new.language);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS translations_ad AFTER DELETE ON translations BEGIN
        DELETE FROM translations_fts WHERE docid = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS translations_au AFTER UPDATE ON translations BEGIN
        DELETE FROM translations_fts WHERE docid = old.id;
        INSERT INTO translations_fts(docid, text, surah_number, ayah_number, language) VALUES (new.id, new.text, new.surah_number, new.ayah_number, new.language);
      END;
    ''');
  }

  Future<void> _syncFtsTables(Database db) async {
    // Initial sync of existing data into FTS tables
    await db.execute('DELETE FROM ayahs_fts');
    await db.execute(
        'INSERT INTO ayahs_fts(docid, text, surah_number, ayah_number) SELECT id, text, surah_number, ayah_number FROM ayahs');

    await db.execute('DELETE FROM translations_fts');
    await db.execute(
        'INSERT INTO translations_fts(docid, text, surah_number, ayah_number, language) SELECT id, text, surah_number, ayah_number, language FROM translations');
  }

  // ...

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfNotExists(
          db, 'translations', 'edition_identifier', 'TEXT');
      await _addColumnIfNotExists(db, 'tafsir', 'edition_identifier', 'TEXT');
      debugPrint('Database upgraded to version 2');
    }

    if (oldVersion < 3) {
      await db.execute('DROP TABLE IF EXISTS bookmarks');
      await _createBookmarksTable(db);
      await _createNotesTable(db);
      debugPrint('Database upgraded to version 3 (bookmarks/notes)');
    }

    if (oldVersion < 4) {
      await _createFtsTables(db);
      await _syncFtsTables(db);
      debugPrint('Database upgraded to version 4 (FTS Support)');
    }

    if (oldVersion < 5) {
      // Rebuild FTS with normalization for correct Arabic search
      await _rebuildFtsWithNormalization(db);
      debugPrint('Database upgraded to version 5 (Normalized FTS)');
    }
  }

  Future<void> _rebuildFtsWithNormalization(Database db) async {
    debugPrint('Rebuilding FTS tables with normalization...');

    // 1. Clear existing FTS data
    await db.execute('DELETE FROM ayahs_fts');

    // 2. Fetch all Ayahs
    final ayahs = await db
        .query('ayahs', columns: ['id', 'text', 'surah_number', 'ayah_number']);

    // 3. Batch insert normalized text
    final batch = db.batch();
    for (final a in ayahs) {
      final text = a['text'] as String;
      final normalized = ArabicNormalizer.normalize(text);
      batch.rawInsert(
          'INSERT INTO ayahs_fts(docid, text, surah_number, ayah_number) VALUES (?, ?, ?, ?)',
          [a['id'], normalized, a['surah_number'], a['ayah_number']]);
    }
    await batch.commit(noResult: true);

    // 4. Update translations (copy as is, usually doesn't need tricky normalization)
    await db.execute('DELETE FROM translations_fts');
    await db.execute(
        'INSERT INTO translations_fts(docid, text, surah_number, ayah_number, language) SELECT id, text, surah_number, ayah_number, language FROM translations');

    debugPrint('FTS tables rebuilt successfully.');
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

  Future<void> _createTranslationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        language TEXT NOT NULL,
        edition_identifier TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_translations_surah_ayah ON translations (surah_number, ayah_number)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_translations_language ON translations (language)');
  }

  Future<void> _createTafsirTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tafsir (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        surah_number INTEGER NOT NULL,
        ayah_number INTEGER NOT NULL,
        text TEXT NOT NULL,
        author TEXT,
        edition_identifier TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tafsir_surah_ayah ON tafsir (surah_number, ayah_number)');
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
