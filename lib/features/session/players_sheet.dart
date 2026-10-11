import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/theme/player_palette.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/player.dart';
import '../../domain/models/session.dart';
import '../../state/providers.dart';

Future<void> showPlayersSheet(BuildContext context, int sessionId) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PlayersSheet(sessionId: sessionId),
    );

/// Thêm người, cho nghỉ, đổi tên, đổi màu giữa lần chơi.
class _PlayersSheet extends ConsumerWidget {
  const _PlayersSheet({required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sessionProvider(sessionId)).value;
    if (data == null) return const SizedBox(height: 200);
    final s = data.session;
    final ctrl = ref.read(sessionProvider(sessionId).notifier);
    final activeCount = s.activePlayers.length;
    final t = Theme.of(context);

    Future<void> save(List<Player> players) =>
        ctrl.updateSession(s.copyWith(players: players));

    List<Player> replace(Player p) => [
      for (final x in s.players) x.id == p.id ? p : x,
    ];

    Future<void> add() async {
      final name = await textInputDialog(
        context,
        title: 'Thêm người chơi',
        hint: 'Tên',
        confirm: 'Thêm',
        maxLength: 20,
      );
      if (name == null) return;
      if (s.players.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"$name" đã có trong lần chơi')),
          );
        }
        return;
      }
      await save([
        ...s.players,
        Player(
          id: s.nextPlayerId,
          name: name,
          colorIdx: PlayerPalette.nextFree(s.players.map((p) => p.colorIdx)),
        ),
      ]);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, sc) => ListView(
        controller: sc,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Người chơi ($activeCount/${GameSession.maxPlayers} đang chơi)',
                    style: t.textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: activeCount >= GameSession.maxPlayers ? null : add,
                  icon: const FaIcon(FontAwesomeIcons.userPlus, size: 14),
                  label: const Text('Thêm'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Tắt để cho nghỉ: không xuất hiện ở ván mới, điểm cũ vẫn giữ nguyên.',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final p in s.players)
            SwitchListTile(
              secondary: InkResponse(
                onTap: () async {
                  final c = await pickColorDialog(
                    context,
                    p.colorIdx,
                    used: s.players.map((x) => x.colorIdx).toSet(),
                  );
                  if (c != null) await save(replace(p.copyWith(colorIdx: c)));
                },
                child: PlayerAvatar(
                  name: p.name,
                  colorIdx: p.colorIdx,
                  dimmed: !p.active,
                ),
              ),
              title: InkWell(
                onTap: () async {
                  final n = await textInputDialog(
                    context,
                    title: 'Đổi tên',
                    initial: p.name,
                    maxLength: 20,
                  );
                  if (n != null) await save(replace(p.copyWith(name: n)));
                },
                child: Row(
                  children: [
                    Flexible(
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 6),
                    FaIcon(
                      FontAwesomeIcons.pen,
                      size: 10,
                      color: t.colorScheme.outline,
                    ),
                  ],
                ),
              ),
              subtitle: Text(p.active ? 'Đang chơi' : 'Đang nghỉ'),
              value: p.active,
              onChanged: (v) {
                if (v && activeCount >= GameSession.maxPlayers) return;
                if (!v && activeCount <= GameSession.minPlayers) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cần ít nhất 2 người đang chơi'),
                    ),
                  );
                  return;
                }
                save(replace(p.copyWith(active: v)));
              },
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
