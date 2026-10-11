import 'enums.dart';

/// Kết quả của một con trong một ván.
class RoundEntry {
  const RoundEntry({
    required this.playerId,
    required this.outcome,
    this.mul = 1,
    this.tag,
    this.bet = 1,
  });

  final int playerId;
  final Outcome outcome;
  final int mul;
  final HandTag? tag;

  /// Mức cược (VND hoặc 1 điểm).
  final int bet;

  int get delta => outcome.sign * mul * bet;

  Map<String, Object?> toJson() => {
    'p': playerId,
    'o': outcome.sign,
    if (mul != 1) 'm': mul,
    if (tag != null) 't': tag!.code,
    if (bet != 1) 'b': bet,
  };

  factory RoundEntry.fromJson(Map<String, Object?> j) => RoundEntry(
    playerId: (j['p'] as num).toInt(),
    outcome: Outcome.fromSign((j['o'] as num).toInt()) ?? Outcome.draw,
    mul: (j['m'] as num?)?.toInt() ?? 1,
    tag: HandTag.fromCode(j['t'] as String?),
    bet: (j['b'] as num?)?.toInt() ?? 1,
  );
}

/// Một ván chơi.
class GameRound {
  const GameRound({
    this.id,
    required this.sessionId,
    required this.idx,
    required this.dealerId,
    required this.createdAt,
    required this.entries,
  });

  final int? id;
  final int sessionId;

  /// Thứ tự tạo (tăng dần), không đổi khi xóa ván khác.
  final int idx;
  final int dealerId;
  final DateTime createdAt;
  final List<RoundEntry> entries;

  int get dealerDelta => -entries.fold(0, (s, e) => s + e.delta);

  /// Delta của mọi người tham gia (kể cả nhà cái). Tổng luôn = 0.
  Map<int, int> get deltas => {
    for (final e in entries) e.playerId: e.delta,
    dealerId: dealerDelta,
  };

  bool involves(int playerId) =>
      dealerId == playerId || entries.any((e) => e.playerId == playerId);

  GameRound copyWith({
    int? id,
    int? sessionId,
    int? idx,
    int? dealerId,
    List<RoundEntry>? entries,
  }) => GameRound(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    idx: idx ?? this.idx,
    dealerId: dealerId ?? this.dealerId,
    createdAt: createdAt,
    entries: entries ?? this.entries,
  );
}
