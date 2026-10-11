import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../format/money.dart';
import '../theme/app_theme.dart';
import '../theme/player_palette.dart';

/// Avatar tròn màu người chơi + chữ cái đầu (không chỉ dựa vào màu).
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.name,
    required this.colorIdx,
    this.size = 36,
    this.isDealer = false,
    this.dimmed = false,
  });

  final String name;
  final int colorIdx;
  final double size;
  final bool isDealer;
  final bool dimmed;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final last = parts.last;
    return last.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = PlayerPalette.of(colorIdx);
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dimmed ? color.withValues(alpha: 0.35) : color,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(name),
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          color: PlayerPalette.onColor(colorIdx),
          fontWeight: FontWeight.w700,
          fontSize: size * 0.44,
        ),
      ),
    );
    if (!isDealer) return avatar;
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -size * 0.18,
          top: -size * 0.22,
          child: Container(
            padding: EdgeInsets.all(size * 0.08),
            decoration: BoxDecoration(
              color: scheme.dealer,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 1.5),
            ),
            child: FaIcon(
              FontAwesomeIcons.crown,
              size: size * 0.26,
              color: scheme.onDealer,
            ),
          ),
        ),
      ],
    );
  }
}

/// Số điểm/tiền có dấu, có màu.
class DeltaText extends StatelessWidget {
  const DeltaText(
    this.value, {
    super.key,
    required this.money,
    this.style,
    this.compact = false,
  });

  final int value;
  final bool money;
  final TextStyle? style;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = compact
        ? formatCompact(value, money: money)
        : formatDelta(value, money: money);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: (style ?? const TextStyle()).copyWith(
        color: scheme.scoreColor(value),
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Nhãn nhỏ cho từng nhóm trong form/list.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing, this.padding});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: t.textTheme.titleSmall?.copyWith(
                color: t.colorScheme.primary,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final FaIconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(icon, size: 48, color: t.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: t.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Bộ chỉnh số nguyên [−] value [+].
class NumberStepper extends StatelessWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 10,
    this.prefix = 'x',
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Giảm',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const FaIcon(FontAwesomeIcons.minus, size: 14),
        ),
        SizedBox(
          width: 44,
          child: Text(
            '$prefix$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Tăng',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
        ),
      ],
    );
  }
}

/// Hộp thoại xác nhận. Trả `true` nếu người dùng đồng ý.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Xóa',
  bool destructive = true,
}) async {
  final scheme = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Hộp thoại nhập một dòng chữ.
Future<String?> textInputDialog(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  String confirm = 'Lưu',
  int maxLength = 40,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = ctrl.text.trim();
        if (v.isNotEmpty) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: maxLength,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(onPressed: submit, child: Text(confirm)),
        ],
      );
    },
  );
}

/// Hộp thoại nhập số tiền, có chip chọn nhanh.
Future<int?> amountDialog(
  BuildContext context, {
  required String title,
  int? initial,
  List<int> chips = const [],
  bool allowZero = false,
}) {
  final ctrl = TextEditingController(
    text: initial == null || initial == 0 ? '' : formatNumber(initial),
  );
  return showDialog<int>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = parseAmount(ctrl.text) ?? (allowZero ? 0 : null);
        if (v != null && (allowZero || v > 0)) Navigator.pop(ctx, v);
      }

      return AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [MoneyInputFormatter()],
              decoration: const InputDecoration(
                suffixText: 'đ',
                hintText: '10.000',
              ),
              onSubmitted: (_) => submit(),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final c in chips)
                    ActionChip(
                      label: Text(formatCompact(c, money: true, signed: false)),
                      onPressed: () => Navigator.pop(ctx, c),
                    ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(onPressed: submit, child: const Text('OK')),
        ],
      );
    },
  );
}

/// Tự chèn dấu chấm phân cách hàng nghìn khi nhập tiền.
class MoneyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final v = int.tryParse(
      digits.length > 12 ? digits.substring(0, 12) : digits,
    );
    if (v == null) return oldValue;
    final text = formatNumber(v);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Chọn màu người chơi.
Future<int?> pickColorDialog(
  BuildContext context,
  int current, {
  Set<int> used = const {},
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chọn màu'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (var i = 0; i < PlayerPalette.colors.length; i++)
            Semantics(
              button: true,
              selected: i == current,
              label: PlayerPalette.names[i],
              child: InkResponse(
                onTap: () => Navigator.pop(ctx, i),
                radius: 28,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: PlayerPalette.of(i),
                    shape: BoxShape.circle,
                    border: i == current
                        ? Border.all(
                            color: Theme.of(ctx).colorScheme.onSurface,
                            width: 3,
                          )
                        : null,
                  ),
                  child: i == current
                      ? Center(
                          child: FaIcon(
                            FontAwesomeIcons.check,
                            size: 18,
                            color: PlayerPalette.onColor(i),
                          ),
                        )
                      : (used.contains(i)
                            ? Center(
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: PlayerPalette.onColor(i),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null),
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
