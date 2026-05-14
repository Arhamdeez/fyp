/// sqflite DAO for saved/favourite routes.
/// Mirrors the pattern used by RideDb in the telemetry layer.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/saved_route.dart';

class RouteDb {
  RouteDb._();
  static final RouteDb instance = RouteDb._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'routes.db'),
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE saved_routes (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          label           TEXT    NOT NULL,
          origin_name     TEXT    NOT NULL,
          dest_name       TEXT    NOT NULL,
          origin_lat      REAL    NOT NULL,
          origin_lng      REAL    NOT NULL,
          dest_lat        REAL    NOT NULL,
          dest_lng        REAL    NOT NULL,
          saved_at        TEXT    NOT NULL,
          is_favorite     INTEGER NOT NULL DEFAULT 0,
          last_eta_minutes INTEGER,
          last_distance_km REAL
        )
      '''),
    );
    return _db!;
  }

  /// Insert or replace a saved route. Returns the new row id.
  Future<int> insert(SavedRoute route) async {
    final db = await _database;
    return db.insert(
      'saved_routes',
      route.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All rows ordered by saved_at DESC.
  Future<List<SavedRoute>> listAll() async {
    final db = await _database;
    final rows = await db.query(
      'saved_routes',
      orderBy: 'saved_at DESC',
      limit: 50,
    );
    return rows.map(SavedRoute.fromMap).toList();
  }

  /// Only favourited rows.
  Future<List<SavedRoute>> listFavorites() async {
    final db = await _database;
    final rows = await db.query(
      'saved_routes',
      where: 'is_favorite = 1',
      orderBy: 'saved_at DESC',
    );
    return rows.map(SavedRoute.fromMap).toList();
  }

  /// Recent searches (non-favourites first, up to 10).
  Future<List<SavedRoute>> listRecent({int limit = 10}) async {
    final db = await _database;
    final rows = await db.query(
      'saved_routes',
      orderBy: 'saved_at DESC',
      limit: limit,
    );
    return rows.map(SavedRoute.fromMap).toList();
  }

  Future<void> toggleFavorite(int id, {required bool isFavorite}) async {
    final db = await _database;
    await db.update(
      'saved_routes',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _database;
    await db.delete('saved_routes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearNonFavorites() async {
    final db = await _database;
    await db.delete('saved_routes', where: 'is_favorite = 0');
  }
}
