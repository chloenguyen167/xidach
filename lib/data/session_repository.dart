import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';
import '../domain/models/player.dart';
import '../domain/models/round.dart';
import '../domain/models/rule_set.dart';
import '../domain/models/session.dart';
import '../domain/scoring/scoring_engine.dart';

/// Đọc/ghi lần chơi và các ván. Mọi thay đổi ván đều tính lại tổng trong cùng transaction.
class SessionRepository {
  SessionRepository(this._adb);

  final AppDatabase _adb;
  Database get _db => _adb.db;

  // ---------- Sessions ----------

  Future<List<GameSession>> listSessions() async {
    final rows = await _db.query('sessions', orderBy: 'updated_at DESC');
    return rows.map(_sessionFromRow).toList();
  }

  Future<GameSession?> getSession(int id) async {
    final rows = await _db.query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _sessionFromRow(rows.first);
  }

  Future<GameSession?> latestSession() async {
    final rows = await _db.query(
      'sessions',
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _sessionFromRow(rows.first);
  }

  Future<int> createSession(GameSession s) =>
      _db.insert('sessions', _sessionToRow(s)..remove('id'));

  /// Cập nhật thông tin chung (tên, người chơi...). Không đụng tới tổng.
  Future<void> updateSessionMeta(GameSession s) => _db.update(
    'sessions',
    {
      'name': s.name,
      'players_json': _encodePlayers(s.players),
      'dealer_id': s.dealerId,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    },
    where: 'id = ?',
    whereArgs: [s.id],
  );

  Future<void> deleteSession(int id) =>
      _db.delete('sessions', where: 'id = ?', whereArgs: [id]);

  /// Khôi phục lần chơi vừa xóa (Hoàn tác).
  Future<void> restoreSession(GameSession s, List<GameRound> rounds) =>
      _db.transaction((txn) async {
        await txn.insert('sessions', _sessionToRow(s));
        for (final r in rounds) {
          await txn.insert('rounds', _roundToRow(r));
        }
      });

  Future<int> countSessions() async =>
      Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM sessions'),
      ) ??
      0;

  /// Xóa toàn bộ dữ liệu chơi và thu gọn file DB.
  Future<void> deleteAllSessions() async {
    await _db.transaction((txn) async {
      await txn.delete('rounds');
      await txn.delete('sessions');
    });
    await _adb.vacuum();
  }

  // ---------- Rounds ----------

  Future<List<GameRound>> getRounds(int sessionId) async {
    final rows = await _db.query(
      'rounds',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'idx ASC',
    );
    return rows.map(_roundFromRow).toList();
  }

  Future<GameRound> addRound(GameRound r) => _db.transaction((txn) async {
    final maxIdx =
        Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT MAX(idx) FROM rounds WHERE session_id = ?',
            [r.sessionId],
          ),
        ) ??
        0;
    final withIdx = r.copyWith(idx: maxIdx + 1);
    final id = await txn.insert('rounds', _roundToRow(withIdx)..remove('id'));
    await _recompute(txn, r.sessionId);
    return withIdx.copyWith(id: id);
  });

  Future<void> updateRound(GameRound r) => _db.transaction((txn) async {
    await txn.update(
      'rounds',
      _roundToRow(r),
      where: 'id = ?',
      whereArgs: [r.id],
    );
    await _recompute(txn, r.sessionId);
  });

  Future<void> deleteRound(GameRound r) => _db.transaction((txn) async {
    await txn.delete('rounds', where: 'id = ?', whereArgs: [r.id]);
    await _recompute(txn, r.sessionId);
  });

  /// Khôi phục ván vừa xóa với đúng thứ tự cũ (Hoàn tác).
  Future<void> restoreRound(GameRound r) => _db.transaction((txn) async {
    await txn.insert('rounds', _roundToRow(r));
    await _recompute(txn, r.sessionId);
  });

  Future<void> _recompute(Transaction txn, int sessionId) async {
    final rows = await txn.query(
      'rounds',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    final totals = ScoringEngine.computeTotals(rows.map(_roundFromRow));
    await txn.update(
      'sessions',
      {
        'totals_json': jsonEncode(totals.map((k, v) => MapEntry('$k', v))),
        'round_count': rows.length,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ---------- Mapping ----------

  static String _encodePlayers(List<Player> ps) =>
      jsonEncode([for (final p in ps) p.toJson()]);

  static Map<String, Object?> _sessionToRow(GameSession s) => {
    'id': s.id,
    'name': s.name,
    'created_at': s.createdAt.millisecondsSinceEpoch,
    'updated_at': s.updatedAt.millisecondsSinceEpoch,
    'mode': s.mode.name,
    'fixed_bet': s.fixedBet,
    'rules_json': s.rules.encode(),
    'players_json': _encodePlayers(s.players),
    'dealer_id': s.dealerId,
    'totals_json': jsonEncode(s.totals.map((k, v) => MapEntry('$k', v))),
    'round_count': s.roundCount,
  };

  static GameSession _sessionFromRow(Map<String, Object?> r) {
    final totals = (jsonDecode(r['totals_json'] as String) as Map).map(
      (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()),
    );
    return GameSession(
      id: r['id'] as int,
      name: r['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(r['updated_at'] as int),
      mode: ScoringMode.fromName(r['mode'] as String),
      fixedBet: r['fixed_bet'] as int,
      rules: RuleSet.decode(r['rules_json'] as String),
      players: [
        for (final p in jsonDecode(r['players_json'] as String) as List)
          Player.fromJson(p as Map<String, Object?>),
      ],
      dealerId: r['dealer_id'] as int,
      totals: totals,
      roundCount: r['round_count'] as int,
    );
  }

  static Map<String, Object?> _roundToRow(GameRound r) => {
    'id': r.id,
    'session_id': r.sessionId,
    'idx': r.idx,
    'dealer_id': r.dealerId,
    'created_at': r.createdAt.millisecondsSinceEpoch,
    'entries_json': jsonEncode([for (final e in r.entries) e.toJson()]),
  };

  static GameRound _roundFromRow(Map<String, Object?> r) => GameRound(
    id: r['id'] as int,
    sessionId: r['session_id'] as int,
    idx: r['idx'] as int,
    dealerId: r['dealer_id'] as int,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
    entries: [
      for (final e in jsonDecode(r['entries_json'] as String) as List)
        RoundEntry.fromJson(e as Map<String, Object?>),
    ],
  );
}
