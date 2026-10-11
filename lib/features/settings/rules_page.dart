import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';
import '../../domain/models/rule_set.dart';
import '../../state/providers.dart';
import 'rule_form.dart';

/// Danh sách bộ luật lưu sẵn.
class RulesPage extends ConsumerWidget {
  const RulesPage({super.key});

  Future<void> _open(BuildContext context, RuleSet r) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => RuleEditorPage(initial: r)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider);
    final defaultId = ref.watch(prefsProvider.select((p) => p.defaultRuleId));
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bộ luật')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, const RuleSet(name: 'Luật mới')),
        icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
        label: const Text('Tạo bộ luật'),
      ),
      body: rules.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          final effectiveDefault = list.any((r) => r.id == defaultId)
              ? defaultId
              : list.first.id;
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final r in list)
                MaxWidth(
                  child: ListTile(
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(r.name, overflow: TextOverflow.ellipsis),
                        ),
                        if (r.id == effectiveDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: t.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Mặc định',
                              style: t.textTheme.labelSmall?.copyWith(
                                color: t.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(r.summary),
                    onTap: () => _open(context, r),
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Tùy chọn',
                      icon: const FaIcon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 16,
                      ),
                      onSelected: (v) async {
                        final repo = ref.read(settingsRepoProvider);
                        switch (v) {
                          case 'default':
                            await ref
                                .read(prefsProvider.notifier)
                                .update((p) => p.copyWith(defaultRuleId: r.id));
                          case 'copy':
                            await repo.saveRule(
                              r.copyWith(
                                clearId: true,
                                builtin: false,
                                name: '${r.name} (bản sao)',
                              ),
                            );
                          case 'reset':
                            await repo.resetBuiltinRule();
                          case 'delete':
                            if (!context.mounted) return;
                            final ok = await confirmDialog(
                              context,
                              title: 'Xóa "${r.name}"?',
                              message: 'Các lần chơi đã tạo vẫn giữ luật cũ.',
                            );
                            if (ok) await repo.deleteRule(r.id!);
                        }
                        ref.invalidate(rulesProvider);
                      },
                      itemBuilder: (_) => [
                        if (r.id != effectiveDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Đặt làm mặc định'),
                          ),
                        const PopupMenuItem(
                          value: 'copy',
                          child: Text('Nhân bản'),
                        ),
                        if (r.builtin)
                          const PopupMenuItem(
                            value: 'reset',
                            child: Text('Khôi phục giá trị gốc'),
                          )
                        else
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Xóa'),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RuleEditorPage extends ConsumerStatefulWidget {
  const RuleEditorPage({super.key, required this.initial});
  final RuleSet initial;

  @override
  ConsumerState<RuleEditorPage> createState() => _RuleEditorPageState();
}

class _RuleEditorPageState extends ConsumerState<RuleEditorPage> {
  late RuleSet _r = widget.initial;
  late final _name = TextEditingController(text: widget.initial.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    await ref.read(settingsRepoProvider).saveRule(_r.copyWith(name: name));
    ref.invalidate(rulesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial.id == null ? 'Bộ luật mới' : 'Sửa bộ luật'),
        actions: [TextButton(onPressed: _save, child: const Text('Lưu'))],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _name,
                    maxLength: 30,
                    decoration: const InputDecoration(labelText: 'Tên bộ luật'),
                  ),
                ),
                RuleForm(rules: _r, onChanged: (r) => setState(() => _r = r)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
