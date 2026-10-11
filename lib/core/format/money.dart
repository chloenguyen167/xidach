import 'package:intl/intl.dart';

final _num = NumberFormat.decimalPattern('vi');
final _time = DateFormat('HH:mm', 'vi');
final _dateTime = DateFormat('dd/MM HH:mm', 'vi');
final _fullDate = DateFormat('dd/MM/yyyy HH:mm', 'vi');

/// Định dạng số: 10000 → "10.000".
String formatNumber(int v) => _num.format(v);

/// Định dạng điểm hoặc tiền, không dấu: "10.000đ" / "12".
String formatAmount(int v, {required bool money}) =>
    money ? '${_num.format(v)}đ' : _num.format(v);

/// Có dấu: "+10.000đ", "−5", "0". Dùng dấu trừ thật (−) cho dễ đọc.
String formatDelta(int v, {required bool money}) {
  final abs = formatAmount(v.abs(), money: money);
  if (v > 0) return '+$abs';
  if (v < 0) return '−$abs';
  return abs;
}

/// Dạng gọn cho bảng/chip: 10000 → "+10k", 1500000 → "+1,5tr".
/// [signed] = false cho mức cược (không dấu): "10k".
String formatCompact(int v, {required bool money, bool signed = true}) {
  if (!money) {
    return signed ? formatDelta(v, money: false) : formatNumber(v);
  }
  final sign = !signed ? '' : (v > 0 ? '+' : (v < 0 ? '−' : ''));
  final a = v.abs();
  String s;
  if (a >= 1000000) {
    s = '${_trim(a / 1000000)}tr';
  } else if (a >= 1000) {
    s = '${_trim(a / 1000)}k';
  } else {
    s = '$a';
  }
  return '$sign$s';
}

String _trim(double d) {
  final s = d.toStringAsFixed(d >= 100 ? 0 : 1).replaceAll('.', ',');
  return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
}

/// "5.000" / "5000" / "5k" / "1tr" → 5000. Trả null nếu không hợp lệ.
int? parseAmount(String input) {
  var s = input.trim().toLowerCase().replaceAll(' ', '');
  if (s.isEmpty) return null;
  var mul = 1;
  if (s.endsWith('k')) {
    mul = 1000;
    s = s.substring(0, s.length - 1);
  } else if (s.endsWith('tr')) {
    mul = 1000000;
    s = s.substring(0, s.length - 2);
  }
  s = s.replaceAll('đ', '');
  if (mul == 1) {
    s = s.replaceAll('.', '').replaceAll(',', '');
    return int.tryParse(s);
  }
  final d = double.tryParse(s.replaceAll(',', '.'));
  return d == null ? null : (d * mul).round();
}

String formatTime(DateTime d) => _time.format(d);
String formatDateTime(DateTime d) => _dateTime.format(d);
String formatFullDate(DateTime d) => _fullDate.format(d);

String formatBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}
