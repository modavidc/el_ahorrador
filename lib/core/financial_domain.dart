/// Financial movement semantics used by every aggregate in the application.
enum FinancialMovementType { income, expense, transfer }

/// Classifies persisted/imported labels without making UI code interpret money.
///
/// Unknown and empty values are expenses for backwards compatibility with the
/// original database, where every captured receipt was an expense.
FinancialMovementType classifyFinancialMovement(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  if (normalized == 'income' ||
      normalized == 'ingreso' ||
      normalized.contains('deposit')) {
    return FinancialMovementType.income;
  }
  if (normalized == 'transfer' || normalized.contains('transferencia')) {
    return FinancialMovementType.transfer;
  }
  return FinancialMovementType.expense;
}

/// Minimal, integer-only input to financial calculations.
final class FinancialMovement {
  const FinancialMovement({required this.amountCents, required this.type});

  /// Magnitude as persisted. Its historical sign is deliberately ignored:
  /// [type] is the sole source of truth for financial direction.
  final int amountCents;
  final FinancialMovementType type;

  int get magnitudeCents => amountCents.abs();

  /// Income adds to the balance, expense subtracts and transfer is neutral.
  int get balanceEffectCents => switch (type) {
    FinancialMovementType.income => magnitudeCents,
    FinancialMovementType.expense => -magnitudeCents,
    FinancialMovementType.transfer => 0,
  };
}

/// Exact aggregate. Conversion to decimal belongs only at the presentation
/// boundary, after all arithmetic has finished in integer cents.
final class FinancialSummary {
  const FinancialSummary({
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceCents,
  });

  const FinancialSummary.zero()
    : incomeCents = 0,
      expenseCents = 0,
      balanceCents = 0;

  final int incomeCents;
  final int expenseCents;
  final int balanceCents;

  bool get isConsistent => balanceCents == incomeCents - expenseCents;

  double get income => incomeCents / 100;
  double get expense => expenseCents / 100;
  double get balance => balanceCents / 100;

  @override
  bool operator ==(Object other) =>
      other is FinancialSummary &&
      incomeCents == other.incomeCents &&
      expenseCents == other.expenseCents &&
      balanceCents == other.balanceCents;

  @override
  int get hashCode => Object.hash(incomeCents, expenseCents, balanceCents);
}

FinancialSummary summarizeFinancialMovements(
  Iterable<FinancialMovement> movements,
) {
  var incomeCents = 0;
  var expenseCents = 0;

  for (final movement in movements) {
    switch (movement.type) {
      case FinancialMovementType.income:
        incomeCents += movement.magnitudeCents;
      case FinancialMovementType.expense:
        expenseCents += movement.magnitudeCents;
      case FinancialMovementType.transfer:
        break;
    }
  }

  return FinancialSummary(
    incomeCents: incomeCents,
    expenseCents: expenseCents,
    balanceCents: incomeCents - expenseCents,
  );
}
