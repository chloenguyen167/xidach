import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/format/money.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';
import '../../domain/scoring/settlement.dart';
import '../../state/providers.dart';
import 'score_views.dart';

/// Tổng kết: xếp hạng, số ván làm cái, gợi ý chuyển tiền.
class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sessionProvider(sessionId)).value;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = data.session;
    final t = Theme.of(context);
    final ranked = orderedPlayers(s, byScore: true);
    final dealerCount = <int, int>{};
    for (final r in data.rounds) {
      dealerCount[r.dealerId] = (dealerCount[r.dealerId] ?? 0) + 1;
    }
    final transfers = settle(s.totals);
    String name(int id) => s.playerById(id)?.name ?? '?';

    String asText() {
      final b = StringBuffer('${s.name} — ${data.rounds.length} ván\n');
      for (var i = 0; i < ranked.length; i++) {
        final p = ranked[i];
        b.writeln(
          '${i + 1}. ${p.name}: ${formatDelta(s.totalOf(p.id), money: s.isMoney)}',
        );
      }
      if (transfers.isNotEmpty) {
        b.writeln(s.isMoney ? '\nChuyển tiền:' : '\nThanh toán:');
        for (final tr in transfers) {
          b.writeln(
            '${name(tr.from)} → ${name(tr.to)}: '
            '${formatAmount(tr.amount, money: s.isMoney)}',
          );
        }
      }
      return b.toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tổng kết'),
        actions: [
          IconButton(
            tooltip: 'Sao chép',
            icon: const FaIcon(FontAwesomeIcons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: asText()));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã sao chép kết quả')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    '${s.name} · ${data.rounds.length} ván',
                    style: t.textTheme.bodyMedium,
                  ),
                ),
                const SectionHeader('Xếp hạng'),
                for (var i = 0; i < ranked.length; i++)
                  ListTile(
                    leading: SizedBox(
                      width: 72,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 28,
                            child: i < 3 && s.totalOf(ranked[i].id) > 0
                                ? FaIcon(
                                    FontAwesomeIcons.trophy,
                                    size: 16,
                                    color: [
                                      const Color(0xFFFFB300),
                                      const Color(0xFF90A4AE),
                                      const Color(0xFFA1887F),
                                    ][i],
                                  )
                                : Text(
                                    '${i + 1}',
                                    style: t.textTheme.titleMedium,
                                  ),
                          ),
                          PlayerAvatar(
                            name: ranked[i].name,
                            colorIdx: ranked[i].colorIdx,
                          ),
                        ],
                      ),
                    ),
                    title: Text(ranked[i].name),
                    subtitle: Text(
                      'Làm cái ${dealerCount[ranked[i].id] ?? 0} ván',
                    ),
                    trailing: DeltaText(
                      s.totalOf(ranked[i].id),
                      money: s.isMoney,
                      style: t.textTheme.titleMedium,
                    ),
                  ),
                SectionHeader(
                  s.isMoney ? 'Gợi ý chuyển tiền' : 'Gợi ý thanh toán',
                ),
                if (transfers.isEmpty)
                  const ListTile(title: Text('Không ai nợ ai 🎉'))
                else
                  for (final tr in transfers)
                    ListTile(
                      leading: const FaIcon(
                        FontAwesomeIcons.handHoldingDollar,
                        size: 18,
                      ),
                      title: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: name(tr.from),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const TextSpan(text: '  →  '),
                            TextSpan(
                              text: name(tr.to),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      trailing: Text(
                        formatAmount(tr.amount, money: s.isMoney),
                        style: t.textTheme.titleMedium,
                      ),
                    ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Gợi ý ghép người thua nhiều với người thắng nhiều để giảm số lần chuyển.',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
