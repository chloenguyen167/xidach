/// Người chơi trong một lần chơi. Thứ tự trong danh sách = thứ tự chỗ ngồi.
class Player {
  const Player({
    required this.id,
    required this.name,
    required this.colorIdx,
    this.active = true,
  });

  final int id;
  final String name;
  final int colorIdx;

  /// `false` = đang nghỉ, không tham gia ván mới.
  final bool active;

  Player copyWith({String? name, int? colorIdx, bool? active}) => Player(
    id: id,
    name: name ?? this.name,
    colorIdx: colorIdx ?? this.colorIdx,
    active: active ?? this.active,
  );

  Map<String, Object?> toJson() => {
    'i': id,
    'n': name,
    'c': colorIdx,
    if (!active) 'a': 0,
  };

  factory Player.fromJson(Map<String, Object?> j) => Player(
    id: (j['i'] as num).toInt(),
    name: j['n'] as String,
    colorIdx: (j['c'] as num).toInt(),
    active: (j['a'] as num?) != 0,
  );
}

/// Thành viên trong một nhóm người chơi lưu sẵn (chưa có id lần chơi).
class Member {
  const Member(this.name, this.colorIdx);
  final String name;
  final int colorIdx;

  Member copyWith({String? name, int? colorIdx}) =>
      Member(name ?? this.name, colorIdx ?? this.colorIdx);

  Map<String, Object?> toJson() => {'n': name, 'c': colorIdx};

  factory Member.fromJson(Map<String, Object?> j) =>
      Member(j['n'] as String, (j['c'] as num).toInt());
}

/// Danh sách người chơi lưu trong cài đặt.
class PlayerGroup {
  const PlayerGroup({this.id, required this.name, required this.members});

  final int? id;
  final String name;
  final List<Member> members;

  PlayerGroup copyWith({String? name, List<Member>? members}) => PlayerGroup(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
  );
}
