import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:el_ahorrador/screens/home_screen.dart';

void main() {
  testWidgets('renders a manual S/ 5 expense with nullable category fields',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // This matches the values persisted by AddTransactionScreen: the selected
    // category is stored in vendor while both category IDs remain null.
    await db.insertExpenseFromParser(
      id: 'manual-five-soles',
      dateEpochMs: DateTime(2026, 7, 27, 10, 30).millisecondsSinceEpoch,
      amountCents: -500,
      currency: 'S/.',
      account: 'Efectivo',
      vendor: 'Comida',
      description: 'Gasto manual de prueba',
      sourceApp: 'Manual',
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gasto manual de prueba'), findsOneWidget);
    expect(find.text('S/. -5.00'), findsWidgets);
  });
}
