import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:el_ahorrador/theme/design_tokens.dart';
import 'package:el_ahorrador/ui/app_home.dart';

// Trans. shows the current month, so fixtures must be dated in it.
DateTime _thisMonth(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1, hour, minute);
}

Future<void> _pumpHome(WidgetTester tester, AppDatabase db) async {
  await tester.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildDesignTheme(),
      home: AppHome(db: db),
    ),
  );
  await tester.pumpAndSettle();
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

    // Older manual entries stored the category name in vendor and left both
    // category IDs null.
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
    await _pumpHome(tester, db);

    expect(tester.takeException(), isNull);
    expect(find.text('Gasto manual de prueba'), findsOneWidget);
    expect(find.textContaining('Comida · Efectivo'), findsOneWidget);
    expect(find.text('S/. 5.00'), findsWidgets);
    await _unmount(tester);
  });

  testWidgets('renders the expense after reopening its database', (
    tester,
  ) async {
    // Real file I/O must run outside the fake-async zone of testWidgets.
    final tempDirectory = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('ui_reopen_'),
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
    await _pumpHome(tester, db);

    expect(find.text('Gasto después del reinicio'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
    await tester.runAsync(db.close);
  });

  testWidgets('edits and deletes the same movement from Trans.', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertExpenseFromParser(
      id: 'manual-edit-delete',
      dateEpochMs: DateTime.now().millisecondsSinceEpoch,
      amountCents: -500,
      currency: 'PEN',
      accountId: AppDatabase.defaultAccountId,
      vendor: 'Comida',
      description: 'Gasto original',
      sourceApp: 'Manual',
    );
    await _pumpHome(tester, db);

    await tester.tap(find.text('Gasto original'));
    await tester.pumpAndSettle();
    expect(find.text('Editar transacción'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Gasto original'),
      'Gasto editado',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final edited = await db.select(db.expenses).getSingle();
    expect(edited.id, 'manual-edit-delete');
    expect(edited.description, 'Gasto editado');
    expect(edited.amountCents, -500);
    expect(find.text('Gasto editado'), findsOneWidget);

    await tester.tap(find.text('Gasto editado'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Eliminar transacción'));
    await tester.pumpAndSettle();

    expect(await db.select(db.expenses).get(), isEmpty);
    expect(find.text('Gasto editado'), findsNothing);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });

  testWidgets('the FAB opens Añadir manual and saves a new expense', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpHome(tester, db);

    await tester.tap(find.bySemanticsLabel('Añadir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir manual'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva transacción'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'ej. rappi pizza 42 soles con la visa'),
      'almuerzo 18.50 con yape',
    );
    await tester.tap(find.text('Interpretar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.expenses).getSingle();
    expect(saved.amountCents, -1850);
    expect(saved.sourceApp, 'Yape');
    expect(saved.description, 'Almuerzo');
    expect(find.text('Almuerzo'), findsOneWidget);
    expect(find.text('Yape'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('editing a captured expense keeps its capture and merchant', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertCapture(id: 'cap-1', imagePath: '/x.eac', hash: 'h1');
    await db.setOcrResult(id: 'cap-1', text: 'Yape', confidence: '91');
    await db.insertExpenseFromParser(
      id: 'captured',
      captureId: 'cap-1',
      dateEpochMs: DateTime.now().millisecondsSinceEpoch,
      amountCents: -1200,
      currency: 'PEN',
      accountId: AppDatabase.defaultAccountId,
      vendor: 'Bodega Don Pepe',
      sourceApp: 'Yape',
    );
    await _pumpHome(tester, db);
    expect(find.text('OCR 91%'), findsOneWidget);

    await tester.tap(find.text('Bodega Don Pepe'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Bodega Don Pepe'),
      'Pan y leche',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final edited = await db.select(db.expenses).getSingle();
    expect(edited.captureId, 'cap-1');
    expect(edited.vendor, 'Bodega Don Pepe');
    expect(edited.sourceApp, 'Yape');
    expect(edited.description, 'Pan y leche');
    expect(find.text('OCR 91%'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('a transfer can be created and edited from the form', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: 'savings',
            name: 'Ahorros',
            order: 1,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db.insertTransfer(
      id: 'tr-1',
      dateEpochMs: DateTime.now().millisecondsSinceEpoch,
      amountCents: 10000,
      currency: 'PEN',
      sourceAccountId: AppDatabase.defaultAccountId,
      destinationAccountId: 'savings',
      description: 'Ahorro',
    );
    await _pumpHome(tester, db);

    await tester.tap(find.text('Ahorro'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, '100.00'), '150');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.expenses).get();
    expect(rows.map((r) => r.amountCents).toSet(), {-15000, 15000});
    expect(rows.every((r) => r.origination == 'tr-1'), isTrue);
    await _unmount(tester);
  });
}
