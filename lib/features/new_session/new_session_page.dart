import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/format/money.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/player_palette.dart';
import '../../core/widgets/common.dart';
import '../../data/settings_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/player.dart';
import '../../domain/models/rule_set.dart';
import '../../domain/models/session.dart';
import '../../state/providers.dart';
import '../session/session_page.dart';
import '../settings/rule_form.dart';

class _Draft {
  _Draft(this.name, this.colorIdx);
  final Key key = UniqueKey();
  String name;
  int colorIdx;
}

class NewSessionPage extends ConsumerStatefulWidget {
  const NewSessionPage({super.key});

  @override
  ConsumerState<NewSessionPage> createState() => _NewSessionPageState();
}

class _NewSessionPageState extends ConsumerState<NewSessionPage> {
  final _nameCtrl = TextEditingController();
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  final _betCtrl = TextEditingController();

  final List<_Draft> _players = [];
  int _dealerIdx = 0;
  ScoringMode _mode = ScoringMode.points;
  int? _ruleId;
  RuleSet? _rules; // null = chưa tải preset
  bool _customized = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    // Cách tính / mức cược / bộ luật lấy theo mặc định trong Cài đặt.
    // Người chơi lần trước: 1 chạm vào chip "Lần trước".
    final prefs = ref.read(prefsProvider);
    _nameCtrl.text = 'Lần chơi ${formatDateTime(DateTime.now())}';
    _mode = prefs.defaultMode;
    _betCtrl.text = formatNumber(prefs.defaultBet);
    _ruleId = prefs.defaultRuleId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addCtrl.dispose();
    _addFocus.dispose();
    _betCtrl.dispose();
    super.dispose();
  }

  bool get _full => _players.length >= GameSession.maxPlayers;

  void _snack(String msg) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));

  void _addFromInput() {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    if (_full) {
      _snack('Tối đa ${GameSession.maxPlayers} người (kể cả nhà cái)');
      return;
    }
    if (_players.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      _snack('"$name" đã có trong danh sách');
      return;
    }
    setState(() {
      _players.add(
        _Draft(name, PlayerPalette.nextFree(_players.map((p) => p.colorIdx))),
      );
      _addCtrl.clear();
    });
    _addFocus.requestFocus();
  }

  void _loadMembers(List<Member> members, {int dealerIdx = 0}) {
    setState(() {
      _players
        ..clear()
        ..addAll(
          members
              .take(GameSession.maxPlayers)
              .map((m) => _Draft(m.name, m.colorIdx)),
        );
      _dealerIdx = dealerIdx.clamp(
        0,
        _players.isEmpty ? 0 : _players.length - 1,
      );
    });
  }

  Future<void> _saveAsGroup() async {
    final name = await textInputDialog(
      context,
      title: 'Lưu danh sách người chơi',
      hint: 'VD: Hội bạn thân',
    );
    if (name == null) return;
    await ref
        .read(settingsRepoProvider)
        .saveGroup(
          PlayerGroup(
            name: name,
            members: [for (final p in _players) Member(p.name, p.colorIdx)],
          ),
        );
    ref.invalidate(groupsProvider);
    if (mounted) _snack('Đã lưu "$name"');
  }

  Future<void> _start() async {
    if (_players.length < GameSession.minPlayers || _rules == null) return;
    setState(() => _starting = true);
    final bet = parseAmount(_betCtrl.text) ?? 0;
    final now = DateTime.now();
    final name = _nameCtrl.text.trim().isEmpty
        ? 'Lần chơi ${formatDateTime(now)}'
        : _nameCtrl.text.trim();
    final session = GameSession(
      name: name,
      createdAt: now,
      updatedAt: now,
      mode: _mode,
      fixedBet: _mode == ScoringMode.points ? 0 : bet,
      rules: _rules!.copyWith(clearId: true),
      players: [
        for (var i = 0; i < _players.length; i++)
          Player(
            id: i + 1,
            name: _players[i].name,
            colorIdx: _players[i].colorIdx,
          ),
      ],
      dealerId: _dealerIdx + 1,
    );
    final id = await ref.read(sessionRepoProvider).createSession(session);
    await ref
        .read(prefsProvider.notifier)
        .update(
          (p) => p.copyWith(
            lastSetup: LastSetup(
              members: [for (final p in _players) Member(p.name, p.colorIdx)],
              dealerIdx: _dealerIdx,
              ruleId: _ruleId,
              mode: _mode,
              bet: bet,
            ),
          ),
        );
    ref.invalidate(sessionsProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SessionPage(sessionId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);
    final groups = ref.watch(groupsProvider).value ?? const [];
    final presets = rulesAsync.value ?? const <RuleSet>[];
    if (_rules == null && presets.isNotEmpty) {
      final chosen = presets.firstWhere(
        (r) => r.id == _ruleId,
        orElse: () => presets.first,
      );
      _ruleId = chosen.id;
      _rules = chosen;
    }
    final last = ref.read(prefsProvider).lastSetup;
    final t = Theme.of(context);
    final canStart =
        _players.length >= GameSession.minPlayers && _rules != null;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Tên lần chơi'),
            textCapitalization: TextCapitalization.sentences,
          ),
        ),
        SectionHeader(
          'Người chơi (${_players.length}/${GameSession.maxPlayers})',
          trailing: _players.length >= 2
              ? TextButton.icon(
                  onPressed: _saveAsGroup,
                  icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
                  label: const Text('Lưu danh sách'),
                )
              : null,
        ),
        if (groups.isNotEmpty || (last != null && last.members.isNotEmpty))
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (last != null && last.members.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const FaIcon(
                        FontAwesomeIcons.clockRotateLeft,
                        size: 14,
                      ),
                      label: const Text('Lần trước'),
                      onPressed: () =>
                          _loadMembers(last.members, dealerIdx: last.dealerIdx),
                    ),
                  ),
                for (final g in groups)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const FaIcon(
                        FontAwesomeIcons.userGroup,
                        size: 14,
                      ),
                      label: Text('${g.name} (${g.members.length})'),
                      onPressed: () => _loadMembers(g.members),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('add-player'),
                  controller: _addCtrl,
                  focusNode: _addFocus,
                  enabled: !_full,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  maxLength: 20,
                  decoration: InputDecoration(
                    hintText: _full ? 'Đã đủ người' : 'Nhập tên rồi bấm Enter',
                    counterText: '',
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(12),
                      child: FaIcon(FontAwesomeIcons.userPlus, size: 16),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44),
                  ),
                  onEditingComplete: _addFromInput,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Thêm người chơi',
                onPressed: _full ? null : _addFromInput,
                icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
              ),
            ],
          ),
        ),
        if (_players.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              'Chạm vương miện để chọn nhà cái ván đầu · kéo để đổi chỗ ngồi',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Cách tính'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<ScoringMode>(
            showSelectedIcon: false,
            segments: [
              for (final m in ScoringMode.values)
                ButtonSegment(
                  value: m,
                  label: Text(m.label, textAlign: TextAlign.center),
                ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            switch (_mode) {
              ScoringMode.points =>
                'Mỗi ván thắng/thua tính theo điểm × hệ số.',
              ScoringMode.fixedMoney =>
                'Mọi người cược bằng nhau mỗi ván. Bỏ trống mức cược thì tính như điểm.',
              ScoringMode.variableMoney =>
                'Mỗi người mỗi ván một mức cược, tự lấy lại mức của ván trước.',
            },
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (_mode != ScoringMode.points)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _BetField(
              controller: _betCtrl,
              label: _mode == ScoringMode.fixedMoney
                  ? 'Mức cược mỗi ván (không bắt buộc)'
                  : 'Mức cược ban đầu',
              chips: ref.watch(prefsProvider.select((p) => p.betChips)),
            ),
          ),
        const SectionHeader('Bộ luật'),
        if (presets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownMenu<int>(
              key: ValueKey(_ruleId),
              expandedInsets: EdgeInsets.zero,
              initialSelection: _ruleId,
              label: const Text('Chọn bộ luật'),
              leadingIcon: const Padding(
                padding: EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.scaleBalanced, size: 16),
              ),
              dropdownMenuEntries: [
                for (final r in presets)
                  DropdownMenuEntry(value: r.id!, label: r.name),
              ],
              onSelected: (id) => setState(() {
                _ruleId = id;
                _rules = presets.firstWhere((r) => r.id == id);
                _customized = false;
              }),
            ),
          ),
        if (_rules != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              (_customized ? '(Đã chỉnh cho lần này) ' : '') + _rules!.summary,
              style: t.textTheme.bodySmall?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Theme(
            data: t.copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              title: const Text('Tùy chỉnh luật cho lần này'),
              leading: const FaIcon(FontAwesomeIcons.sliders, size: 18),
              children: [
                RuleForm(
                  rules: _rules!,
                  onChanged: (r) => setState(() {
                    _rules = r;
                    _customized = true;
                  }),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Lần chơi mới')),
      body: MaxWidth(
        expand: true,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          header: header,
          footer: footer,
          itemCount: _players.length,
          onReorderItem: (oldI, newI) => setState(() {
            final dealer = _players[_dealerIdx];
            _players.insert(newI, _players.removeAt(oldI));
            _dealerIdx = _players.indexOf(dealer);
          }),
          itemBuilder: (context, i) => _PlayerRow(
            key: _players[i].key,
            index: i,
            draft: _players[i],
            isDealer: i == _dealerIdx,
            onDealer: () => setState(() => _dealerIdx = i),
            onRemove: () => setState(() {
              _players.removeAt(i);
              if (i < _dealerIdx) _dealerIdx--;
              if (_dealerIdx >= _players.length) _dealerIdx = 0;
            }),
            onRename: () async {
              final n = await textInputDialog(
                context,
                title: 'Đổi tên',
                initial: _players[i].name,
                maxLength: 20,
              );
              if (n != null) setState(() => _players[i].name = n);
            },
            onColor: () async {
              final c = await pickColorDialog(
                context,
                _players[i].colorIdx,
                used: _players.map((p) => p.colorIdx).toSet(),
              );
              if (c != null) setState(() => _players[i].colorIdx = c);
            },
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: MaxWidth(
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canStart && !_starting ? _start : null,
                icon: const FaIcon(FontAwesomeIcons.play, size: 16),
                label: Text(
                  canStart
                      ? 'Bắt đầu'
                      : 'Cần ít nhất ${GameSession.minPlayers} người chơi',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    super.key,
    required this.index,
    required this.draft,
    required this.isDealer,
    required this.onDealer,
    required this.onRemove,
    required this.onRename,
    required this.onColor,
  });

  final int index;
  final _Draft draft;
  final bool isDealer;
  final VoidCallback onDealer, onRemove, onRename, onColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: Semantics(
          button: true,
          label: 'Đổi màu ${draft.name}',
          child: InkResponse(
            onTap: onColor,
            child: PlayerAvatar(
              name: draft.name,
              colorIdx: draft.colorIdx,
              isDealer: isDealer,
            ),
          ),
        ),
        title: Text(draft.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: isDealer ? const Text('Nhà cái ván đầu') : null,
        onTap: onRename,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Chọn làm nhà cái',
              isSelected: isDealer,
              onPressed: onDealer,
              icon: FaIcon(
                FontAwesomeIcons.crown,
                size: 16,
                color: scheme.outlineVariant,
              ),
              selectedIcon: FaIcon(
                FontAwesomeIcons.crown,
                size: 16,
                color: scheme.dealer,
              ),
            ),
            IconButton(
              tooltip: 'Xóa',
              onPressed: onRemove,
              icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
            ),
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: FaIcon(FontAwesomeIcons.gripVertical, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BetField extends StatelessWidget {
  const _BetField({
    required this.controller,
    required this.label,
    required this.chips,
  });
  final TextEditingController controller;
  final String label;
  final List<int> chips;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          decoration: InputDecoration(labelText: label, suffixText: 'đ'),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in chips)
              ActionChip(
                label: Text(formatCompact(c, money: true, signed: false)),
                onPressed: () => controller.text = formatNumber(c),
              ),
          ],
        ),
      ],
    );
  }
}
