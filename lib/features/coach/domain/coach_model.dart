import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// Ajustes → Personalizar Coach → Modelo de IA: a language model reached
/// with the user's own key. The key lives in the device's secure storage,
/// never in the app package.
abstract interface class CoachModelAccess {
  Future<bool> isConnected();

  /// Checks the key against the provider and keeps it.
  ///
  /// Throws [CoachModelException] when the provider rejects it.
  Future<void> connect(String apiKey);

  Future<void> disconnect();
}

final class CoachModelException implements Exception {
  const CoachModelException(this.message);

  /// Shown to the user as is.
  final String message;

  @override
  String toString() => message;
}

/// The only data a language model receives: totals of the month, never
/// movements, notes, accounts or receipts.
String coachBrief(CoachContext c) {
  final m = c.month;
  String money(int cents) => Fmt.money(cents / 100);
  String categories(List<(Category, int)> totals) => totals.isEmpty
      ? 'sin gastos'
      : totals.map((e) => '${e.$1.label} ${money(e.$2)}').join(', ');
  final previous = <Category, int>{};
  for (final e in c.previous.movements) {
    if (e.type != MovementType.expense) continue;
    previous.update(
      Category.of(e.category),
      (t) => t + e.amountCents,
      ifAbsent: () => e.amountCents,
    );
  }
  final previousRanked = [for (final e in previous.entries) (e.key, e.value)]
    ..sort((a, b) => b.$2.compareTo(a.$2));
  return [
    'Hoy es ${c.today.day} de ${c.monthName}; quedan ${m.daysLeft} días del mes.',
    'Presupuesto mensual: ${money(c.budgetCents)}.',
    'Gastado este mes: ${money(m.spentCents)} (${m.spentPercent}% del presupuesto).',
    'Ingresos este mes: ${money(m.incomeCents)}.',
    'Queda: ${money(m.leftCents)}; ${Fmt.money(m.perDay)} por día hasta fin de mes.',
    'Promedio diario gastado: ${money(c.today.day == 0 ? 0 : (m.spentCents / c.today.day).round())}.',
    'Gastos por categoría este mes: ${categories(c.byCategory)}.',
    'Gastos de ${c.previousName}: ${money(c.previous.spentCents)}; '
        'por categoría: ${categories(previousRanked)}.',
    'Pagos registrados solos por captura este mes: ${c.captured}.',
  ].join('\n');
}
