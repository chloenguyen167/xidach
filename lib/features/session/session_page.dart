import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/widgets/common.dart';
import '../../domain/models/round.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../state/providers.dart';
import '../rules_reference/rules_view.dart';
import 'players_sheet.dart';
import 'round_editor.dart';
import 'score_views.dart';
import 'summary_page.dart';

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key, required this.sessionId});
  final int sessionId;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

/// Trạng thái pane nhập ván bên phải (chỉ trên màn rộng).
class _Pane {
  const _Pane(this.editing);
  final GameRound? editing;
}

class _SessionPageState extends ConsumerState<SessionPage> {
  bool _byScore = false;
  _Pane? _pane;
  bool _wake = false;

  @override
  void initState() {
    super.initState();
    _wake = ref.read(prefsProvider).keepAwake;
    if (_wake) WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    if (_wake) WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  SessionController get _ctrl =>
      ref.read(sessionProvider(widget.sessionId).notifier);

  void _showResult(EditResult r) {
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final (msg, undo) = switch (r.kind) {
      EditKind.added => (
        'Đã lưu ván ${r.number}',
        () => _ctrl.deleteRound(r.round),
      ),
      EditKind.updated => (
        'Đã cập nhật ván ${r.number}',
        () => _ctrl.updateRound(r.previous!),
      ),
      EditKind.deleted => (
        'Đã xóa ván ${r.number}',
        () => _ctrl.restoreRound(r.round),
      ),
    };
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(label: 'Hoàn tác', onPressed: undo),
      ),
    );
  }

  Future<void> _openEditor(bool twoPane, [GameRound? editing]) async {
    // Snackbar cũ (VD "Đã lưu ván N") không được che nút Lưu của màn nhập ván.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (twoPane) {
      setState(() => _pane = _Pane(editing));
      return;
    }
    final res = await Navigator.of(context).push<EditResult>(
      MaterialPageRoute(
        builder: (_) =>
            RoundEditorPage(sessionId: widget.sessionId, editing: editing),
      ),
    );
    if (res != null && mounted) _showResult(res);
  }

  Future<void> _delete(
    GameRound r,
    SessionData data, {
    bool confirm = false,
  }) async {
    final number = data.numberOf(r);
    if (confirm) {
      final res = await deleteRoundWithConfirm(
        context,
        ref,
        widget.sessionId,
        r,
        number,
      );
      if (res != null && mounted) {
        if (_pane?.editing?.id == r.id) setState(() => _pane = null);
        _showResult(res);
      }
      return;
    }
    await _ctrl.deleteRound(r);
    if (mounted) _showResult(EditResult(EditKind.deleted, r, number));
  }

  Future<void> _rename(SessionData data) async {
    final name = await textInputDialog(
      context,
      title: 'Đổi tên lần chơi',
      initial: data.session.name,
    );
    if (name != null) {
      await _ctrl.updateSession(data.session.copyWith(name: name));
    }
  }

  void _showRules(SessionData data) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, sc) => ListView(
        controller: sc,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Luật đang dùng cho lần chơi này',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          SessionRulesView(rules: data.session.rules, session: data.session),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionProvider(widget.sessionId));
    return async.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: FontAwesomeIcons.triangleExclamation,
          title: 'Không mở được',
          message: '$e',
        ),
      ),
      data: (data) => _build(context, data),
    );
  }

  Widget _build(BuildContext context, SessionData data) {
    final s = data.session;
    final players = orderedPlayers(s, byScore: _byScore);
    final nextDealer = ScoringEngine.suggestDealer(s, data.rounds).playerId;
    final size = MediaQuery.sizeOf(context);
    final useTable = size.width >= 600 || size.width > size.height;
    final twoPane = size.width >= 840 && size.height >= 500;
    if (!twoPane && _pane != null) _pane = null;

    final appBar = AppBar(
      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Tổng kết',
          icon: const FaIcon(FontAwesomeIcons.trophy, size: 18),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SummaryPage(sessionId: widget.sessionId),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Người chơi',
          icon: const FaIcon(FontAwesomeIcons.userGroup, size: 18),
          onPressed: () => showPlayersSheet(context, widget.sessionId),
        ),
        PopupMenuButton<String>(
          tooltip: 'Thêm',
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
          onSelected: (v) => switch (v) {
            'sort' => setState(() => _byScore = !_byScore),
            'rename' => _rename(data),
            'rules' => _showRules(data),
            _ => null,
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'sort',
              child: ListTile(
                leading: FaIcon(
                  _byScore
                      ? FontAwesomeIcons.arrowDownWideShort
                      : FontAwesomeIcons.arrowUpWideShort,
                  size: 16,
                ),
                title: Text(_byScore ? 'Xếp theo chỗ ngồi' : 'Xếp theo điểm'),
              ),
            ),
            const PopupMenuItem(
              value: 'rename',
              child: ListTile(
                leading: FaIcon(FontAwesomeIcons.pen, size: 16),
                title: Text('Đổi tên'),
              ),
            ),
            const PopupMenuItem(
              value: 'rules',
              child: ListTile(
                leading: FaIcon(FontAwesomeIcons.scaleBalanced, size: 16),
                title: Text('Luật đang dùng'),
              ),
            ),
          ],
        ),
      ],
    );

    final Widget main;
    if (useTable) {
      main = ScoreTable(
        data: data,
        players: players,
        nextDealerId: nextDealer,
        selectedRoundId: _pane?.editing?.id,
        onTap: (r) => _openEditor(twoPane, r),
        onLongPress: (r) => _delete(r, data, confirm: true),
      );
    } else {
      main = Column(
        children: [
          TotalsPanel(session: s, players: players, nextDealerId: nextDealer),
          Expanded(
            child: RoundHistoryList(
              data: data,
              players: players,
              onTap: (r) => _openEditor(false, r),
              onDelete: (r) => _delete(r, data),
            ),
          ),
        ],
      );
    }

    final fab = s.activePlayers.length < 2
        ? null
        : FloatingActionButton.extended(
            onPressed: () => _openEditor(twoPane),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
            label: const Text('Ván mới'),
          );

    if (!twoPane) {
      return Scaffold(appBar: appBar, body: main, floatingActionButton: fab);
    }

    final pane = _pane;
    return Scaffold(
      appBar: appBar,
      floatingActionButton: pane == null ? fab : null,
      body: Row(
        children: [
          Expanded(child: main),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 440,
            child: pane == null
                ? const EmptyState(
                    icon: FontAwesomeIcons.handPointer,
                    title: 'Chọn một ván để sửa',
                    message: 'hoặc bấm "Ván mới" để ghi ván tiếp theo.',
                  )
                : Column(
                    children: [
                      ListTile(
                        title: Text(
                          pane.editing == null
                              ? 'Ván ${data.rounds.length + 1}'
                              : 'Sửa ván ${data.numberOf(pane.editing!)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (pane.editing != null)
                              IconButton(
                                tooltip: 'Xóa ván',
                                icon: const FaIcon(
                                  FontAwesomeIcons.trashCan,
                                  size: 16,
                                ),
                                onPressed: () =>
                                    _delete(pane.editing!, data, confirm: true),
                              ),
                            IconButton(
                              tooltip: 'Đóng',
                              icon: const FaIcon(
                                FontAwesomeIcons.xmark,
                                size: 18,
                              ),
                              onPressed: () => setState(() => _pane = null),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: RoundEditor(
                          key: ValueKey(
                            'pane-${pane.editing?.id ?? 'new-${data.rounds.length}'}',
                          ),
                          sessionId: widget.sessionId,
                          data: data,
                          editing: pane.editing,
                          onDone: (r) {
                            setState(() => _pane = null);
                            _showResult(r);
                          },
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
