import 'package:flutter/material.dart';

/// Paleta y estilos de texto sacados literalmente de `home_screen.dart`
/// (la pantalla de gastos ya validada visualmente). Cualquier pantalla nueva
/// debe reusar estas constantes en vez de inventar su propia paleta o
/// depender del ColorScheme.fromSeed(Colors.red) de Material 3, que produce
/// tonos peach/navy que no coinciden con el diseño real de la app.
abstract final class AppColors {
  static const background = Color(0xfffaf9fd);
  static const cardBackground = Colors.white;
  static const border = Color(0xffdddddd);

  /// Acento principal (FAB, botones primarios).
  static const accent = Color(0xfff45b55);
  static const tabIndicator = Color(0xffef625d);

  /// Usado para todo lo que representa ingresos/activos en la app.
  static const income = Color(0xff3294c0);

  /// Usado para todo lo que representa gastos/deudas en la app.
  static const expense = Color(0xffd9796c);

  static const textPrimary = Color(0xff333333);
  static const textSecondary = Color(0xff888888);
  static const textMuted = Color(0xff9b9b9b);
}

abstract final class AppTextStyles {
  static const cardTitle = TextStyle(
    fontSize: 18,
    color: Color(0xff222222),
    fontWeight: FontWeight.w600,
  );
  static const label = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    fontWeight: FontWeight.w500,
  );
  static const amountLarge = TextStyle(
    fontSize: 28,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.bold,
  );
  static const amountMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.bold,
  );
}
