import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/player_palette.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round.dart';
import '../../domain/models/session.dart';
import '../../state/providers.dart';

/// Thứ tự hiển thị người chơi: theo chỗ ngồi hoặc theo điểm.
List<Player> orderedPlayers(GameSession s, {required bool byScore}) {
  final list = [...s.players];
  if (byScore) {
    list.sort((a, b) => s.totalOf(b.id).compareTo(s.totalOf(a.id)));
  }
  return list;
}

/// Dải tổng điểm — luôn hiện ở đầu màn hình bảng điểm (dọc).
class TotalsPanel extends StatelessWidget {
  const TotalsPanel({
    super.key,
    required this.session,
    required this.players,
    required this.nextDealerId,
  });

  final GameSession session;
  final List<Player> players;
  final int nextDealerId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainer,
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth < 340 ? 2 : (c.maxWidth < 520 ? 3 : 4);
          final w = (c.maxWidth - 16 - (cols - 1) * 8) / cols;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.42,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in players)
                    SizedBox(
                      width: w,
                      child: _TotalTile(
                        player: p,
                        total: session.totalOf(p.id),
                        money: session.isMoney,
                        isDealer: p.id == nextDealerId,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  const _TotalTile({
    required this.player,
    required this.total,
    required this.money,
    required this.isDealer,
  });

  final Player player;
  final int total;
  final bool money;
  final bool isDealer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final color = PlayerPalette.of(player.colorIdx);
    return Semantics(
      label:
          '${player.name}${isDealer ? ', nhà cái' : ''}: '
          '${formatDelta(total, money: money)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: t.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Opacity(
          opacity: player.active ? 1 : 0.5,
          child: Row(
            children: [
              PlayerAvatar(
                name: player.name,
                colorIdx: player.colorIdx,
                size: 28,
                isDealer: isDealer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.labelMedium,
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: DeltaText(
                        total,
                        money: money,
                        style: t.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách ván (mới nhất ở trên) — dùng ở màn dọc.
class RoundHistoryList extends StatelessWidget {
  const RoundHistoryList({
    super.key,
    required this.data,
    required this.players,
    required this.onTap,
    required this.onDelete,
    this.bottomPadding = 96,
  });

  final SessionData data;
  final List<Player> players;
  final ValueChanged<GameRound> onTap;
  final ValueChanged<GameRound> onDelete;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final rounds = data.rounds.reversed.toList();
    if (rounds.isEmpty) {
      return const EmptyState(
        icon: FontAwesomeIcons.clockRotateLeft,
        title: 'Chưa có ván nào',
        message: 'Bấm "Ván mới" để ghi kết quả ván đầu tiên.',
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomPadding),
      itemCount: rounds.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final r = rounds[i];
        return Dismissible(
          key: ValueKey('round-${r.id}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: FaIcon(
              FontAwesomeIcons.trashCan,
              color: scheme.onErrorContainer,
            ),
          ),
          onDismissed: (_) => onDelete(r),
          child: _RoundCard(
            number: rounds.length - i,
            round: r,
            session: data.session,
            players: players,
            onTap: () => onTap(r),
          ),
        );
      },
    );
  }
}

class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.number,
    required this.round,
    required this.session,
    required this.players,
    required this.onTap,
  });

  final int number;
  final GameRound round;
  final GameSession session;
  final List<Player> players;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dealer = session.playerById(round.dealerId);
    final deltas = round.deltas;
    final tags = {for (final e in round.entries) e.playerId: e};
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Ván $number', style: t.textTheme.titleSmall),
                  const SizedBox(width: 8),
                  FaIcon(
                    FontAwesomeIcons.crown,
                    size: 11,
                    color: t.colorScheme.dealer,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      dealer?.name ?? '?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall,
                    ),
                  ),
                  Text(
                    formatTime(round.createdAt),
                    style: t.textTheme.bodySmall,
                  ),
                  const SizedBox(width: 6),
                  FaIcon(
                    FontAwesomeIcons.penToSquare,
                    size: 12,
                    color: t.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  for (final p in players)
                    if (deltas.containsKey(p.id))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerAvatar(
                            name: p.name,
                            colorIdx: p.colorIdx,
                            size: 20,
                            isDealer: p.id == round.dealerId,
                          ),
                          const SizedBox(width: 4),
                          DeltaText(
                            deltas[p.id]!,
                            money: session.isMoney,
                            compact: true,
                            style: t.textTheme.bodyMedium,
                          ),
                          if (tags[p.id]?.tag != null) ...[
                            const SizedBox(width: 3),
                            Text(
                              tags[p.id]!.tag!.label,
                              style: t.textTheme.labelSmall?.copyWith(
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ] else if ((tags[p.id]?.mul ?? 1) > 1) ...[
                            const SizedBox(width: 3),
                            Text(
                              'x${tags[p.id]!.mul}',
                              style: t.textTheme.labelSmall?.copyWith(
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bảng lưới (ngang / tablet): cột = người chơi, hàng = ván, tổng dính trên cùng.
class ScoreTable extends StatelessWidget {
  const ScoreTable({
    super.key,
    required this.data,
    required this.players,
    required this.nextDealerId,
    required this.onTap,
    required this.onLongPress,
    this.selectedRoundId,
  });

  final SessionData data;
  final List<Player> players;
  final int nextDealerId;
  final ValueChanged<GameRound> onTap;
  final ValueChanged<GameRound> onLongPress;
  final int? selectedRoundId;

  static const _firstCol = 64.0;
  static const _minCol = 88.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final s = data.session;
    final rounds = data.rounds.reversed.toList();
    return LayoutBuilder(
      builder: (context, c) {
        final colW = ((c.maxWidth - _firstCol) / players.length)
            .clamp(_minCol, 180.0)
            .toDouble();
        final tableW = _firstCol + colW * players.length;

        Widget cell(Widget child, {Color? bg, double? h}) => Container(
          width: colW,
          height: h ?? 44,
          alignment: Alignment.center,
          color: bg,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        );

        final header = Container(
          color: t.colorScheme.surfaceContainer,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: _firstCol),
                  for (final p in players)
                    cell(
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PlayerAvatar(
                            name: p.name,
                            colorIdx: p.colorIdx,
                            size: 26,
                            isDealer: p.id == nextDealerId,
                            dimmed: !p.active,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.labelMedium,
                          ),
                        ],
                      ),
                      h: 64,
                    ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: _firstCol,
                    child: Text(
                      'Tổng',
                      textAlign: TextAlign.center,
                      style: t.textTheme.labelLarge,
                    ),
                  ),
                  for (final p in players)
                    cell(
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: DeltaText(
                          s.totalOf(p.id),
                          money: s.isMoney,
                          style: t.textTheme.titleMedium,
                        ),
                      ),
                      h: 40,
                    ),
                ],
              ),
              Divider(height: 1, color: t.colorScheme.outlineVariant),
            ],
          ),
        );

        final body = rounds.isEmpty
            ? const EmptyState(
                icon: FontAwesomeIcons.tableCells,
                title: 'Chưa có ván nào',
              )
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: rounds.length,
                itemBuilder: (context, i) {
                  final r = rounds[i];
                  final deltas = r.deltas;
                  final selected = r.id == selectedRoundId;
                  return Material(
                    color: selected
                        ? t.colorScheme.secondaryContainer
                        : (i.isOdd
                              ? t.colorScheme.surfaceContainerLowest
                              : Colors.transparent),
                    child: InkWell(
                      onTap: () => onTap(r),
                      onLongPress: () => onLongPress(r),
                      child: Row(
                        children: [
                          SizedBox(
                            width: _firstCol,
                            child: Column(
                              children: [
                                Text(
                                  '${rounds.length - i}',
                                  style: t.textTheme.labelLarge,
                                ),
                                Text(
                                  formatTime(r.createdAt),
                                  style: t.textTheme.labelSmall?.copyWith(
                                    color: t.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final p in players)
                            cell(
                              deltas.containsKey(p.id)
                                  ? Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        if (p.id == r.dealerId) ...[
                                          FaIcon(
                                            FontAwesomeIcons.crown,
                                            size: 10,
                                            color: t.colorScheme.dealer,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Flexible(
                                          child: DeltaText(
                                            deltas[p.id]!,
                                            money: s.isMoney,
                                            compact: true,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '—',
                                      style: TextStyle(
                                        color: t.colorScheme.outlineVariant,
                                      ),
                                    ),
                              bg: p.id == r.dealerId
                                  ? t.colorScheme.dealerTint
                                  : null,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );

        final table = SizedBox(
          width: tableW,
          height: c.maxHeight,
          child: Column(
            children: [
              header,
              Expanded(child: body),
            ],
          ),
        );
        return tableW > c.maxWidth
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: table,
              )
            : Align(alignment: Alignment.topLeft, child: table);
      },
    );
  }
}
