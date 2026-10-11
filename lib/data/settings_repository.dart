import 'dart:convert';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/db/app_database.dart';
import '../domain/models/enums.dart';
import '../domain/models/player.dart';
import '../domain/models/rule_set.dart';

enum OrientationPref {
  auto('Tự động'),
  portrait('Khóa dọc'),
  landscape('Khóa ngang');

  const OrientationPref(this.label);
  final String label;
}

/// Lựa chọn của lần tạo gần nhất để điền sẵn cho lần sau.
class LastSetup {
  const LastSetup({
    required this.members,
    required this.dealerIdx,
    this.ruleId,
    required this.mode,
    required this.bet,
  });

  final List<Member> members;
  final int dealerIdx;
  final int? ruleId;
  final ScoringMode mode;
  final int bet;

  String encode() => jsonEncode({
    'm': [for (final m in members) m.toJson()],
    'd': dealerIdx,
    'r': ruleId,
    'mo': mode.name,
    'b': bet,
  });

  static LastSetup? decode(String? s) {
    if (s == null) return null;
    try {
      final j = jsonDecode(s) as Map<String, Object?>;
      return LastSetup(
        members: [
          for (final m in j['m'] as List)
            Member.fromJson(m as Map<String, Object?>),
        ],
        dealerIdx: (j['d'] as num?)?.toInt() ?? 0,
        ruleId: (j['r'] as num?)?.toInt(),
        mode: ScoringMode.fromName(j['mo'] as String?),
        bet: (j['b'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Cài đặt chung lưu trong SharedPreferences.
class AppPrefs {
  const AppPrefs({
    this.themeMode = ThemeMode.system,
    this.orientation = OrientationPref.auto,
    this.keepAwake = true,
    this.haptics = true,
    this.defaultMode = ScoringMode.points,
    this.defaultBet = 10000,
    this.betChips = defaultBetChips,
    this.defaultRuleId,
    this.lastSetup,
  });

  static const defaultBetChips = [5000, 10000, 20000, 50000];

  final ThemeMode themeMode;
  final OrientationPref orientation;
  final bool keepAwake;
  final bool haptics;
  final ScoringMode defaultMode;
  final int defaultBet;
  final List<int> betChips;
  final int? defaultRuleId;
  final LastSetup? lastSetup;

  AppPrefs copyWith({
    ThemeMode? themeMode,
    OrientationPref? orientation,
    bool? keepAwake,
    bool? haptics,
    ScoringMode? defaultMode,
    int? defaultBet,
    List<int>? betChips,
    int? defaultRuleId,
    LastSetup? lastSetup,
  }) => AppPrefs(
    themeMode: themeMode ?? this.themeMode,
    orientation: orientation ?? this.orientation,
    keepAwake: keepAwake ?? this.keepAwake,
    haptics: haptics ?? this.haptics,
    defaultMode: defaultMode ?? this.defaultMode,
    defaultBet: defaultBet ?? this.defaultBet,
    betChips: betChips ?? this.betChips,
    defaultRuleId: defaultRuleId ?? this.defaultRuleId,
    lastSetup: lastSetup ?? this.lastSetup,
  );
}

class SettingsRepository {
  SettingsRepository(this._adb, this._prefs);

  final AppDatabase _adb;
  final SharedPreferences _prefs;
  Database get _db => _adb.db;

  // ---------- Prefs ----------

  static const _kTheme = 'theme';
  static const _kOrient = 'orient';
  static const _kAwake = 'awake';
  static const _kHaptics = 'haptics';
  static const _kMode = 'mode';
  static const _kBet = 'bet';
  static const _kChips = 'chips';
  static const _kRule = 'rule';
  static const _kLast = 'last';

  AppPrefs loadPrefs() {
    const d = AppPrefs();
    final chips = _prefs.getString(_kChips);
    return AppPrefs(
      themeMode:
          ThemeMode.values.elementAtOrNull(_prefs.getInt(_kTheme) ?? 0) ??
          d.themeMode,
      orientation:
          OrientationPref.values.elementAtOrNull(
            _prefs.getInt(_kOrient) ?? 0,
          ) ??
          d.orientation,
      keepAwake: _prefs.getBool(_kAwake) ?? d.keepAwake,
      haptics: _prefs.getBool(_kHaptics) ?? d.haptics,
      defaultMode: ScoringMode.fromName(_prefs.getString(_kMode)),
      defaultBet: _prefs.getInt(_kBet) ?? d.defaultBet,
      betChips: chips == null
          ? d.betChips
          : [for (final c in chips.split(',')) ?int.tryParse(c)],
      defaultRuleId: _prefs.getInt(_kRule),
      lastSetup: LastSetup.decode(_prefs.getString(_kLast)),
    );
  }

  Future<void> savePrefs(AppPrefs p) async {
    await _prefs.setInt(_kTheme, p.themeMode.index);
    await _prefs.setInt(_kOrient, p.orientation.index);
    await _prefs.setBool(_kAwake, p.keepAwake);
    await _prefs.setBool(_kHaptics, p.haptics);
    await _prefs.setString(_kMode, p.defaultMode.name);
    await _prefs.setInt(_kBet, p.defaultBet);
    await _prefs.setString(_kChips, p.betChips.join(','));
    if (p.defaultRuleId != null) await _prefs.setInt(_kRule, p.defaultRuleId!);
    if (p.lastSetup != null) {
      await _prefs.setString(_kLast, p.lastSetup!.encode());
    }
  }

  // ---------- Player groups ----------

  Future<List<PlayerGroup>> listGroups() async {
    final rows = await _db.query('player_groups', orderBy: 'updated_at DESC');
    return [
      for (final r in rows)
        PlayerGroup(
          id: r['id'] as int,
          name: r['name'] as String,
          members: [
            for (final m in jsonDecode(r['players_json'] as String) as List)
              Member.fromJson(m as Map<String, Object?>),
          ],
        ),
    ];
  }

  Future<int> saveGroup(PlayerGroup g) async {
    final row = {
      'name': g.name,
      'players_json': jsonEncode([for (final m in g.members) m.toJson()]),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (g.id == null) return _db.insert('player_groups', row);
    await _db.update('player_groups', row, where: 'id = ?', whereArgs: [g.id]);
    return g.id!;
  }

  Future<void> deleteGroup(int id) =>
      _db.delete('player_groups', where: 'id = ?', whereArgs: [id]);

  // ---------- Rule presets ----------

  Future<List<RuleSet>> listRules() async {
    final rows = await _db.query(
      'rule_presets',
      orderBy: 'is_builtin DESC, id ASC',
    );
    return [
      for (final r in rows)
        RuleSet.decode(
          r['rules_json'] as String,
          id: r['id'] as int,
          builtin: r['is_builtin'] == 1,
        ).copyWith(name: r['name'] as String),
    ];
  }

  Future<int> saveRule(RuleSet r) async {
    final row = {'name': r.name, 'rules_json': r.encode()};
    if (r.id == null) return _db.insert('rule_presets', row);
    await _db.update('rule_presets', row, where: 'id = ?', whereArgs: [r.id]);
    return r.id!;
  }

  Future<void> deleteRule(int id) => _db.delete(
    'rule_presets',
    where: 'id = ? AND is_builtin = 0',
    whereArgs: [id],
  );

  /// Khôi phục bộ luật mặc định về giá trị gốc.
  Future<void> resetBuiltinRule() => _db.update('rule_presets', {
    'name': RuleSet.defaults.name,
    'rules_json': RuleSet.defaults.encode(),
  }, where: 'is_builtin = 1');

  // ---------- Data management ----------

  Future<(int groups, int rules)> countSettings() async {
    final g =
        Sqflite.firstIntValue(
          await _db.rawQuery('SELECT COUNT(*) FROM player_groups'),
        ) ??
        0;
    final r =
        Sqflite.firstIntValue(
          await _db.rawQuery(
            'SELECT COUNT(*) FROM rule_presets WHERE is_builtin = 0',
          ),
        ) ??
        0;
    return (g, r);
  }

  /// Xóa toàn bộ dữ liệu cài đặt: nhóm người chơi, bộ luật tự tạo, cài đặt chung.
  Future<void> clearSettings() async {
    await _db.transaction((txn) async {
      await txn.delete('player_groups');
      await txn.delete('rule_presets', where: 'is_builtin = 0');
    });
    await resetBuiltinRule();
    await _prefs.clear();
    await _adb.vacuum();
  }
}
