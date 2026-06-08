import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../models/bookmark.dart';
import '../models/note.dart';

class BookmarkNotesRepository {
  BookmarkNotesRepository({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<Database> get _db async => _database.database;

  Future<List<Bookmark>> getAllBookmarks({String? colorHex}) async {
    final db = await _db;
    final rows = await db.query(
      'bookmarks',
      where: colorHex != null ? 'color_hex = ?' : null,
      whereArgs: colorHex != null ? [colorHex] : null,
      orderBy: 'created_at DESC',
    );
    return rows.map(Bookmark.fromMap).toList();
  }

  Future<Bookmark?> getBookmarkForVerse(int surahId, int ayahId) async {
    final db = await _db;
    final rows = await db.query(
      'bookmarks',
      where: 'surah_id = ? AND ayah_id = ?',
      whereArgs: [surahId, ayahId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  Future<Bookmark?> getKhatmahPin() async {
    final db = await _db;
    final rows = await db.query(
      'bookmarks',
      where: 'is_khatmah_pin = 1',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Bookmark.fromMap(rows.first);
  }

  Future<Bookmark> upsertBookmark({
    required int surahId,
    required int ayahId,
    String colorHex = '#FFD54F',
    String? categoryName,
    bool isKhatmahPin = false,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    final bookmark = await db.transaction((txn) async {
      if (isKhatmahPin) {
        await txn.delete(
          'bookmarks',
          where: 'is_khatmah_pin = 1 OR category_name = ?',
          whereArgs: ['Last read'],
        );
      } else {
        await txn.delete(
          'bookmarks',
          where: 'color_hex = ? AND is_khatmah_pin = 0',
          whereArgs: [colorHex],
        );
      }

      await txn.insert(
        'bookmarks',
        {
          'surah_id': surahId,
          'ayah_id': ayahId,
          'color_hex': colorHex,
          'category_name': categoryName,
          'is_khatmah_pin': isKhatmahPin ? 1 : 0,
          'created_at': now,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final rows = await txn.query(
        'bookmarks',
        where: 'surah_id = ? AND ayah_id = ?',
        whereArgs: [surahId, ayahId],
        limit: 1,
      );
      return Bookmark.fromMap(rows.first);
    });

    return bookmark;
  }

  Future<void> deleteBookmarkForVerse(int surahId, int ayahId) async {
    final db = await _db;
    await db.delete(
      'bookmarks',
      where: 'surah_id = ? AND ayah_id = ?',
      whereArgs: [surahId, ayahId],
    );
  }

  Future<void> clearKhatmahPin() async {
    final db = await _db;
    await db.delete(
      'bookmarks',
      where: 'is_khatmah_pin = 1 OR category_name = ?',
      whereArgs: ['Last read'],
    );
  }

  Future<List<NoteModel>> notesForVerse(int surahId, int ayahId) async {
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'surah_id = ? AND ayah_id = ?',
      whereArgs: [surahId, ayahId],
      orderBy: 'updated_at DESC',
    );
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<NoteModel> upsertNote({
    required int surahId,
    required int ayahId,
    required String content,
  }) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    final note = await db.transaction((txn) async {
      final existing = await txn.query(
        'notes',
        where: 'surah_id = ? AND ayah_id = ?',
        whereArgs: [surahId, ayahId],
        limit: 1,
      );

      if (existing.isEmpty) {
        final id = await txn.insert('notes', {
          'surah_id': surahId,
          'ayah_id': ayahId,
          'content': content,
          'created_at': now,
          'updated_at': now,
        });
        return NoteModel(
          id: id,
          surahId: surahId,
          ayahId: ayahId,
          content: content,
          createdAt: DateTime.parse(now),
          updatedAt: DateTime.parse(now),
        );
      }

      final target = existing.first;
      await txn.update(
        'notes',
        {
          'content': content,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [target['id']],
      );
      return NoteModel.fromMap({
        ...target,
        'content': content,
        'updated_at': now,
      });
    });

    return note;
  }

  Future<void> deleteNoteById(int id) async {
    final db = await _db;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteNotesForVerse(int surahId, int ayahId) async {
    final db = await _db;
    await db.delete(
      'notes',
      where: 'surah_id = ? AND ayah_id = ?',
      whereArgs: [surahId, ayahId],
    );
  }

  Future<List<NoteModel>> getAllNotes() async {
    final db = await _db;
    final rows = await db.query('notes', orderBy: 'updated_at DESC');
    if (rows.length > 200) {
      return compute(_mapNotes, rows);
    }
    return rows.map(NoteModel.fromMap).toList();
  }

  Future<List<NoteModel>> searchNotes(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final db = await _db;
    final rows = await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['%$trimmed%'],
      orderBy: 'updated_at DESC',
    );

    // Offload mapping for larger result sets to keep UI smooth
    if (rows.length > 120) {
      return compute(_mapNotes, rows);
    }
    return rows.map(NoteModel.fromMap).toList();
  }
}

List<NoteModel> _mapNotes(List<Map<String, Object?>> rows) {
  return rows.map(NoteModel.fromMap).toList();
}
