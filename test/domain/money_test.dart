import 'package:flutter_test/flutter_test.dart';
import 'package:xidach/core/format/money.dart';

void main() {
  test('format', () {
    expect(formatAmount(10000, money: true), '10.000đ');
    expect(formatDelta(-5000, money: true), '−5.000đ');
    expect(formatDelta(12, money: false), '+12');
    expect(formatCompact(1500000, money: true), '+1,5tr');
    expect(formatCompact(-20000, money: true), '−20k');
    expect(formatCompact(5000, money: true, signed: false), '5k');
  });

  test('parse', () {
    expect(parseAmount('10.000'), 10000);
    expect(parseAmount('5k'), 5000);
    expect(parseAmount('1,5tr'), 1500000);
    expect(parseAmount('20000đ'), 20000);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
  });
}
