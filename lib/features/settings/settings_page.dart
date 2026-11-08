import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app.dart';
import '../../core/format/money.dart';
import '../../core/layout/breakpoints.dart';
import '../../core/widgets/common.dart';
import '../../data/settings_repository.dart';
import '../../domain/models/enums.dart';
import '../../state/providers.dart';
import '../donate/donate_page.dart';
import '../rules_reference/rules_view.dart';
import 'about_page.dart';
import 'groups_page.dart';
import 'rules_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static Widget _icon(FaIconData i) =>
      SizedBox(width: 24, child: Center(child: FaIcon(i, size: 18)));

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(prefsProvider);
    final n = ref.read(prefsProvider.notifier);

    Future<void> choose<T>(
      String title,
      List<T> values,
      T current,
      String Function(T) label,
      void Function(T) onPick,
    ) async {
      final v = await showDialog<T>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(title),
          children: [
            RadioGroup<T>(
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
              child: Column(
                children: [
                  for (final x in values)
                    RadioListTile<T>(value: x, title: Text(label(x))),
                ],
              ),
            ),
          ],
        ),
      );
      if (v != null) onPick(v);
    }

    String themeLabel(ThemeMode m) => switch (m) {
      ThemeMode.system => 'Theo hệ thống',
      ThemeMode.light => 'Sáng',
      ThemeMode.dark => 'Tối',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SectionHeader('Lưu sẵn để chơi nhanh'),
                ListTile(
                  leading: _icon(FontAwesomeIcons.userGroup),
                  title: const Text('Danh sách người chơi'),
                  subtitle: const Text(
                    'Lần sau chỉ cần chọn, khỏi nhập lại tên',
                  ),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () => _push(context, const GroupsPage()),
                ),
                ListTile(
                  leading: _icon(FontAwesomeIcons.scaleBalanced),
                  title: const Text('Bộ luật'),
                  subtitle: const Text(
                    'Hệ số xì bàng, xì dách, ngũ linh, quắc…',
                  ),
                  trailing: const FaIcon(
                    FontAwesomeIcons.chevronRight,
                    size: 14,
                  ),
                  onTap: () => _push(context, const RulesPage()),
                ),
                const SectionHeader('Mặc định khi tạo lần chơi mới'),
                ListTile(
                  leading: _icon(FontAwesomeIcons.calculator),
                  title: const Text('Cách tính'),
                  subtitle: Text(p.defaultMode.label),
                  onTap: () => choose<ScoringMode>(
                    'Cách tính',
                    ScoringMode.values,
                    p.defaultMode,
                    (m) => m.label,
                    (m) => n.update((x) => x.copyWith(defaultMode: m)),
                  ),
                ),
                ListTile(
                  leading: _icon(FontAwesomeIcons.coins),
                  title: const Text('Mức cược mặc định'),
                  subtitle: Text(formatAmount(p.defaultBet, money: true)),
                  onTap: () async {
                    final v = await amountDialog(
                      context,
                      title: 'Mức cược mặc định',
                      initial: p.defaultBet,
                      chips: p.betChips,
                    );
                    if (v != null) {
                      await n.update((x) => x.copyWith(defaultBet: v));
                    }
                  },
                ),
                ListTile(
                  leading: _icon(FontAwesomeIcons.moneyBillWave),
                  title: const Text('Mức cược chọn nhanh'),
                  subtitle: Text(
                    p.betChips
                        .map(
                          (c) => formatCompact(c, money: true, signed: false),
                        )
                        .join(' · '),
                  ),
                  onTap: () => _editChips(context, ref, p.betChips),
                ),
                const SectionHeader('Giao diện & sử dụng'),
                ListTile(
                  leading: _icon(FontAwesomeIcons.circleHalfStroke),
                  title: const Text('Chủ đề'),
                  subtitle: Text(themeLabel(p.themeMode)),
                  onTap: () => choose<ThemeMode>(
                    'Chủ đề',
                    ThemeMode.values,
                    p.themeMode,
                    themeLabel,
                    (m) => n.update((x) => x.copyWith(themeMode: m)),
                  ),
                ),
                // Trình duyệt không cho khóa xoay màn hình.
                if (!kIsWeb)
                  ListTile(
                    leading: _icon(FontAwesomeIcons.mobileScreenButton),
                    title: const Text('Xoay màn hình'),
                    subtitle: Text(p.orientation.label),
                    onTap: () => choose<OrientationPref>(
                      'Xoay màn hình',
                      OrientationPref.values,
                      p.orientation,
                      (o) => o.label,
                      (o) => n.update((x) => x.copyWith(orientation: o)),
                    ),
                  ),
                SwitchListTile(
                  secondary: _icon(FontAwesomeIcons.lightbulb),
                  title: const Text('Giữ màn hình sáng'),
                  subtitle: const Text('Khi đang ở bảng điểm'),
                  value: p.keepAwake,
                  onChanged: (v) => n.update((x) => x.copyWith(keepAwake: v)),
                ),
                SwitchListTile(
                  secondary: _icon(FontAwesomeIcons.handPointer),
                  title: const Text('Rung khi thao tác'),
                  value: p.haptics,
                  onChanged: (v) => n.update((x) => x.copyWith(haptics: v)),
                ),
                const SectionHeader(
                  kIsWeb ? 'Dữ liệu trong trình duyệt' : 'Dữ liệu trên máy',
                ),
                const _DataSection(),
                const SectionHeader('Khác'),
                ListTile(
                  leading: _icon(FontAwesomeIcons.bookOpen),
                  title: const Text('Luật xì dách'),
                  onTap: () => _push(context, const RulesReferencePage()),
                ),
                if (!kIsWeb)
                  ListTile(
                    leading: _icon(FontAwesomeIcons.mugHot),
                    title: const Text('Ủng hộ nhà phát triển'),
                    onTap: () => _push(context, const DonatePage()),
                  ),
                ListTile(
                  leading: _icon(FontAwesomeIcons.circleInfo),
                  title: const Text('Giới thiệu'),
                  subtitle: const Text('$appName · phiên bản $appVersion'),
                  onTap: () => _push(context, const AboutPage()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editChips(
    BuildContext context,
    WidgetRef ref,
    List<int> chips,
  ) async {
    final text = await textInputDialog(
      context,
      title: 'Mức cược chọn nhanh',
      initial: chips
          .map((c) => formatCompact(c, money: true, signed: false))
          .join(', '),
      hint: '5k, 10k, 20k, 50k',
      maxLength: 60,
    );
    if (text == null) return;
    final values = [
      for (final s in text.split(RegExp(r'[,;]')))
        if (parseAmount(s) case final v? when v > 0) v,
    ]..sort();
    if (values.isEmpty) return;
    await ref
        .read(prefsProvider.notifier)
        .update((x) => x.copyWith(betChips: values.toSet().take(6).toList()));
  }
}

class _DataSection extends ConsumerStatefulWidget {
  const _DataSection();

  @override
  ConsumerState<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends ConsumerState<_DataSection> {
  late Future<(int, int, int, int)> _info = _load();

  Future<(int, int, int, int)> _load() async {
    final size = await ref.read(databaseProvider).sizeInBytes();
    final sessions = await ref.read(sessionRepoProvider).countSessions();
    final (g, r) = await ref.read(settingsRepoProvider).countSettings();
    return (size, sessions, g, r);
  }

  void _reload() => setState(() => _info = _load());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: _info,
      builder: (context, snap) {
        final (size, sessions, groups, rules) = snap.data ?? (0, 0, 0, 0);
        return Column(
          children: [
            ListTile(
              leading: const SizedBox(
                width: 24,
                child: Center(
                  child: FaIcon(FontAwesomeIcons.database, size: 18),
                ),
              ),
              title: const Text('Dung lượng đang dùng'),
              subtitle: Text(snap.hasData ? formatBytes(size) : '…'),
            ),
            ListTile(
              leading: SizedBox(
                width: 24,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.trashCan,
                    size: 18,
                    color: scheme.error,
                  ),
                ),
              ),
              title: Text(
                'Xóa dữ liệu chơi',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: Text('$sessions lần chơi và toàn bộ các ván'),
              enabled: sessions > 0,
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Xóa dữ liệu chơi?',
                  message:
                      'Sẽ xóa vĩnh viễn $sessions lần chơi và toàn bộ ván đã ghi. '
                      'Danh sách người chơi, bộ luật và cài đặt vẫn giữ nguyên.',
                  confirm: 'Xóa hết',
                );
                if (!ok) return;
                await ref.read(sessionRepoProvider).deleteAllSessions();
                ref.invalidate(sessionsProvider);
                _reload();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã xóa dữ liệu chơi')),
                  );
                }
              },
            ),
            ListTile(
              leading: SizedBox(
                width: 24,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.broom,
                    size: 18,
                    color: scheme.error,
                  ),
                ),
              ),
              title: Text(
                'Xóa dữ liệu cài đặt',
                style: TextStyle(color: scheme.error),
              ),
              subtitle: Text(
                '$groups danh sách người chơi, $rules bộ luật tự tạo, '
                'các tùy chọn',
              ),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Xóa dữ liệu cài đặt?',
                  message:
                      'Sẽ xóa $groups danh sách người chơi, $rules bộ luật tự tạo, '
                      'khôi phục bộ luật mặc định và đưa mọi tùy chọn về ban đầu. '
                      'Các lần chơi đã lưu vẫn giữ nguyên.',
                  confirm: 'Xóa & đặt lại',
                );
                if (!ok) return;
                await ref.read(settingsRepoProvider).clearSettings();
                ref.read(prefsProvider.notifier).reload();
                ref.invalidate(groupsProvider);
                ref.invalidate(rulesProvider);
                _reload();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã đặt lại cài đặt')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
