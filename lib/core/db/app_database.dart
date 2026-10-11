import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/models/rule_set.dart';

/// SQLite cục bộ. Android dùng SQLite có sẵn của hệ thống nên không tăng dung lượng app.
class AppDatabase {
  AppDatabase._(this.db, this.path);

  final Database db;
  final String path;

  static const fileName = 'xidach.db';
  static const version = 1;

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? p.join(await f.getDatabasesPath(), fileName);
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      ),
    );
    return AppDatabase._(db, dbPath);
  }

  static Future<void> _onCreate(Database db, int version) async {
    final b = db.batch();
    b.execute('''
      CREATE TABLE sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        mode TEXT NOT NULL,
        fixed_bet INTEGER NOT NULL DEFAULT 0,
        rules_json TEXT NOT NULL,
        players_json TEXT NOT NULL,
        dealer_id INTEGER NOT NULL,
        totals_json TEXT NOT NULL DEFAULT '{}',
        round_count INTEGER NOT NULL DEFAULT 0
      )''');
    b.execute('''
      CREATE TABLE rounds(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        idx INTEGER NOT NULL,
        dealer_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        entries_json TEXT NOT NULL
      )''');
    b.execute('CREATE INDEX rounds_session ON rounds(session_id, idx)');
    b.execute('''
      CREATE TABLE player_groups(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        players_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )''');
    b.execute('''
      CREATE TABLE rule_presets(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        rules_json TEXT NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 0
      )''');
    b.insert('rule_presets', {
      'name': RuleSet.defaults.name,
      'rules_json': RuleSet.defaults.encode(),
      'is_builtin': 1,
    });
    await b.commit(noResult: true);
  }

  // Chỗ để thêm migration khi tăng [version].
  static Future<void> _onUpgrade(Database db, int from, int to) async {}

  /// Dung lượng file DB (bytes), kể cả WAL nếu có.
  Future<int> sizeInBytes() async {
    var total = 0;
    for (final suffix in ['', '-wal', '-journal']) {
      final f = File('$path$suffix');
      if (await f.exists()) total += await f.length();
    }
    return total;
  }

  Future<void> vacuum() => db.execute('VACUUM');

  Future<void> close() => db.close();
}
