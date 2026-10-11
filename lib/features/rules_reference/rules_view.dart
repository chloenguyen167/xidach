import 'package:flutter/material.dart';

import '../../core/format/money.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/models/session.dart';

/// Bảng hệ số của một bộ luật (chỉ đọc).
class SessionRulesView extends StatelessWidget {
  const SessionRulesView({super.key, required this.rules, this.session});
  final RuleSet rules;
  final GameSession? session;

  @override
  Widget build(BuildContext context) {
    final r = rules;
    final s = session;
    Widget row(String a, String b) => ListTile(
      dense: true,
      title: Text(a),
      trailing: Text(b, style: Theme.of(context).textTheme.titleSmall),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (s != null) ...[
          row('Cách tính', s.mode.label),
          if (s.mode == ScoringMode.fixedMoney)
            row(
              'Mức cược',
              s.fixedBet > 0
                  ? formatAmount(s.fixedBet, money: true)
                  : 'Không (tính điểm)',
            ),
        ],
        row('Xì bàng', 'x${r.xiBangMul}'),
        row('Xì dách', 'x${r.xiDachMul}'),
        row('Ngũ linh', 'x${r.nguLinhMul}'),
        row('Quắc', 'x${r.bustMul}'),
        if (r.heavyBustEnabled)
          row('Quắc ≥ ${r.heavyBustThreshold}', 'x${r.heavyBustMul}'),
        row('Con non', 'x${r.playerNonMul}'),
        row('Cái non (đền cả bàn)', 'x${r.dealerNonMul}'),
        row('Cái và con cùng quắc', r.bothBust.label),
        row(
          'Cùng ngũ linh',
          r.nguLinhVsNguLinh == NguLinhVsNguLinh.draw ? 'Hòa' : 'Ít điểm thắng',
        ),
        row('Ăn xì dách được làm cái', r.winnerTakesDealer ? 'Có' : 'Không'),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Luật xì dách cơ bản để tham khảo.
class RulesReferencePage extends StatelessWidget {
  const RulesReferencePage({super.key});

  static const _sections = <(String, List<String>)>[
    (
      'Chuẩn bị',
      [
        'Bộ bài 52 lá, 2–10 người kể cả nhà cái (mỗi người rút tối đa 5 lá).',
        'Nhà cái chia mỗi người 2 lá, chia vòng theo chiều chỗ ngồi.',
        'Giá trị: 2–10 theo số; J, Q, K = 10; A tính 1, 10 hoặc 11 tùy số lá.',
      ],
    ),
    (
      'Bài đặc biệt (xét ngay khi chia 2 lá)',
      [
        'Xì bàng: 2 lá A — mạnh nhất.',
        'Xì dách: 1 lá A + 1 lá 10/J/Q/K.',
        'Nếu nhà cái có xì bàng/xì dách thì lật ngay, ăn cả bàn trừ ai có bài bằng hoặc mạnh hơn.',
      ],
    ),
    (
      'Rút bài',
      [
        'Con phải đủ 16 điểm ("đủ tuổi") mới được dằn; dưới 16 khi lật là "non" và bị phạt.',
        'Nhà cái thường phải đủ 15 hoặc 16 điểm tùy luật bàn; cái non thì đền cả bàn.',
        'Quá 21 điểm là "quắc" (thua). Một số bàn phạt nặng khi quắc từ 28 trở lên.',
        'Ngũ linh: rút đủ 5 lá mà tổng ≤ 21 — thắng lớn, chỉ thua xì bàng/xì dách.',
      ],
    ),
    (
      'So bài',
      [
        'Thứ tự: xì bàng > xì dách > ngũ linh > bài thường (điểm cao hơn thắng, tối đa 21).',
        'Bằng điểm thì hòa. Nhà cái quắc thì đền những con không quắc.',
        'Cái và con cùng quắc: tùy luật bàn — con vẫn thua hoặc hòa.',
        'Nhà cái có thể "xét" (lật bài) từng con trước khi tự rút thêm.',
      ],
    ),
    (
      'Trong app',
      [
        'Mỗi ván chỉ cần chọn Thắng/Hòa/Thua cho từng con, hoặc chạm loại bài để tự điền hệ số.',
        'Dùng nút nhanh của nhà cái (Cái xì dách, Cái quắc…) để điền cả bàn rồi sửa riêng.',
        'Ván mới tự giữ người làm cái ván trước; đổi bằng 1 chạm.',
        'Sửa hoặc xóa ván cũ thì điểm tổng tự tính lại.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Luật xì dách')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final (title, items) in _sections)
            MaxWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(title),
                  for (final it in items)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8, right: 10),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: t.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(it, style: t.textTheme.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          MaxWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'Luật xì dách khác nhau theo vùng và nhóm chơi. Hãy thống nhất trước khi chơi '
                'và chỉnh hệ số trong Cài đặt › Bộ luật.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
