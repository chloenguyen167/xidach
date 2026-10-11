import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/format/money.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/player.dart';
import '../../domain/models/round.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/models/session.dart';
import '../../domain/scoring/scoring_engine.dart';
import '../../state/providers.dart';

enum EditKind { added, updated, deleted }

/// Kết quả trả về sau khi lưu/xóa ván để màn bảng điểm hiện snackbar + Hoàn tác.
class EditResult {
  const EditResult(this.kind, this.round, this.number, {this.previous});
  final EditKind kind;
  final GameRound round;
  final int number;
  final GameRound? previous;
}

/// Màn full-screen nhập/sửa ván (điện thoại).
class RoundEditorPage extends ConsumerWidget {
  const RoundEditorPage({super.key, required this.sessionId, this.editing});
  final int sessionId;
  final GameRound? editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(sessionProvider(sessionId)).value;
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final number = editing == null
        ? data.rounds.length + 1
        : data.numberOf(editing!);
    return Scaffold(
      appBar: AppBar(
        title: Text(editing == null ? 'Ván $number' : 'Sửa ván $number'),
        actions: [
          if (editing != null)
            IconButton(
              tooltip: 'Xóa ván',
              icon: const FaIcon(FontAwesomeIcons.trashCan, size: 18),
              onPressed: () async {
                final res = await deleteRoundWithConfirm(
                  context,
                  ref,
                  sessionId,
                  editing!,
                  number,
                );
                if (res != null && context.mounted) Navigator.pop(context, res);
              },
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RoundEditor(
          sessionId: sessionId,
          data: data,
          editing: editing,
          onDone: (r) => Navigator.pop(context, r),
        ),
      ),
    );
  }
}

Future<EditResult?> deleteRoundWithConfirm(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
  GameRound round,
  int number,
) async {
  final ok = await confirmDialog(
    context,
    title: 'Xóa ván $number?',
    message: 'Điểm tổng sẽ được tính lại. Có thể hoàn tác ngay sau khi xóa.',
  );
  if (!ok) return null;
  await ref.read(sessionProvider(sessionId).notifier).deleteRound(round);
  return EditResult(EditKind.deleted, round, number);
}

/// Nội dung nhập ván — dùng chung cho màn full và pane bên phải (tablet).
class RoundEditor extends ConsumerStatefulWidget {
  const RoundEditor({
    super.key,
    required this.sessionId,
    required this.data,
    this.editing,
    required this.onDone,
  });

  final int sessionId;
  final SessionData data;
  final GameRound? editing;
  final ValueChanged<EditResult> onDone;

  @override
  ConsumerState<RoundEditor> createState() => _RoundEditorState();
}

class _RoundEditorState extends ConsumerState<RoundEditor> {
  late int _dealerId;
  late Map<int, EntryDraft> _drafts;

  /// Người nghỉ ván này (giữ draft để thêm lại không mất dữ liệu).
  final Map<int, EntryDraft> _resting = {};
  DealerSuggestion? _suggestion;
  bool _saving = false;

  GameSession get _s => widget.data.session;
  RuleSet get _rules => _s.rules;
  bool get _variable => _s.mode == ScoringMode.variableMoney;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _dealerId = e.dealerId;
      _drafts = {
        for (final x in e.entries) x.playerId: EntryDraft.fromEntry(x),
      };
      for (final p in _s.activePlayers) {
        if (!e.involves(p.id)) {
          _resting[p.id] = EntryDraft(bet: _defaultBet(p.id));
        }
      }
    } else {
      _suggestion = ScoringEngine.suggestDealer(_s, widget.data.rounds);
      _dealerId = _suggestion!.playerId;
      _drafts = {
        for (final p in _s.activePlayers)
          if (p.id != _dealerId) p.id: EntryDraft(bet: _defaultBet(p.id)),
      };
    }
  }

  int _defaultBet(int playerId) {
    if (!_variable) return _s.baseBet;
    for (final r in widget.data.rounds.reversed) {
      for (final e in r.entries) {
        if (e.playerId == playerId && e.bet > 1) return e.bet;
      }
    }
    if (_s.fixedBet > 0) return _s.fixedBet;
    return ref.read(prefsProvider).defaultBet;
  }

  /// Người tham gia theo thứ tự chỗ ngồi.
  List<Player> get _ordered => [
    for (final p in _s.players)
      if (_drafts.containsKey(p.id)) p,
  ];

  List<Player> get _seatOptions => [
    for (final p in _s.players)
      if (p.active || p.id == _dealerId || _drafts.containsKey(p.id)) p,
  ];

  int get _dealerDelta => -_drafts.values.fold(0, (s, d) => s + d.delta);
  int get _unset => _drafts.values.where((d) => !d.isSet).length;

  void _setDealer(int id) {
    if (id == _dealerId) return;
    setState(() {
      final old = _dealerId;
      _dealerId = id;
      final moved = _drafts.remove(id) ?? _resting.remove(id);
      _drafts[old] = EntryDraft(bet: moved?.bet ?? _defaultBet(old));
      _suggestion = null;
    });
  }

  void _update(int id, EntryDraft d) => setState(() => _drafts[id] = d);

  void _rest(int id) => setState(() => _resting[id] = _drafts.remove(id)!);

  void _unrest(int id) => setState(() => _drafts[id] = _resting.remove(id)!);

  Future<void> _save() async {
    if (_unset > 0 || _drafts.isEmpty || _saving) return;
    setState(() => _saving = true);
    final ctrl = ref.read(sessionProvider(widget.sessionId).notifier);
    final entries = [for (final p in _ordered) _drafts[p.id]!.toEntry(p.id)];
    final e = widget.editing;
    haptic(ref);
    if (e == null) {
      final saved = await ctrl.addRound(
        GameRound(
          sessionId: widget.sessionId,
          idx: 0,
          dealerId: _dealerId,
          createdAt: DateTime.now(),
          entries: entries,
        ),
      );
      widget.onDone(
        EditResult(EditKind.added, saved, widget.data.rounds.length + 1),
      );
    } else {
      final updated = e.copyWith(dealerId: _dealerId, entries: entries);
      await ctrl.updateRound(updated);
      widget.onDone(
        EditResult(
          EditKind.updated,
          updated,
          widget.data.numberOf(e),
          previous: e,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final dealer = _s.playerById(_dealerId)!;
    final players = _ordered;
    final resting = [
      for (final p in _s.players)
        if (_resting.containsKey(p.id)) p,
    ];

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = (c.maxWidth / 380).floor().clamp(1, 3);
              final itemW = (c.maxWidth - 24 - (cols - 1) * 12) / cols;
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  _DealerCard(
                    options: _seatOptions,
                    dealerId: _dealerId,
                    suggestion: _suggestion,
                    onDealer: _setDealer,
                    onAction: (a) => setState(() {
                      _drafts = ScoringEngine.applyDealerAction(
                        _drafts,
                        a,
                        _rules,
                      );
                      haptic(ref);
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (players.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Chưa có người chơi nào trong ván này.',
                        textAlign: TextAlign.center,
                        style: t.textTheme.bodyMedium,
                      ),
                    ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final p in players)
                        SizedBox(
                          width: itemW,
                          child: _EntryCard(
                            key: ValueKey(p.id),
                            player: p,
                            draft: _drafts[p.id]!,
                            rules: _rules,
                            money: _s.isMoney,
                            variable: _variable,
                            onChanged: (d) => _update(p.id, d),
                            onRest: () => _rest(p.id),
                          ),
                        ),
                    ],
                  ),
                  if (resting.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Nghỉ ván này — chạm để thêm lại',
                      style: t.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final p in resting)
                          ActionChip(
                            avatar: PlayerAvatar(
                              name: p.name,
                              colorIdx: p.colorIdx,
                              size: 24,
                            ),
                            label: Text(p.name),
                            onPressed: () => _unrest(p.id),
                          ),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        _BottomBar(
          dealer: dealer,
          dealerDelta: _dealerDelta,
          money: _s.isMoney,
          unset: _unset,
          canSave: _unset == 0 && _drafts.isNotEmpty && !_saving,
          isEdit: widget.editing != null,
          onRestDraw: () => setState(() {
            _drafts = {
              for (final e in _drafts.entries)
                e.key: e.value.isSet
                    ? e.value
                    : e.value.copyWith(outcome: Outcome.draw, mul: 1),
            };
          }),
          onSave: _save,
        ),
      ],
    );
  }
}

class _DealerCard extends StatelessWidget {
  const _DealerCard({
    required this.options,
    required this.dealerId,
    required this.suggestion,
    required this.onDealer,
    required this.onAction,
  });

  final List<Player> options;
  final int dealerId;
  final DealerSuggestion? suggestion;
  final ValueChanged<int> onDealer;
  final ValueChanged<DealerAction> onAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final sug = suggestion;
    return Card(
      color: t.colorScheme.dealerTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.crown,
                    size: 14,
                    color: t.colorScheme.dealer,
                  ),
                  const SizedBox(width: 8),
                  Text('Nhà cái', style: t.textTheme.titleSmall),
                  if (sug?.byWinner != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '· vừa ăn ${sug!.byWinner!.label.toLowerCase()}',
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final p in options)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: PlayerAvatar(
                          name: p.name,
                          colorIdx: p.colorIdx,
                          size: 24,
                        ),
                        label: Text(p.name),
                        selected: p.id == dealerId,
                        onSelected: (_) => onDealer(p.id),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Kết quả nhanh — áp cho cả bàn, sửa riêng sau:',
                style: t.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Cái:', style: t.textTheme.labelLarge),
                  for (final a in DealerAction.values)
                    Tooltip(
                      message: a.label,
                      child: ActionChip(
                        label: Text(a.short),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => onAction(a),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    super.key,
    required this.player,
    required this.draft,
    required this.rules,
    required this.money,
    required this.variable,
    required this.onChanged,
    required this.onRest,
  });

  final Player player;
  final EntryDraft draft;
  final RuleSet rules;
  final bool money;
  final bool variable;
  final ValueChanged<EntryDraft> onChanged;
  final VoidCallback onRest;

  Future<void> _customMul(BuildContext context) async {
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chọn hệ số'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 1; i <= RuleSet.maxMul; i++)
              ChoiceChip(
                label: Text('x$i'),
                selected: draft.mul == i,
                onSelected: (_) => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (v != null) onChanged(draft.copyWith(mul: v));
  }

  Future<void> _editBet(BuildContext context, List<int> chips) async {
    final v = await amountDialog(
      context,
      title: 'Mức cược của ${player.name}',
      initial: draft.bet,
      chips: chips,
    );
    if (v != null) onChanged(draft.copyWith(bet: v));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final mulEnabled = draft.outcome != null && draft.outcome != Outcome.draw;
    final unset = !draft.isSet;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unset ? scheme.outlineVariant : scheme.surfaceContainerLow,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PlayerAvatar(
                  name: player.name,
                  colorIdx: player.colorIdx,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.titleMedium,
                      ),
                      if (variable)
                        Consumer(
                          builder: (context, ref, _) {
                            final chips = ref.watch(
                              prefsProvider.select((p) => p.betChips),
                            );
                            return InkWell(
                              onTap: () => _editBet(context, chips),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Cược ${formatAmount(draft.bet, money: true)}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: t.textTheme.bodySmall?.copyWith(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    FaIcon(
                                      FontAwesomeIcons.pen,
                                      size: 10,
                                      color: scheme.primary,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: draft.isSet
                        ? DeltaText(
                            draft.delta,
                            money: money,
                            style: t.textTheme.titleMedium,
                          )
                        : Text(
                            'Chưa chọn',
                            style: t.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn',
                  icon: const FaIcon(
                    FontAwesomeIcons.ellipsisVertical,
                    size: 16,
                  ),
                  onSelected: (_) => onRest(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rest', child: Text('Nghỉ ván này')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _OutcomeToggle(
                value: draft.outcome,
                onChanged: (o) =>
                    onChanged(ScoringEngine.applyOutcome(draft, o)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final tag in rules.availableTags)
                  FilterChip(
                    label: Text(tag.label),
                    visualDensity: VisualDensity.compact,
                    selected: draft.tag == tag,
                    onSelected: (_) =>
                        onChanged(ScoringEngine.applyTag(draft, tag, rules)),
                  ),
                for (final m in const [1, 2, 3])
                  ChoiceChip(
                    label: Text('x$m'),
                    visualDensity: VisualDensity.compact,
                    selected: mulEnabled && draft.mul == m,
                    onSelected: mulEnabled
                        ? (_) => onChanged(draft.copyWith(mul: m))
                        : null,
                  ),
                ChoiceChip(
                  label: Text(
                    mulEnabled && draft.mul > 3 ? 'x${draft.mul}' : 'x…',
                  ),
                  visualDensity: VisualDensity.compact,
                  selected: mulEnabled && draft.mul > 3,
                  onSelected: mulEnabled ? (_) => _customMul(context) : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 3 nút Thua / Hòa / Thắng, có màu riêng.
class _OutcomeToggle extends StatelessWidget {
  const _OutcomeToggle({required this.value, required this.onChanged});
  final Outcome? value;
  final ValueChanged<Outcome?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget btn(Outcome o, Color bg, Color fg) {
      final selected = value == o;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? bg : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onChanged(selected ? null : o),
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  o.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? fg : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        btn(Outcome.lose, scheme.negative, scheme.onError),
        const SizedBox(width: 8),
        btn(Outcome.draw, scheme.secondary, scheme.onSecondary),
        const SizedBox(width: 8),
        btn(
          Outcome.win,
          scheme.positive,
          scheme.brightness == Brightness.light ? Colors.white : Colors.black,
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.dealer,
    required this.dealerDelta,
    required this.money,
    required this.unset,
    required this.canSave,
    required this.isEdit,
    required this.onRestDraw,
    required this.onSave,
  });

  final Player dealer;
  final int dealerDelta;
  final bool money;
  final int unset;
  final bool canSave;
  final bool isEdit;
  final VoidCallback onRestDraw;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unset > 0)
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Còn $unset người chưa chọn',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextButton(
                      onPressed: onRestDraw,
                      child: const Text('Đặt còn lại là Hòa'),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                PlayerAvatar(
                  name: dealer.name,
                  colorIdx: dealer.colorIdx,
                  size: 32,
                  isDealer: true,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Cái ${dealer.name}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall,
                      ),
                      DeltaText(
                        dealerDelta,
                        money: money,
                        style: t.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: canSave ? onSave : null,
                  icon: const FaIcon(FontAwesomeIcons.check, size: 16),
                  label: Text(isEdit ? 'Cập nhật' : 'Lưu ván'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
