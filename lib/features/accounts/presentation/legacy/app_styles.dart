import 'package:flutter/material.dart';

/// Mismo texto en toda la app para cualquier acción todavía no
/// implementada — un solo SnackBar reusable, nunca un mensaje inventado
/// por pantalla.
const comingSoonSnackBar = SnackBar(content: Text('Próximamente'));

/// Paleta y estilos de texto sacados literalmente de `home_screen.dart`
/// (la pantalla de gastos ya validada visualmente). Cualquier pantalla nueva
/// debe reusar estas constantes en vez de inventar su propia paleta o
/// depender del ColorScheme.fromSeed(Colors.red) de Material 3, que produce
/// tonos peach/navy que no coinciden con el diseño real de la app.
abstract final class AppColors {
  static const background = Color(0xfffaf9fd);
  static const cardBackground = Colors.white;
  static const border = Color(0xffdddddd);

  /// Banda de encabezado de grupo en listas planas (ej. Cuentas agrupadas).
  static const groupBand = Color(0xfff2f2f5);

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

  /// Gris de las etiquetas (Income/Expenses/Total, PEN, etc.) en
  /// home_screen.dart — más oscuro que textSecondary, no confundir.
  static const textCaption = Color(0xff4d4d4d);
}

/// Tamaños y pesos sacados literalmente de home_screen.dart: label de
/// _buildSummaryItem (fontSize 12, w400 implícito) y montos de fila
/// (_buildDayHeader / _buildDailyTransactionItem, fontSize 15, w400 — NO
/// bold). Antes esta clase tenía valores inventados (13/17 bold) que no
/// coincidían con la pantalla principal; de ahí el desajuste reportado.
abstract final class AppTextStyles {
  static const cardTitle = TextStyle(
    fontSize: 18,
    color: Color(0xff222222),
    fontWeight: FontWeight.w600,
  );

  /// Etiqueta chica sobre un monto (Assets/Liabilities/Total, PEN...).
  static const label = TextStyle(fontSize: 12, color: AppColors.textCaption);

  static const amountLarge = TextStyle(
    fontSize: 28,
    color: AppColors.textPrimary,
    fontWeight: FontWeight.bold,
  );

  /// Monto de fila (listas, filas de cuenta) — home_screen.dart nunca usa
  /// bold acá, solo color para distinguir ingreso/gasto.
  static const amountMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );

  /// Igual a _buildSummaryItem de home_screen.dart (Income/Expenses/Total).
  static const summaryValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
}
