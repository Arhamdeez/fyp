import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'ride_record.dart';

/// Local **SQLite** store for completed rides (see `rides` table).
class RideDb {
  RideDb._();
  static final RideDb instance = RideDb._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'momentum_rides.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) async {
        await db.execute('''
CREATE TABLE rides (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  started_at_ms INTEGER NOT NULL,
  ended_at_ms INTEGER NOT NULL,
  adapter_label TEXT,
  sample_count INTEGER NOT NULL,
  max_speed_kph INTEGER NOT NULL,
  max_rpm REAL NOT NULL,
  harsh_braking_count INTEGER NOT NULL,
  harsh_accel_count INTEGER NOT NULL,
  high_rpm_samples INTEGER NOT NULL,
  avg_engine_load_pct REAL,
  verdict TEXT NOT NULL
);
''');
        await db.execute('''
CREATE TABLE ride_summary_lines (
  ride_id INTEGER NOT NULL,
  line_index INTEGER NOT NULL,
  body TEXT NOT NULL,
  FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE,
  UNIQUE (ride_id, line_index)
);
''');
      },
    );
  }

  Future<int> insertRide(RideRecord record) async {
    final db = await database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('rides', record.toRowWithoutId());
      final lines = record.summaryLines;
      for (var i = 0; i < lines.length; i++) {
        await txn.insert('ride_summary_lines', {
          'ride_id': id,
          'line_index': i,
          'body': lines[i],
        });
      }
      return id;
    });
  }

  Future<RideRecord?> latestRide() async {
    final db = await database;
    final rows = await db.query(
      'rides',
      orderBy: 'ended_at_ms DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final id = rows.first['id'] as int;
    final lines = await _linesForRide(db, id);
    return RideRecord.fromRow(rows.first, lines);
  }

  Future<List<String>> _linesForRide(Database db, int rideId) async {
    final rows = await db.query(
      'ride_summary_lines',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'line_index ASC',
    );
    return rows.map((r) => r['body']! as String).toList(growable: false);
  }
}
