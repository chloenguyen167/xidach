import 'dart:convert';

import 'enums.dart';

/// Bộ luật tính hệ số. Lần chơi giữ một bản sao để sửa preset không ảnh hưởng.
class RuleSet {
  const RuleSet({
    this.id,
    this.name = 'Mặc định',
    this.builtin = false,
    this.xiBangMul = 3,
    this.xiDachMul = 2,
    this.nguLinhMul = 2,
    this.bustMul = 1,
    this.heavyBustEnabled = false,
    this.heavyBustThreshold = 28,
    this.heavyBustMul = 2,
    this.playerNonMul = 1,
    this.dealerNonMul = 1,
    this.bothBust = BothBust.lose,
    this.nguLinhVsNguLinh = NguLinhVsNguLinh.draw,
    this.winnerTakesDealer = false,
  });

  static const int maxMul = 10;
  static const RuleSet defaults = RuleSet(builtin: true);

  final int? id;
  final String name;
  final bool builtin;
  final int xiBangMul;
  final int xiDachMul;
  final int nguLinhMul;
  final int bustMul;
  final bool heavyBustEnabled;
  final int heavyBustThreshold;
  final int heavyBustMul;
  final int playerNonMul;
  final int dealerNonMul;
  final BothBust bothBust;
  final NguLinhVsNguLinh nguLinhVsNguLinh;
  final bool winnerTakesDealer;

  /// Hệ số mặc định theo loại bài.
  int mulFor(HandTag tag) => switch (tag) {
    HandTag.xiBang => xiBangMul,
    HandTag.xiDach => xiDachMul,
    HandTag.nguLinh => nguLinhMul,
    HandTag.bust => bustMul,
    HandTag.heavyBust => heavyBustMul,
    HandTag.non => playerNonMul,
  };

  /// Kết quả mặc định của con khi gắn loại bài.
  Outcome outcomeFor(HandTag tag) =>
      tag.specialRank > 0 ? Outcome.win : Outcome.lose;

  List<HandTag> get availableTags => [
    HandTag.xiBang,
    HandTag.xiDach,
    HandTag.nguLinh,
    HandTag.bust,
    if (heavyBustEnabled) HandTag.heavyBust,
    HandTag.non,
  ];

  RuleSet copyWith({
    int? id,
    bool clearId = false,
    String? name,
    bool? builtin,
    int? xiBangMul,
    int? xiDachMul,
    int? nguLinhMul,
    int? bustMul,
    bool? heavyBustEnabled,
    int? heavyBustThreshold,
    int? heavyBustMul,
    int? playerNonMul,
    int? dealerNonMul,
    BothBust? bothBust,
    NguLinhVsNguLinh? nguLinhVsNguLinh,
    bool? winnerTakesDealer,
  }) => RuleSet(
    id: clearId ? null : (id ?? this.id),
    name: name ?? this.name,
    builtin: builtin ?? this.builtin,
    xiBangMul: xiBangMul ?? this.xiBangMul,
    xiDachMul: xiDachMul ?? this.xiDachMul,
    nguLinhMul: nguLinhMul ?? this.nguLinhMul,
    bustMul: bustMul ?? this.bustMul,
    heavyBustEnabled: heavyBustEnabled ?? this.heavyBustEnabled,
    heavyBustThreshold: heavyBustThreshold ?? this.heavyBustThreshold,
    heavyBustMul: heavyBustMul ?? this.heavyBustMul,
    playerNonMul: playerNonMul ?? this.playerNonMul,
    dealerNonMul: dealerNonMul ?? this.dealerNonMul,
    bothBust: bothBust ?? this.bothBust,
    nguLinhVsNguLinh: nguLinhVsNguLinh ?? this.nguLinhVsNguLinh,
    winnerTakesDealer: winnerTakesDealer ?? this.winnerTakesDealer,
  );

  /// Chỉ gồm các tham số luật (không id/tên) — dùng để lưu vào session.
  Map<String, Object?> toJson() => {
    'n': name,
    'xb': xiBangMul,
    'xd': xiDachMul,
    'nl': nguLinhMul,
    'q': bustMul,
    'qnOn': heavyBustEnabled ? 1 : 0,
    'qnAt': heavyBustThreshold,
    'qn': heavyBustMul,
    'pn': playerNonMul,
    'dn': dealerNonMul,
    'bb': bothBust.name,
    'nn': nguLinhVsNguLinh.name,
    'wd': winnerTakesDealer ? 1 : 0,
  };

  factory RuleSet.fromJson(
    Map<String, Object?> j, {
    int? id,
    bool builtin = false,
  }) {
    int i(String k, int d) => (j[k] as num?)?.toInt() ?? d;
    const d = RuleSet();
    return RuleSet(
      id: id,
      builtin: builtin,
      name: (j['n'] as String?) ?? d.name,
      xiBangMul: i('xb', d.xiBangMul),
      xiDachMul: i('xd', d.xiDachMul),
      nguLinhMul: i('nl', d.nguLinhMul),
      bustMul: i('q', d.bustMul),
      heavyBustEnabled: i('qnOn', 0) == 1,
      heavyBustThreshold: i('qnAt', d.heavyBustThreshold),
      heavyBustMul: i('qn', d.heavyBustMul),
      playerNonMul: i('pn', d.playerNonMul),
      dealerNonMul: i('dn', d.dealerNonMul),
      bothBust: BothBust.fromName(j['bb'] as String?),
      nguLinhVsNguLinh: NguLinhVsNguLinh.fromName(j['nn'] as String?),
      winnerTakesDealer: i('wd', 0) == 1,
    );
  }

  String encode() => jsonEncode(toJson());

  static RuleSet decode(String s, {int? id, bool builtin = false}) =>
      RuleSet.fromJson(
        jsonDecode(s) as Map<String, Object?>,
        id: id,
        builtin: builtin,
      );

  /// Mô tả ngắn để hiển thị trong danh sách.
  String get summary {
    final parts = [
      'Xì bàng x$xiBangMul',
      'Xì dách x$xiDachMul',
      'Ngũ linh x$nguLinhMul',
      'Quắc x$bustMul',
      if (heavyBustEnabled) 'Quắc ≥$heavyBustThreshold x$heavyBustMul',
    ];
    return parts.join(' · ');
  }
}
