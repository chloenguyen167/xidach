import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/theme/player_palette.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/player.dart';
import '../../domain/models/session.dart';
import '../../state/providers.dart';

/// Danh sách các nhóm người chơi lưu sẵn.
class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  Future<void> _open(BuildContext context, [PlayerGroup? g]) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => GroupEditorPage(group: g)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách người chơi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
        label: const Text('Tạo danh sách'),
      ),
      body: groups.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: FontAwesomeIcons.userGroup,
                title: 'Chưa có danh sách nào',
                message:
                    'Lưu nhóm bạn hay chơi cùng để lần sau chỉ cần chọn, khỏi nhập lại tên.',
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final g in list)
                    MaxWidth(
                      child: ListTile(
                        title: Text(g.name),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final m in g.members)
                                Chip(
                                  avatar: PlayerAvatar(
                                    name: m.name,
                                    colorIdx: m.colorIdx,
                                    size: 20,
                                  ),
                                  label: Text(m.name),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                            ],
                          ),
                        ),
                        onTap: () => _open(context, g),
                        trailing: IconButton(
                          tooltip: 'Xóa',
                          icon: const FaIcon(
                            FontAwesomeIcons.trashCan,
                            size: 16,
                          ),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              context,
                              title: 'Xóa "${g.name}"?',
                              message:
                                  'Các lần chơi đã tạo không bị ảnh hưởng.',
                            );
                            if (!ok) return;
                            await ref
                                .read(settingsRepoProvider)
                                .deleteGroup(g.id!);
                            ref.invalidate(groupsProvider);
                          },
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class GroupEditorPage extends ConsumerStatefulWidget {
  const GroupEditorPage({super.key, this.group});
  final PlayerGroup? group;

  @override
  ConsumerState<GroupEditorPage> createState() => _GroupEditorPageState();
}

class _GroupEditorPageState extends ConsumerState<GroupEditorPage> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  final _add = TextEditingController();
  final _addFocus = FocusNode();
  late final List<Member> _members = [...?widget.group?.members];

  @override
  void dispose() {
    _name.dispose();
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  void _addMember() {
    final n = _add.text.trim();
    if (n.isEmpty || _members.length >= GameSession.maxPlayers) return;
    if (_members.any((m) => m.name.toLowerCase() == n.toLowerCase())) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"$n" đã có trong danh sách')));
      return;
    }
    setState(() {
      _members.add(
        Member(n, PlayerPalette.nextFree(_members.map((m) => m.colorIdx))),
      );
      _add.clear();
    });
    _addFocus.requestFocus();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _members.length < 2) return;
    await ref
        .read(settingsRepoProvider)
        .saveGroup(
          PlayerGroup(id: widget.group?.id, name: name, members: _members),
        );
    ref.invalidate(groupsProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final full = _members.length >= GameSession.maxPlayers;
    final canSave = _name.text.trim().isNotEmpty && _members.length >= 2;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group == null ? 'Danh sách mới' : 'Sửa danh sách'),
        actions: [
          TextButton(
            onPressed: canSave ? _save : null,
            child: const Text('Lưu'),
          ),
        ],
      ),
      body: MaxWidth(
        expand: true,
        child: ReorderableListView.builder(
          buildDefaultDragHandles: false,
          header: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  autofocus: widget.group == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Tên danh sách',
                    hintText: 'VD: Hội bạn thân',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _add,
                        focusNode: _addFocus,
                        enabled: !full,
                        maxLength: 20,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: full
                              ? 'Tối đa ${GameSession.maxPlayers} người'
                              : 'Thêm người (${_members.length}/${GameSession.maxPlayers})',
                        ),
                        onEditingComplete: _addMember,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Thêm',
                      onPressed: full ? null : _addMember,
                      icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          itemCount: _members.length,
          onReorderItem: (a, b) => setState(() {
            _members.insert(b, _members.removeAt(a));
          }),
          itemBuilder: (context, i) {
            final m = _members[i];
            return ListTile(
              key: ValueKey('m-${m.name}'),
              leading: InkResponse(
                onTap: () async {
                  final c = await pickColorDialog(
                    context,
                    m.colorIdx,
                    used: _members.map((x) => x.colorIdx).toSet(),
                  );
                  if (c != null) {
                    setState(() => _members[i] = m.copyWith(colorIdx: c));
                  }
                },
                child: PlayerAvatar(name: m.name, colorIdx: m.colorIdx),
              ),
              title: Text(m.name),
              onTap: () async {
                final n = await textInputDialog(
                  context,
                  title: 'Đổi tên',
                  initial: m.name,
                  maxLength: 20,
                );
                if (n != null) {
                  setState(() => _members[i] = m.copyWith(name: n));
                }
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Xóa',
                    icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                    onPressed: () => setState(() => _members.removeAt(i)),
                  ),
                  ReorderableDragStartListener(
                    index: i,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: FaIcon(FontAwesomeIcons.gripVertical, size: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
