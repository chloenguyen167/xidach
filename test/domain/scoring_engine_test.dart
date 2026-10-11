import 'package:flutter_test/flutter_test.dart';
import 'package:xidach/domain/models/enums.dart';
import 'package:xidach/domain/models/player.dart';
import 'package:xidach/domain/models/round.dart';
import 'package:xidach/domain/models/rule_set.dart';
import 'package:xidach/domain/models/session.dart';
import 'package:xidach/domain/scoring/scoring_engine.dart';
import 'package:xidach/domain/scoring/settlement.dart';

GameRound round(int idx, int dealer, List<RoundEntry> entries) => GameRound(
  sessionId: 1,
  idx: idx,
  dealerId: dealer,
  createdAt: DateTime(2026),
  entries: entries,
);

GameSession session({RuleSet rules = const RuleSet(), int dealer = 1}) =>
    GameSession(
      id: 1,
      name: 't',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      mode: ScoringMode.points,
      rules: rules,
      players: const [
        Player(id: 1, name: 'An', colorIdx: 0),
        Player(id: 2, name: 'Bình', colorIdx: 1),
        Player(id: 3, name: 'Chi', colorIdx: 2),
      ],
      dealerId: dealer,
    );

void main() {
  const rules = RuleSet();

  group('RoundEntry / GameRound', () {
    test('delta = sign × mul × bet', () {
      const e = RoundEntry(
        playerId: 1,
        outcome: Outcome.win,
        mul: 2,
        bet: 10000,
      );
      expect(e.delta, 20000);
      const l = RoundEntry(playerId: 1, outcome: Outcome.lose, mul: 3, bet: 5);
      expect(l.delta, -15);
      const d = RoundEntry(playerId: 1, outcome: Outcome.draw, mul: 3, bet: 5);
      expect(d.delta, 0);
    });

    test('zero-sum: dealer delta balances all players', () {
      final r = round(1, 1, const [
        RoundEntry(playerId: 2, outcome: Outcome.win, mul: 2, bet: 10000),
        RoundEntry(playerId: 3, outcome: Outcome.lose, mul: 1, bet: 20000),
      ]);
      expect(r.dealerDelta, 0);
      expect(r.deltas.values.reduce((a, b) => a + b), 0);
      final r2 = round(2, 1, const [
        RoundEntry(playerId: 2, outcome: Outcome.lose, mul: 3),
        RoundEntry(playerId: 3, outcome: Outcome.lose, mul: 2),
      ]);
      expect(r2.deltas, {2: -3, 3: -2, 1: 5});
    });

    test('json round-trip keeps compact keys', () {
      const e = RoundEntry(
        playerId: 4,
        outcome: Outcome.win,
        mul: 2,
        tag: HandTag.xiDach,
        bet: 5000,
      );
      final j = e.toJson();
      expect(j, {'p': 4, 'o': 1, 'm': 2, 't': 'xd', 'b': 5000});
      final back = RoundEntry.fromJson(j);
      expect(back.delta, e.delta);
      expect(back.tag, HandTag.xiDach);
      expect(const RoundEntry(playerId: 1, outcome: Outcome.draw).toJson(), {
        'p': 1,
        'o': 0,
      });
    });
  });

  group('tags', () {
    test('tag fills outcome + multiplier from rules', () {
      final r = rules.copyWith(xiBangMul: 3, xiDachMul: 2, nguLinhMul: 2);
      var d = ScoringEngine.applyTag(const EntryDraft(), HandTag.xiBang, r);
      expect((d.outcome, d.mul), (Outcome.win, 3));
      d = ScoringEngine.applyTag(d, HandTag.bust, r);
      expect((d.outcome, d.mul, d.tag), (Outcome.lose, 1, HandTag.bust));
      d = ScoringEngine.applyTag(d, HandTag.bust, r);
      expect(d.isSet, isFalse, reason: 'tapping same tag clears');
    });

    test('every tag uses the multiplier configured in the preset', () {
      final r = rules.copyWith(
        xiBangMul: 4,
        xiDachMul: 5,
        nguLinhMul: 6,
        bustMul: 7,
        heavyBustMul: 8,
        playerNonMul: 9,
        heavyBustEnabled: true,
      );
      final expected = {
        HandTag.xiBang: 4,
        HandTag.xiDach: 5,
        HandTag.nguLinh: 6,
        HandTag.bust: 7,
        HandTag.heavyBust: 8,
        HandTag.non: 9,
      };
      expected.forEach((tag, mul) {
        final d = ScoringEngine.applyTag(const EntryDraft(), tag, r);
        expect(d.mul, mul, reason: tag.name);
      });
    });

    test('manual outcome flip drops a conflicting tag', () {
      final d = ScoringEngine.applyTag(
        const EntryDraft(),
        HandTag.xiDach,
        rules,
      );
      final lost = ScoringEngine.applyOutcome(d, Outcome.lose);
      expect((lost.tag, lost.mul), (null, 1));
      final drew = ScoringEngine.applyOutcome(d, Outcome.draw);
      expect(drew.tag, HandTag.xiDach);
    });
  });

  group('dealer quick actions', () {
    Map<int, EntryDraft> drafts(Map<int, HandTag?> tags) => {
      for (final e in tags.entries)
        e.key: e.value == null
            ? const EntryDraft()
            : ScoringEngine.applyTag(const EntryDraft(), e.value!, rules),
    };

    test(
      'dealer xì dách: xì dách vs xì dách = hòa, xì bàng thắng, others lose',
      () {
        final out = ScoringEngine.applyDealerAction(
          drafts({
            2: HandTag.xiDach,
            3: null,
            4: HandTag.xiBang,
            5: HandTag.bust,
          }),
          DealerAction.xiDach,
          rules,
        );
        expect(out[2]!.outcome, Outcome.draw);
        expect((out[3]!.outcome, out[3]!.mul), (Outcome.lose, rules.xiDachMul));
        expect((out[4]!.outcome, out[4]!.mul), (Outcome.win, rules.xiBangMul));
        expect(
          (out[5]!.outcome, out[5]!.mul, out[5]!.tag),
          (Outcome.lose, rules.xiDachMul, null),
        );
      },
    );

    test('dealer xì bàng: only xì bàng draws', () {
      final out = ScoringEngine.applyDealerAction(
        drafts({2: HandTag.xiBang, 3: HandTag.xiDach}),
        DealerAction.xiBang,
        rules,
      );
      expect(out[2]!.outcome, Outcome.draw);
      expect((out[3]!.outcome, out[3]!.mul), (Outcome.lose, rules.xiBangMul));
    });

    test('dealer quắc respects bothBust rule', () {
      final d = drafts({2: HandTag.bust, 3: null, 4: HandTag.nguLinh});
      final lose = ScoringEngine.applyDealerAction(d, DealerAction.bust, rules);
      expect(lose[2]!.outcome, Outcome.lose);
      expect((lose[3]!.outcome, lose[3]!.mul), (Outcome.win, 1));
      expect((lose[4]!.outcome, lose[4]!.mul), (Outcome.win, rules.nguLinhMul));

      final drawRules = rules.copyWith(bothBust: BothBust.draw);
      final draw = ScoringEngine.applyDealerAction(
        d,
        DealerAction.bust,
        drawRules,
      );
      expect(draw[2]!.outcome, Outcome.draw);
    });

    test('dealer non pays everyone; player also non = hòa', () {
      final r = rules.copyWith(dealerNonMul: 2);
      final out = ScoringEngine.applyDealerAction(
        drafts({2: HandTag.non, 3: null}),
        DealerAction.non,
        r,
      );
      expect(out[2]!.outcome, Outcome.draw);
      expect((out[3]!.outcome, out[3]!.mul), (Outcome.win, 2));
    });

    test('ngũ linh vs ngũ linh: draw or left for manual choice', () {
      final d = drafts({2: HandTag.nguLinh});
      expect(
        ScoringEngine.applyDealerAction(
          d,
          DealerAction.nguLinh,
          rules,
        )[2]!.outcome,
        Outcome.draw,
      );
      final manual = ScoringEngine.applyDealerAction(
        d,
        DealerAction.nguLinh,
        rules.copyWith(nguLinhVsNguLinh: NguLinhVsNguLinh.lowerWins),
      );
      expect(manual[2]!.isSet, isFalse);
    });

    test('ăn hết / đền hết', () {
      final d = drafts({2: null, 3: HandTag.xiDach});
      final all = ScoringEngine.applyDealerAction(
        d,
        DealerAction.winAll,
        rules,
      );
      expect(all.values.every((e) => e.outcome == Outcome.lose), isTrue);
      final pay = ScoringEngine.applyDealerAction(
        d,
        DealerAction.loseAll,
        rules,
      );
      expect((pay[2]!.outcome, pay[2]!.mul), (Outcome.win, 1));
      expect((pay[3]!.outcome, pay[3]!.mul), (Outcome.win, rules.xiDachMul));
    });
  });

  group('totals & dealer suggestion', () {
    test('totals equal sum of rounds and stay zero-sum after edits', () {
      final r1 = round(1, 1, const [
        RoundEntry(playerId: 2, outcome: Outcome.win, mul: 2),
        RoundEntry(playerId: 3, outcome: Outcome.lose),
      ]);
      final r2 = round(2, 2, const [
        RoundEntry(playerId: 1, outcome: Outcome.lose, mul: 3),
        RoundEntry(playerId: 3, outcome: Outcome.win),
      ]);
      final t = ScoringEngine.computeTotals([r1, r2]);
      expect(t, {1: -1 - 3, 2: 2 + 2, 3: -1 + 1});
      expect(t.values.reduce((a, b) => a + b), 0);
      // "Xóa" ván 1
      expect(ScoringEngine.computeTotals([r2]), {1: -3, 2: 2, 3: 1});
    });

    test('next round keeps previous dealer', () {
      final s = session(dealer: 2);
      expect(ScoringEngine.suggestDealer(s, []).playerId, 2);
      final r = round(1, 3, const [
        RoundEntry(playerId: 1, outcome: Outcome.win),
      ]);
      expect(ScoringEngine.suggestDealer(s, [r]).playerId, 3);
    });

    test('winnerTakesDealer suggests the xì dách winner', () {
      final s = session(rules: rules.copyWith(winnerTakesDealer: true));
      final r = round(1, 1, const [
        RoundEntry(
          playerId: 2,
          outcome: Outcome.win,
          mul: 2,
          tag: HandTag.xiDach,
        ),
        RoundEntry(playerId: 3, outcome: Outcome.lose),
      ]);
      final sug = ScoringEngine.suggestDealer(s, [r]);
      expect((sug.playerId, sug.byWinner), (2, HandTag.xiDach));
    });

    test('inactive dealer falls back to first active player', () {
      final s = session(dealer: 1);
      final s2 = s.copyWith(
        players: [s.players[0].copyWith(active: false), ...s.players.skip(1)],
      );
      expect(ScoringEngine.suggestDealer(s2, []).playerId, 2);
    });
  });

  group('rules', () {
    test('json round-trip', () {
      final r = rules.copyWith(
        name: 'Nhà',
        xiBangMul: 4,
        heavyBustEnabled: true,
        bothBust: BothBust.draw,
      );
      final back = RuleSet.decode(r.encode());
      expect(back.name, 'Nhà');
      expect(back.xiBangMul, 4);
      expect(back.heavyBustEnabled, isTrue);
      expect(back.bothBust, BothBust.draw);
    });
  });

  group('settlement', () {
    test('transfers sum equals total debt and clears balances', () {
      final totals = {1: -50000, 2: 30000, 3: -10000, 4: 30000};
      final tr = settle(totals);
      expect(tr.length, lessThanOrEqualTo(totals.length - 1));
      final bal = Map.of(totals);
      for (final t in tr) {
        bal[t.from] = bal[t.from]! + t.amount;
        bal[t.to] = bal[t.to]! - t.amount;
      }
      expect(bal.values.every((v) => v == 0), isTrue);
      expect(tr.fold(0, (s, t) => s + t.amount), 60000);
    });

    test('nothing to settle', () {
      expect(settle({1: 0, 2: 0}), isEmpty);
    });
  });
}
