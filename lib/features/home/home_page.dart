import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app.dart';
import '../../core/format/money.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/session.dart';
import '../../state/providers.dart';
import '../donate/donate_page.dart';
import '../new_session/new_session_page.dart';
import '../session/session_page.dart';
import '../settings/settings_page.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static Future<void> openSession(BuildContext context, int id) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => SessionPage(sessionId: id)));

  static Future<void> openNew(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const NewSessionPage()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text(appName),
        actions: [
          IconButton(
            tooltip: 'Ủng hộ nhà phát triển',
            icon: const FaIcon(FontAwesomeIcons.mugHot, size: 20),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const DonatePage())),
          ),
          IconButton(
            tooltip: 'Cài đặt',
            icon: const FaIcon(FontAwesomeIcons.gear, size: 20),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
          ),
        ],
      ),
      body: sessions.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: FontAwesomeIcons.layerGroup,
                title: 'Chưa có lần chơi nào',
                message:
                    'Tạo lần chơi mới, nhập tên người chơi\nrồi bắt đầu ghi điểm từng ván.',
                action: FilledButton.icon(
                  onPressed: () => openNew(context),
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
                  label: const Text('Lần chơi mới'),
                ),
              )
            : _SessionList(list),
      ),
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList(this.list);
  final List<GameSession> list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = list.first;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        MaxWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContinueCard(latest),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () => HomePage.openNew(context),
                    icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
                    label: const Text('Lần chơi mới'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (list.length > 1) const MaxWidth(child: SectionHeader('Lịch sử')),
        for (final s in list.skip(1))
          MaxWidth(child: _SessionTile(s, key: ValueKey(s.id))),
      ],
    );
  }
}

String _meta(GameSession s) =>
    '${s.roundCount} ván · ${s.players.length} người · ${formatDateTime(s.updatedAt)}';

class _ContinueCard extends StatelessWidget {
  const _ContinueCard(this.s);
  final GameSession s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final top = [...s.players]
      ..sort((a, b) => s.totalOf(b.id).compareTo(s.totalOf(a.id)));
    return Card(
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => HomePage.openSession(context, s.id!),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiếp tục lần gần nhất',
                          style: t.textTheme.labelLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _meta(s),
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: () => HomePage.openSession(context, s.id!),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(16),
                    ),
                    child: Semantics(
                      label: 'Tiếp tục',
                      child: const FaIcon(FontAwesomeIcons.play, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in top.take(4))
                    Container(
                      padding: const EdgeInsets.fromLTRB(3, 3, 10, 3),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PlayerAvatar(
                            name: p.name,
                            colorIdx: p.colorIdx,
                            size: 24,
                          ),
                          const SizedBox(width: 6),
                          DeltaText(
                            s.totalOf(p.id),
                            money: s.isMoney,
                            compact: true,
                          ),
                        ],
                      ),
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

class _SessionTile extends ConsumerWidget {
  const _SessionTile(this.s, {super.key});
  final GameSession s;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sessionRepoProvider);
    final rounds = await repo.getRounds(s.id!);
    await repo.deleteSession(s.id!);
    ref.invalidate(sessionsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Đã xóa "${s.name}"'),
          action: SnackBarAction(
            label: 'Hoàn tác',
            onPressed: () async {
              await repo.restoreSession(s, rounds);
              ref.invalidate(sessionsProvider);
            },
          ),
        ),
      );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final name = await textInputDialog(
      context,
      title: 'Đổi tên lần chơi',
      initial: s.name,
    );
    if (name == null) return;
    await ref
        .read(sessionRepoProvider)
        .updateSessionMeta(s.copyWith(name: name));
    ref.invalidate(sessionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('dismiss-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: scheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: FaIcon(
          FontAwesomeIcons.trashCan,
          color: scheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => _delete(context, ref),
      child: ListTile(
        leading: _AvatarStack(s),
        title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(_meta(s)),
        onTap: () => HomePage.openSession(context, s.id!),
        onLongPress: () => _rename(context, ref),
        trailing: PopupMenuButton<String>(
          tooltip: 'Tùy chọn',
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
          onSelected: (v) =>
              v == 'rename' ? _rename(context, ref) : _delete(context, ref),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
            PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ),
      ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack(this.s);
  final GameSession s;

  @override
  Widget build(BuildContext context) {
    final ps = s.players.take(3).toList();
    return SizedBox(
      width: 48,
      height: 40,
      child: Stack(
        children: [
          for (var i = 0; i < ps.length; i++)
            Positioned(
              left: i * 10.0,
              top: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: PlayerAvatar(
                  name: ps[i].name,
                  colorIdx: ps[i].colorIdx,
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
