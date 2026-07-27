import 'package:el_ahorrador/models/transaction.dart';
import 'package:el_ahorrador/widgets/transaction_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transaction item exposes amount semantics at 200% text scale', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final transaction = Transaction(
      id: 'expense-1',
      date: DateTime(2026, 7, 24, 10, 30),
      type: TransactionType.expense,
      category: 'alimentacion',
      subcategory: 'almuerzo',
      description: 'Mercado local',
      account: 'Cuenta principal',
      amount: 42.50,
      currency: 'PEN',
      icon: Icons.restaurant,
      color: Colors.red,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: TransactionItem(transaction: transaction)),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'expense, S/\. 42\.50')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('OCR action has an accessible label and 48px target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final transaction = Transaction(
      id: 'ocr-1',
      date: DateTime(2026, 7, 24),
      type: TransactionType.expense,
      category: 'compras',
      subcategory: '',
      description: 'Compra OCR',
      account: 'Efectivo',
      amount: 10,
      currency: 'PEN',
      notes: 'ocr',
      icon: Icons.receipt,
      color: Colors.red,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TransactionItem(transaction: transaction)),
      ),
    );

    expect(find.bySemanticsLabel(RegExp('Ver captura OCR')), findsOneWidget);
    final target = tester.getSize(
      find.bySemanticsLabel(RegExp('Ver captura OCR')),
    );
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });
}
