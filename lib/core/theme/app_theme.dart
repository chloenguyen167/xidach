import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const brand = Color(0xFF33A13F);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    var scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: b,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    if (b == Brightness.light) {
      scheme = scheme.copyWith(primary: brand, onPrimary: Colors.white);
    }
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(centerTitle: false),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      chipTheme: const ChipThemeData(showCheckmark: false),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}

/// Màu cho số dương/âm (luôn kèm dấu +/− nên không phụ thuộc chỉ vào màu).
extension ScoreColors on ColorScheme {
  Color get positive => brightness == Brightness.light
      ? const Color(0xFF1B7A2B)
      : const Color(0xFF7DD88A);
  Color get negative => error;

  Color scoreColor(int v) =>
      v > 0 ? positive : (v < 0 ? negative : onSurfaceVariant);

  /// Màu vàng cho mọi thứ liên quan nhà cái (vương miện, ô của cái).
  Color get dealer => brightness == Brightness.light
      ? const Color(0xFFE0A100)
      : const Color(0xFFFFC94D);
  Color get onDealer => const Color(0xFF3A2A00);
  Color get dealerTint => dealer.withValues(alpha: 0.16);
}
