/// Một lần chuyển tiền: [from] trả [to] số [amount].
class Transfer {
  const Transfer(this.from, this.to, this.amount);
  final int from;
  final int to;
  final int amount;

  @override
  bool operator ==(Object other) =>
      other is Transfer &&
      other.from == from &&
      other.to == to &&
      other.amount == amount;

  @override
  int get hashCode => Object.hash(from, to, amount);

  @override
  String toString() => 'Transfer($from → $to: $amount)';
}

/// Gợi ý chuyển tiền cuối buổi: ghép người âm nhiều nhất với người dương nhiều nhất.
/// Số lần chuyển ≤ (số người − 1).
List<Transfer> settle(Map<int, int> totals) {
  final debtors = [
    for (final e in totals.entries)
      if (e.value < 0) [e.key, -e.value],
  ]..sort((a, b) => b[1].compareTo(a[1]));
  final creditors = [
    for (final e in totals.entries)
      if (e.value > 0) [e.key, e.value],
  ]..sort((a, b) => b[1].compareTo(a[1]));

  final result = <Transfer>[];
  var i = 0, j = 0;
  while (i < debtors.length && j < creditors.length) {
    final pay = debtors[i][1] < creditors[j][1]
        ? debtors[i][1]
        : creditors[j][1];
    result.add(Transfer(debtors[i][0], creditors[j][0], pay));
    debtors[i][1] -= pay;
    creditors[j][1] -= pay;
    if (debtors[i][1] == 0) i++;
    if (creditors[j][1] == 0) j++;
  }
  return result;
}
