import 'enums.dart';
import 'player.dart';
import 'rule_set.dart';

/// Một lần chơi (gồm nhiều ván).
class GameSession {
  const GameSession({
    this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.mode,
    this.fixedBet = 0,
    required this.rules,
    required this.players,
    required this.dealerId,
    this.totals = const {},
    this.roundCount = 0,
  });

  /// Giới hạn theo luật: 52 lá / tối đa 5 lá mỗi người ≈ 10 người (kể cả cái).
  static const int minPlayers = 2;
  static const int maxPlayers = 10;

  final int? id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScoringMode mode;

  /// Mức cược chung ở chế độ tiền cố định (0 = không nhập → tính như điểm).
  final int fixedBet;
  final RuleSet rules;
  final List<Player> players;

  /// Nhà cái ván đầu.
  final int dealerId;

  /// Cache tổng (tính lại mỗi khi thêm/sửa/xóa ván).
  final Map<int, int> totals;
  final int roundCount;

  /// Hiển thị dạng tiền hay điểm.
  bool get isMoney =>
      mode == ScoringMode.variableMoney ||
      (mode == ScoringMode.fixedMoney && fixedBet > 0);

  /// Mức cược mặc định cho mỗi entry (chế độ tiền theo ván sẽ ghi đè).
  int get baseBet =>
      mode == ScoringMode.fixedMoney && fixedBet > 0 ? fixedBet : 1;

  List<Player> get activePlayers => players.where((p) => p.active).toList();

  Player? playerById(int id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  int totalOf(int playerId) => totals[playerId] ?? 0;

  int get nextPlayerId => players.fold(0, (m, p) => p.id > m ? p.id : m) + 1;

  GameSession copyWith({
    int? id,
    String? name,
    DateTime? updatedAt,
    ScoringMode? mode,
    int? fixedBet,
    RuleSet? rules,
    List<Player>? players,
    int? dealerId,
    Map<int, int>? totals,
    int? roundCount,
  }) => GameSession(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    mode: mode ?? this.mode,
    fixedBet: fixedBet ?? this.fixedBet,
    rules: rules ?? this.rules,
    players: players ?? this.players,
    dealerId: dealerId ?? this.dealerId,
    totals: totals ?? this.totals,
    roundCount: roundCount ?? this.roundCount,
  );
}
