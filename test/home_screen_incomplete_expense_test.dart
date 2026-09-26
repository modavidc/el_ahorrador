import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:el_ahorrador/screens/home_screen.dart';

// Home shows the current month, so fixtures must be dated in it.
DateTime _thisMonth(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1, hour, minute);
}

// Unmount the tree so drift stream subscriptions are cancelled before the
// database closes; otherwise their cleanup timers keep the test pending.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 1));
}

void main() {
  testWidgets('renders a manual S/ 5 expense with nullable category fields', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // This matches the values persisted by AddTransactionScreen: the selected
    // category is stored in vendor while both category IDs remain null.
    await db.insertExpenseFromParser(
      id: 'manual-five-soles',
      dateEpochMs: _thisMonth(10, 30).millisecondsSinceEpoch,
      amountCents: -500,
      currency: 'S/.',
      account: 'Efectivo',
      vendor: 'Comida',
      description: 'Gasto manual de prueba',
      sourceApp: 'Manual',
    );
    await db.insertExpenseFromParser(
      id: 'another-expense',
      dateEpochMs: _thisMonth(11).millisecondsSinceEpoch,
      amountCents: -1200,
      currency: 'S/.',
      account: 'Efectivo',
      vendor: 'Transporte',
      description: 'Segundo gasto',
      sourceApp: 'Manual',
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Gasto manual de prueba'), findsOneWidget);
    expect(find.text('Segundo gasto'), findsOneWidget);
    // Daily rows show the absolute amount; the red color marks the expense.
    expect(find.text('S/. 5.00'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('renders the incomplete expense after reopening its database', (
    tester,
  ) async {
    // Real file I/O must run outside the fake-async zone of testWidgets.
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('mob003_'),
    ))!;
    final databaseFile = File('${tempDirectory.path}/expenses.sqlite');
    var db = AppDatabase.forTesting(NativeDatabase(databaseFile));
    await tester.runAsync(() async {
      await db.insertExpenseFromParser(
        id: 'persisted-manual-expense',
        dateEpochMs: _thisMonth(10, 30).millisecondsSinceEpoch,
        amountCents: -500,
        currency: 'S/.',
        account: 'Efectivo',
        vendor: 'Comida',
        description: 'Gasto después del reinicio',
        sourceApp: 'Manual',
      );
      await db.close();
    });

    db = AppDatabase.forTesting(NativeDatabase(databaseFile));
    addTearDown(() => tempDirectory.delete(recursive: true));
    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();

    expect(find.text('Gasto después del reinicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
    await tester.runAsync(db.close);
  });

  testWidgets('edits and deletes the same incomplete manual expense', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertExpenseFromParser(
      id: 'manual-edit-delete',
      dateEpochMs: DateTime.now().millisecondsSinceEpoch,
      amountCents: -500,
      currency: 'S/.',
      account: 'Efectivo',
      vendor: 'Comida',
      description: 'Gasto original',
      sourceApp: 'Manual',
    );

    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gasto original'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar transacción'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Descripción'),
      'Gasto editado',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    final edited = await db.select(db.expenses).getSingle();
    expect(edited.id, 'manual-edit-delete');
    expect(edited.description, 'Gasto editado');
    expect(edited.categoryId, isNull);
    expect(edited.subcategoryId, isNull);

    await tester.tap(find.byTooltip('Eliminar transacción'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await tester.pumpAndSettle();

    expect(await db.select(db.expenses).get(), isEmpty);
    expect(find.text('Gasto editado'), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
}
