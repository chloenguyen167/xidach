import '../models/enums.dart';
import '../models/round.dart';
import '../models/rule_set.dart';
import '../models/session.dart';

/// Trạng thái đang nhập của một con (outcome có thể chưa chọn).
class EntryDraft {
  const EntryDraft({this.outcome, this.mul = 1, this.tag, this.bet = 1});

  final Outcome? outcome;
  final int mul;
  final HandTag? tag;
  final int bet;

  bool get isSet => outcome != null;

  int get delta => (outcome?.sign ?? 0) * mul * bet;

  EntryDraft copyWith({
    Outcome? outcome,
    bool clearOutcome = false,
    int? mul,
    HandTag? tag,
    bool clearTag = false,
    int? bet,
  }) => EntryDraft(
    outcome: clearOutcome ? null : (outcome ?? this.outcome),
    mul: mul ?? this.mul,
    tag: clearTag ? null : (tag ?? this.tag),
    bet: bet ?? this.bet,
  );

  RoundEntry toEntry(int playerId) => RoundEntry(
    playerId: playerId,
    outcome: outcome ?? Outcome.draw,
    mul: outcome == Outcome.draw ? 1 : mul,
    tag: tag,
    bet: bet,
  );

  factory EntryDraft.fromEntry(RoundEntry e) =>
      EntryDraft(outcome: e.outcome, mul: e.mul, tag: e.tag, bet: e.bet);
}

/// Các hàm tính điểm thuần (không phụ thuộc UI/DB) để dễ unit test.
abstract final class ScoringEngine {
  /// Gắn/bỏ loại bài cho một con. Bấm lại cùng loại = bỏ chọn.
  static EntryDraft applyTag(EntryDraft d, HandTag tag, RuleSet rules) {
    if (d.tag == tag) {
      return d.copyWith(clearTag: true, clearOutcome: true, mul: 1);
    }
    return d.copyWith(
      tag: tag,
      outcome: rules.outcomeFor(tag),
      mul: rules.mulFor(tag),
    );
  }

  /// Chọn thắng/hòa/thua thủ công. Đổi chiều thắng↔thua thì bỏ tag không còn hợp.
  static EntryDraft applyOutcome(EntryDraft d, Outcome? outcome) {
    final tag = d.tag;
    final tagConflicts =
        tag != null &&
        outcome != null &&
        outcome != Outcome.draw &&
        outcome != (tag.specialRank > 0 ? Outcome.win : Outcome.lose);
    if (outcome == null) return d.copyWith(clearOutcome: true);
    return d.copyWith(
      outcome: outcome,
      clearTag: tagConflicts,
      mul: tagConflicts ? 1 : null,
    );
  }

  /// Áp kết quả của nhà cái cho cả bàn. Người dùng vẫn sửa riêng được sau đó.
  static Map<int, EntryDraft> applyDealerAction(
    Map<int, EntryDraft> drafts,
    DealerAction action,
    RuleSet r,
  ) {
    EntryDraft lose(EntryDraft d, int mul) =>
        d.copyWith(outcome: Outcome.lose, mul: mul, clearTag: true);
    EntryDraft win(EntryDraft d, int mul) =>
        d.copyWith(outcome: Outcome.win, mul: mul);
    EntryDraft draw(EntryDraft d) => d.copyWith(outcome: Outcome.draw, mul: 1);
    EntryDraft winSpecial(EntryDraft d, [int minMul = 1]) {
      final m = r.mulFor(d.tag!);
      return win(d, m > minMul ? m : minMul);
    }

    EntryDraft map(EntryDraft d) {
      final tag = d.tag;
      final rank = tag?.specialRank ?? 0;
      switch (action) {
        case DealerAction.xiBang:
          return rank == 3 ? draw(d) : lose(d, r.xiBangMul);
        case DealerAction.xiDach:
          if (rank == 3) return winSpecial(d);
          if (rank == 2) return draw(d);
          return lose(d, r.xiDachMul);
        case DealerAction.nguLinh:
          if (rank >= 2) return winSpecial(d);
          if (rank == 1) {
            return r.nguLinhVsNguLinh == NguLinhVsNguLinh.draw
                ? draw(d)
                : d.copyWith(clearOutcome: true, mul: 1);
          }
          return lose(d, r.nguLinhMul);
        case DealerAction.bust:
          if (rank > 0) return winSpecial(d);
          if (tag != null && tag.isBust) {
            return r.bothBust == BothBust.draw
                ? draw(d)
                : d.copyWith(outcome: Outcome.lose, mul: r.mulFor(tag));
          }
          if (tag == HandTag.non) {
            return d.copyWith(outcome: Outcome.lose, mul: r.playerNonMul);
          }
          return win(d, 1);
        case DealerAction.non:
          if (rank > 0) return winSpecial(d, r.dealerNonMul);
          if (tag == HandTag.non) return draw(d);
          if (tag != null && tag.isBust) {
            return d.copyWith(outcome: Outcome.lose, mul: r.mulFor(tag));
          }
          return win(d, r.dealerNonMul);
        case DealerAction.winAll:
          if (tag != null && (tag.isBust || tag == HandTag.non)) {
            return d.copyWith(outcome: Outcome.lose, mul: r.mulFor(tag));
          }
          return lose(d, 1);
        case DealerAction.loseAll:
          if (rank > 0) return winSpecial(d);
          return win(d.copyWith(clearTag: true), 1);
      }
    }

    return {for (final e in drafts.entries) e.key: map(e.value)};
  }

  /// Tổng của từng người qua các ván.
  static Map<int, int> computeTotals(Iterable<GameRound> rounds) {
    final totals = <int, int>{};
    for (final r in rounds) {
      r.deltas.forEach((id, d) => totals[id] = (totals[id] ?? 0) + d);
    }
    return totals;
  }

  /// Nhà cái mặc định cho ván mới: giữ người làm cái ván trước.
  /// Nếu bật luật "ăn xì dách được làm cái" thì ưu tiên người vừa ăn.
  static DealerSuggestion suggestDealer(GameSession s, List<GameRound> rounds) {
    final active = s.activePlayers;
    bool isActive(int id) => active.any((p) => p.id == id);
    int fallback() => active.isNotEmpty ? active.first.id : s.dealerId;

    if (rounds.isEmpty) {
      return DealerSuggestion(isActive(s.dealerId) ? s.dealerId : fallback());
    }
    final last = rounds.reduce((a, b) => a.idx >= b.idx ? a : b);
    if (s.rules.winnerTakesDealer) {
      RoundEntry? best;
      for (final p in s.players) {
        for (final e in last.entries) {
          if (e.playerId != p.id || e.outcome != Outcome.win) continue;
          final rank = e.tag?.specialRank ?? 0;
          if (rank < 2 || !isActive(p.id)) continue;
          if (best == null || rank > best.tag!.specialRank) best = e;
        }
      }
      if (best != null) {
        return DealerSuggestion(best.playerId, byWinner: best.tag);
      }
    }
    return DealerSuggestion(
      isActive(last.dealerId) ? last.dealerId : fallback(),
    );
  }
}

class DealerSuggestion {
  const DealerSuggestion(this.playerId, {this.byWinner});
  final int playerId;

  /// Có giá trị nếu được gợi ý vì vừa ăn xì dách / xì bàng.
  final HandTag? byWinner;
}
