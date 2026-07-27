import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/core/financial_domain.dart';

void main() {
  group('financial movement semantics', () {
    test('classifies persisted labels and keeps legacy default', () {
      expect(classifyFinancialMovement('income'), FinancialMovementType.income);
      expect(
        classifyFinancialMovement('Ingreso'),
        FinancialMovementType.income,
      );
      expect(
        classifyFinancialMovement('Deposito bancario'),
        FinancialMovementType.income,
      );
      expect(
        classifyFinancialMovement('Transferencia bancaria'),
        FinancialMovementType.transfer,
      );
      expect(classifyFinancialMovement(null), FinancialMovementType.expense);
      expect(
        classifyFinancialMovement('compra'),
        FinancialMovementType.expense,
      );
    });

    test('type determines direction regardless of historical stored sign', () {
      expect(
        const FinancialMovement(
          amountCents: -1250,
          type: FinancialMovementType.income,
        ).balanceEffectCents,
        1250,
      );
      expect(
        const FinancialMovement(
          amountCents: 1250,
          type: FinancialMovementType.expense,
        ).balanceEffectCents,
        -1250,
      );
      expect(
        const FinancialMovement(
          amountCents: 1250,
          type: FinancialMovementType.transfer,
        ).balanceEffectCents,
        0,
      );
    });
  });

  group('financial summary', () {
    test('calculates income, expense and balance using cents only', () {
      final summary = summarizeFinancialMovements(const [
        FinancialMovement(
          amountCents: 1001,
          type: FinancialMovementType.income,
        ),
        FinancialMovement(amountCents: -1, type: FinancialMovementType.income),
        FinancialMovement(
          amountCents: 333,
          type: FinancialMovementType.expense,
        ),
      ]);

      expect(summary.incomeCents, 1002);
      expect(summary.expenseCents, 333);
      expect(summary.balanceCents, 669);
      expect(summary.isConsistent, isTrue);
      expect(summary.income, 10.02);
      expect(summary.expense, 3.33);
      expect(summary.balance, 6.69);
    });

    test('transfers are neutral and do not inflate totals', () {
      final summary = summarizeFinancialMovements(const [
        FinancialMovement(
          amountCents: 500000,
          type: FinancialMovementType.transfer,
        ),
      ]);

      expect(summary, const FinancialSummary.zero());
    });

    test('many fractional amounts do not accumulate decimal error', () {
      final summary = summarizeFinancialMovements(
        List.generate(
          10000,
          (_) => const FinancialMovement(
            amountCents: 1,
            type: FinancialMovementType.expense,
          ),
        ),
      );

      expect(summary.expenseCents, 10000);
      expect(summary.balanceCents, -10000);
      expect(summary.expense, 100);
    });
  });
}
