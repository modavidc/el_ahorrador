import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/app_clock.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:el_ahorrador/theme/design_tokens.dart';
import 'package:el_ahorrador/ui/app_home.dart';

// Movimientos shows the current month, so fixtures must be dated in it.
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
  // Mornings: the "Aún no registras nada hoy" notice only shows from 20:00.
  setUp(() {
    final now = DateTime.now();
    AppClock.pin(DateTime(now.year, now.month, now.day, 10));
  });
  tearDown(AppClock.reset);

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
    expect(find.text('\u2212S/ 5.00'), findsWidgets);
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

  testWidgets('the detail sheet changes the category, deletes and undoes', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertExpenseFromParser(
      id: 'manual-detail',
      dateEpochMs: DateTime.now().millisecondsSinceEpoch,
      amountCents: -500,
      currency: 'PEN',
      accountId: AppDatabase.defaultAccountId,
      vendor: 'Comida',
      description: 'Pan',
      sourceApp: 'Manual',
    );
    await _pumpHome(tester, db);

    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mercado'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mercado · Efectivo'), findsOneWidget);

    await tester.tap(find.text('Pan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(find.text('Movimiento eliminado'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();
    final restored = await db.select(db.expenses).getSingle();
    expect(restored.id, 'manual-detail');
    expect(find.text('Pan'), findsOneWidget);
    await _unmount(tester);
  });

  testWidgets('+ → Manual registers with the keypad and can be undone', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await _pumpHome(tester, db);

    await tester.tap(find.byKey(const ValueKey('fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe el monto'), findsOneWidget);

    for (final key in ['1', '8', '.', '5', '0', '9']) {
      final button = find.byKey(ValueKey('keypad-$key'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
    await tester.tap(find.text('Guardar S/ 18.50'));
    await tester.pumpAndSettle();

    final saved = await db.select(db.expenses).getSingle();
    expect(saved.amountCents, -1850);
    expect(saved.sourceApp, 'Manual');
    expect(find.text('Gasto de S/ 18.50 registrado'), findsOneWidget);
    expect(find.text('Registrado ·'), findsOneWidget);

    // The pill of the new row undoes it.
    await tester.tap(find.text('Deshacer').last);
    await tester.pumpAndSettle();
    expect(await db.select(db.expenses).get(), isEmpty);
    await _unmount(tester);
  });

  testWidgets('a captured expense shows where it came from', (tester) async {
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
    expect(find.text('Bodega Don Pepe'), findsOneWidget);
    expect(find.text('Compartido'), findsOneWidget);
    // Sharing was used, so the "Prueba la función principal" notice is gone.
    expect(find.text('Prueba la función principal'), findsNothing);
    await _unmount(tester);
  });

  testWidgets('a transfer moves money between two accounts', (tester) async {
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
    await _pumpHome(tester, db);

    await tester.tap(find.byKey(const ValueKey('fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transferencia'));
    await tester.pumpAndSettle();
    for (final key in ['1', '0', '0']) {
      final button = find.byKey(ValueKey('keypad-$key'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    }
    // DESDE Efectivo, then HACIA Ahorros (the only other account).
    for (final chip in [
      find.text('Efectivo').first,
      find.text('Ahorros').last,
    ]) {
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Guardar S/ 100.00'));
    await tester.pumpAndSettle();

    final rows = await db.select(db.expenses).get();
    expect(rows.map((r) => r.amountCents).toSet(), {-10000, 10000});
    expect(find.text('Efectivo → Ahorros'), findsOneWidget);
    await _unmount(tester);
  });
}
