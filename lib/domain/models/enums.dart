/// Kết quả của một người chơi (con) so với nhà cái trong một ván.
enum Outcome {
  lose(-1, 'Thua'),
  draw(0, 'Hòa'),
  win(1, 'Thắng');

  const Outcome(this.sign, this.label);
  final int sign;
  final String label;

  static Outcome? fromSign(int? sign) => switch (sign) {
    -1 => Outcome.lose,
    0 => Outcome.draw,
    1 => Outcome.win,
    _ => null,
  };
}

/// Loại bài đặc biệt — bấm 1 lần để tự điền kết quả + hệ số theo bộ luật.
enum HandTag {
  xiBang('xb', 'Xì bàng'),
  xiDach('xd', 'Xì dách'),
  nguLinh('nl', 'Ngũ linh'),
  bust('q', 'Quắc'),
  heavyBust('qn', 'Quắc nặng'),
  non('non', 'Non');

  const HandTag(this.code, this.label);
  final String code;
  final String label;

  bool get isBust => this == bust || this == heavyBust;

  /// Thứ hạng bài đặc biệt: xì bàng > xì dách > ngũ linh.
  int get specialRank => switch (this) {
    xiBang => 3,
    xiDach => 2,
    nguLinh => 1,
    _ => 0,
  };

  static HandTag? fromCode(String? code) {
    if (code == null) return null;
    for (final t in values) {
      if (t.code == code) return t;
    }
    return null;
  }
}

/// Chế độ tính điểm của một lần chơi.
enum ScoringMode {
  points('Điểm', 'Mỗi ván tính theo điểm'),
  fixedMoney('Tiền cố định', 'Mọi người cược bằng nhau'),
  variableMoney('Tiền theo ván', 'Mỗi người mỗi ván một mức');

  const ScoringMode(this.label, this.description);
  final String label;
  final String description;

  static ScoringMode fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => points);
}

/// Khi cả nhà cái và con cùng quắc.
enum BothBust {
  lose('Con vẫn thua'),
  draw('Hòa');

  const BothBust(this.label);
  final String label;

  static BothBust fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => lose);
}

/// Khi nhà cái và con cùng ngũ linh.
enum NguLinhVsNguLinh {
  lowerWins('Ít điểm hơn thắng (tự chọn)'),
  draw('Hòa');

  const NguLinhVsNguLinh(this.label);
  final String label;

  static NguLinhVsNguLinh fromName(String? name) =>
      values.firstWhere((m) => m.name == name, orElse: () => draw);
}

/// Các nút nhanh cho kết quả của nhà cái (áp cho cả bàn).
enum DealerAction {
  xiBang('Cái xì bàng', 'Xì bàng'),
  xiDach('Cái xì dách', 'Xì dách'),
  nguLinh('Cái ngũ linh', 'Ngũ linh'),
  bust('Cái quắc', 'Quắc'),
  non('Cái non', 'Non'),
  winAll('Cái ăn hết', 'Ăn hết'),
  loseAll('Cái đền hết', 'Đền hết');

  const DealerAction(this.label, this.short);
  final String label;

  /// Nhãn ngắn hiển thị trên chip (đã có tiêu đề "Cái:").
  final String short;
}
