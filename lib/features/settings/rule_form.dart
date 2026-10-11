import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/rule_set.dart';

/// Form chỉnh các hệ số luật. Dùng chung cho cài đặt và màn tạo lần chơi.
class RuleForm extends StatelessWidget {
  const RuleForm({super.key, required this.rules, required this.onChanged});

  final RuleSet rules;
  final ValueChanged<RuleSet> onChanged;

  Widget _mul(
    String title,
    String subtitle,
    int value,
    RuleSet Function(int v) apply,
  ) => ListTile(
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: NumberStepper(
      value: value,
      max: RuleSet.maxMul,
      onChanged: (v) => onChanged(apply(v)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = rules;
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Con thắng'),
        _mul('Xì bàng', '2 lá A', r.xiBangMul, (v) => r.copyWith(xiBangMul: v)),
        _mul(
          'Xì dách',
          'A + 10/J/Q/K',
          r.xiDachMul,
          (v) => r.copyWith(xiDachMul: v),
        ),
        _mul(
          'Ngũ linh',
          '5 lá, tổng ≤ 21',
          r.nguLinhMul,
          (v) => r.copyWith(nguLinhMul: v),
        ),
        const SectionHeader('Con thua'),
        _mul('Quắc', 'Tổng > 21', r.bustMul, (v) => r.copyWith(bustMul: v)),
        SwitchListTile(
          title: const Text('Quắc nặng'),
          subtitle: const Text('Quắc từ ngưỡng trở lên thì phạt nặng hơn'),
          value: r.heavyBustEnabled,
          onChanged: (v) => onChanged(r.copyWith(heavyBustEnabled: v)),
        ),
        if (r.heavyBustEnabled) ...[
          ListTile(
            title: const Text('Ngưỡng quắc nặng'),
            trailing: NumberStepper(
              value: r.heavyBustThreshold,
              min: 23,
              max: 35,
              prefix: '≥',
              onChanged: (v) => onChanged(r.copyWith(heavyBustThreshold: v)),
            ),
          ),
          _mul(
            'Hệ số quắc nặng',
            'Áp dụng khi chọn "Quắc nặng"',
            r.heavyBustMul,
            (v) => r.copyWith(heavyBustMul: v),
          ),
        ],
        _mul(
          'Con non',
          'Chưa đủ 16 điểm khi lật bài',
          r.playerNonMul,
          (v) => r.copyWith(playerNonMul: v),
        ),
        const SectionHeader('Nhà cái'),
        _mul(
          'Cái non',
          'Cái chưa đủ tuổi, đền cả bàn',
          r.dealerNonMul,
          (v) => r.copyWith(dealerNonMul: v),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Cái và con cùng quắc', style: t.textTheme.bodyLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<BothBust>(
            showSelectedIcon: false,
            segments: [
              for (final b in BothBust.values)
                ButtonSegment(value: b, label: Text(b.label)),
            ],
            selected: {r.bothBust},
            onSelectionChanged: (s) => onChanged(r.copyWith(bothBust: s.first)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('Cái và con cùng ngũ linh', style: t.textTheme.bodyLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<NguLinhVsNguLinh>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: NguLinhVsNguLinh.draw, label: Text('Hòa')),
              ButtonSegment(
                value: NguLinhVsNguLinh.lowerWins,
                label: Text('Ít điểm thắng'),
              ),
            ],
            selected: {r.nguLinhVsNguLinh},
            onSelectionChanged: (s) =>
                onChanged(r.copyWith(nguLinhVsNguLinh: s.first)),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Ăn xì dách / xì bàng được làm cái'),
          subtitle: const Text('Gợi ý người vừa ăn làm cái ván sau'),
          value: r.winnerTakesDealer,
          onChanged: (v) => onChanged(r.copyWith(winnerTakesDealer: v)),
        ),
      ],
    );
  }
}
