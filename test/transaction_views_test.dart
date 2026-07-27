import 'package:el_ahorrador/screens/transaction_views.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('clasificación de movimientos', () {
    test('reconoce valores guardados por el formulario manual', () {
      expect(classifyOrigination('income'), LedgerEntryKind.income);
      expect(classifyOrigination('expense'), LedgerEntryKind.expense);
      expect(classifyOrigination('transfer'), LedgerEntryKind.transfer);
    });

    test('acepta etiquetas en español y variantes de importación', () {
      expect(classifyOrigination('Ingreso'), LedgerEntryKind.income);
      expect(classifyOrigination('Depósito bancario'), LedgerEntryKind.income);
      expect(
        classifyOrigination('Transferencia bancaria'),
        LedgerEntryKind.transfer,
      );
      expect(classifyOrigination(null), LedgerEntryKind.expense);
    });
  });

  test('el filtro mensual respeta año y mes', () {
    final july = DateTime(2026, 7);
    expect(
      isInMonth(DateTime(2026, 7, 1).millisecondsSinceEpoch, july),
      isTrue,
    );
    expect(
      isInMonth(DateTime(2026, 7, 31, 23, 59).millisecondsSinceEpoch, july),
      isTrue,
    );
    expect(
      isInMonth(DateTime(2026, 6, 30).millisecondsSinceEpoch, july),
      isFalse,
    );
    expect(
      isInMonth(DateTime(2025, 7, 1).millisecondsSinceEpoch, july),
      isFalse,
    );
  });
}
