import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xidach/core/db/app_database.dart';
import 'package:xidach/data/session_repository.dart';
import 'package:xidach/data/settings_repository.dart';
import 'package:xidach/domain/models/enums.dart';
import 'package:xidach/domain/models/player.dart';
import 'package:xidach/domain/models/round.dart';
import 'package:xidach/domain/models/rule_set.dart';
import 'package:xidach/domain/models/session.dart';

void main() {
  late AppDatabase adb;
  late SessionRepository sessions;
  late SettingsRepository settings;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    adb = await AppDatabase.open(
      factory: databaseFactoryFfiNoIsolate,
      path: inMemoryDatabasePath,
    );
    sessions = SessionRepository(adb);
    settings = SettingsRepository(adb, await SharedPreferences.getInstance());
  });

  tearDown(() => adb.close());

  Future<int> newSession({RuleSet rules = const RuleSet()}) =>
      sessions.createSession(
        GameSession(
          name: 'Tối T7',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
          mode: ScoringMode.variableMoney,
          rules: rules,
          players: const [
            Player(id: 1, name: 'An', colorIdx: 0),
            Player(id: 2, name: 'Bình', colorIdx: 1),
            Player(id: 3, name: 'Chi', colorIdx: 2),
          ],
          dealerId: 1,
        ),
      );

  GameRound r(int sid, List<RoundEntry> e, {int dealer = 1}) => GameRound(
    sessionId: sid,
    idx: 0,
    dealerId: dealer,
    createdAt: DateTime.now(),
    entries: e,
  );

  test(
    'add / edit / delete / restore rounds keep cached totals correct',
    () async {
      final sid = await newSession();
      final r1 = await sessions.addRound(
        r(sid, const [
          RoundEntry(playerId: 2, outcome: Outcome.win, mul: 2, bet: 10000),
          RoundEntry(playerId: 3, outcome: Outcome.lose, bet: 20000),
        ]),
      );
      final r2 = await sessions.addRound(
        r(sid, const [
          RoundEntry(playerId: 1, outcome: Outcome.lose, bet: 10000),
          RoundEntry(playerId: 3, outcome: Outcome.win, mul: 3, bet: 10000),
        ], dealer: 2),
      );
      final r3 = await sessions.addRound(
        r(sid, const [
          RoundEntry(playerId: 2, outcome: Outcome.lose, bet: 5000),
          RoundEntry(playerId: 3, outcome: Outcome.draw, bet: 5000),
        ]),
      );
      expect([r1.idx, r2.idx, r3.idx], [1, 2, 3]);

      var s = (await sessions.getSession(sid))!;
      expect(s.roundCount, 3);
      expect(s.totals, {
        1: 0 - 10000 + 5000,
        2: 20000 - 20000 - 5000,
        3: -20000 + 30000,
      });
      expect(s.totals.values.reduce((a, b) => a + b), 0);

      // Sửa ván 2: Chi thua thay vì thắng x3.
      await sessions.updateRound(
        r2.copyWith(
          entries: const [
            RoundEntry(playerId: 1, outcome: Outcome.lose, bet: 10000),
            RoundEntry(playerId: 3, outcome: Outcome.lose, bet: 10000),
          ],
        ),
      );
      s = (await sessions.getSession(sid))!;
      expect(s.totals, {1: -5000, 2: 20000 + 20000 - 5000, 3: -30000});

      // Xóa ván 1 rồi hoàn tác.
      await sessions.deleteRound(r1);
      s = (await sessions.getSession(sid))!;
      expect(s.roundCount, 2);
      expect(s.totals, {1: -5000, 2: 15000, 3: -10000});
      await sessions.restoreRound(r1);
      final rounds = await sessions.getRounds(sid);
      expect(rounds.map((e) => e.idx), [1, 2, 3]);
      s = (await sessions.getSession(sid))!;
      expect(s.totals, {1: -5000, 2: 35000, 3: -30000});

      // Ván mới sau khi xóa vẫn có idx tăng dần.
      await sessions.deleteRound(rounds.last);
      final r4 = await sessions.addRound(
        r(sid, const [
          RoundEntry(playerId: 2, outcome: Outcome.draw),
          RoundEntry(playerId: 3, outcome: Outcome.draw),
        ]),
      );
      expect(r4.idx, 3);
    },
  );

  test('session keeps its own rule copy when the preset changes', () async {
    final presets = await settings.listRules();
    expect(presets.single.builtin, isTrue);
    final custom = presets.single.copyWith(
      clearId: true,
      name: 'Nhà',
      xiDachMul: 3,
    );
    final cid = await settings.saveRule(custom);
    final sid = await newSession(rules: custom.copyWith(id: cid));
    await settings.saveRule(custom.copyWith(id: cid, xiDachMul: 5));
    final s = (await sessions.getSession(sid))!;
    expect(s.rules.xiDachMul, 3);
    expect((await settings.listRules()).last.xiDachMul, 5);
  });

  test('delete session + restore (undo)', () async {
    final sid = await newSession();
    await sessions.addRound(
      r(sid, const [RoundEntry(playerId: 2, outcome: Outcome.win, bet: 1000)]),
    );
    final s = (await sessions.getSession(sid))!;
    final rounds = await sessions.getRounds(sid);
    await sessions.deleteSession(sid);
    expect(await sessions.getRounds(sid), isEmpty, reason: 'cascade');
    await sessions.restoreSession(s, rounds);
    expect((await sessions.getSession(sid))!.totals, s.totals);
    expect(await sessions.getRounds(sid), hasLength(1));
  });

  test('clearing game data and settings data are independent', () async {
    await newSession();
    await settings.saveGroup(
      const PlayerGroup(
        name: 'Bạn thân',
        members: [Member('An', 0), Member('Bình', 1)],
      ),
    );
    await settings.saveRule(const RuleSet(name: 'Tết', xiBangMul: 4));
    await settings.savePrefs(const AppPrefs(keepAwake: false));

    await sessions.deleteAllSessions();
    expect(await sessions.countSessions(), 0);
    expect(await settings.countSettings(), (1, 1));

    await newSession();
    await settings.clearSettings();
    expect(await settings.countSettings(), (0, 0));
    expect((await settings.listRules()).single.builtin, isTrue);
    expect(settings.loadPrefs().keepAwake, isTrue);
    expect(await sessions.countSessions(), 1);
  });

  test('prefs round-trip including last setup', () async {
    await settings.savePrefs(
      const AppPrefs(
        betChips: [1000, 2000],
        defaultMode: ScoringMode.fixedMoney,
        lastSetup: LastSetup(
          members: [Member('An', 3)],
          dealerIdx: 0,
          ruleId: 1,
          mode: ScoringMode.fixedMoney,
          bet: 5000,
        ),
      ),
    );
    final p = settings.loadPrefs();
    expect(p.betChips, [1000, 2000]);
    expect(p.defaultMode, ScoringMode.fixedMoney);
    expect(p.lastSetup!.members.single.colorIdx, 3);
    expect(p.lastSetup!.bet, 5000);
  });
}
