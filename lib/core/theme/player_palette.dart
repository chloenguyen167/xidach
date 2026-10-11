import 'package:flutter/material.dart';

/// 10 màu người chơi dễ phân biệt, đủ tương phản ở cả nền sáng và tối.
/// Không dùng xanh lá để khỏi lẫn với màu chủ đạo / số dương.
abstract final class PlayerPalette {
  static const colors = <Color>[
    Color(0xFFE53935), // đỏ
    Color(0xFF1E88E5), // xanh dương
    Color(0xFFFB8C00), // cam
    Color(0xFF8E24AA), // tím
    Color(0xFF00897B), // xanh ngọc
    Color(0xFFD81B60), // hồng
    Color(0xFF6D4C41), // nâu
    Color(0xFF3949AB), // chàm
    Color(0xFFFDD835), // vàng
    Color(0xFF546E7A), // xám xanh
  ];

  static const names = [
    'Đỏ', 'Xanh dương', 'Cam', 'Tím', 'Xanh ngọc', //
    'Hồng', 'Nâu', 'Chàm', 'Vàng', 'Xám xanh',
  ];

  static Color of(int idx) => colors[idx % colors.length];

  /// Màu chữ trên nền màu người chơi.
  static Color onColor(int idx) =>
      of(idx).computeLuminance() > 0.45 ? Colors.black87 : Colors.white;

  /// Màu đầu tiên chưa ai dùng.
  static int nextFree(Iterable<int> used) {
    final set = used.toSet();
    for (var i = 0; i < colors.length; i++) {
      if (!set.contains(i)) return i;
    }
    return set.length % colors.length;
  }
}
