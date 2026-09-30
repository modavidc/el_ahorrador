import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/app/home/app_home.dart';
import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

import 'support/capture_fakes.dart';

/// Onboarding, Escanear boleta and Dictar from the app shell.
void main() {
  late AppDatabase db;
  late AppDependencies dependencies;

  setUp(() async {
    AppClock.pin(DateTime(2026, 9, 27, 10));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AccountRepository(
      db,
    ).create(name: 'Yape', groupId: AppDatabase.defaultAccountGroupId);
    dependencies = fakeDependencies(db);
  });
  tearDown(() async {
    AppClock.reset();
    dependencies.dispose();
    await db.close();
  });

  /// The database needs real time while the screens need frames.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  Future<void> pumpHome(WidgetTester tester, {bool welcome = false}) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(),
        home: AppHome(dependencies: dependencies, welcomeOnFirstRun: welcome),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> openFab(WidgetTester tester, String action) async {
    await tester.tap(find.byKey(const ValueKey('fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(action));
    await settle(tester);
  }

  Future<List<Movement>> movements(WidgetTester tester) async => (await tester
      .runAsync(() => dependencies.ledger.watchMovements().first))!;

  testWidgets('the first run shows the welcome and saves the budget', (
    tester,
  ) async {
    await pumpHome(tester, welcome: true);
    expect(find.text('Tu plata,\nen orden.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuánto quieres gastar al mes?'), findsOneWidget);
    await tester.tap(find.text('S/ 3,000'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Registra sin escribir'), findsOneWidget);

    await tester.tap(find.text('Ahora no'));
    await settle(tester);
    expect(find.text('Registra sin escribir'), findsNothing);
    expect(
      await tester.runAsync(
        () => dependencies.ledger.watchMonthlyBudget().first,
      ),
      300000,
    );
    expect(
      await tester.runAsync(
        () => dependencies.preferences.get(Preference.onboardingDone),
      ),
      isTrue,
    );
    await unmount(tester);
  });

  testWidgets('the welcome is not shown again', (tester) async {
    await tester.runAsync(
      () => dependencies.preferences.set(Preference.onboardingDone, true),
    );
    await pumpHome(tester, welcome: true);
    expect(find.text('Tu plata,\nen orden.'), findsNothing);
    expect(find.text('Movimientos'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('Escanear boleta reads the ticket and saves it', (tester) async {
    await pumpHome(tester);
    await openFab(tester, 'Escanear boleta');

    expect(find.text('Plaza Vea'), findsOneWidget);
    expect(find.text('S/ 99.50'), findsOneWidget);
    expect(find.text('Lectura 97%'), findsOneWidget);

    await tester.tap(find.text('Comida'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('scan-save')));
    await tester.tap(find.byKey(const ValueKey('scan-save')));
    await settle(tester);

    final saved = (await movements(tester)).single;
    expect(saved.note, 'Plaza Vea');
    expect(saved.category, 'Comida');
    expect(saved.origin, MovementOrigin.receipt);
    expect(find.text('Registrado · Plaza Vea S/ 99.50'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Dictar turns a sentence into a movement', (tester) async {
    await pumpHome(tester);
    await openFab(tester, 'Dictar');

    expect(find.text('“almuerzo 18 soles con yape”'), findsOneWidget);
    expect(find.text('S/ 18.00'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('dictate-save')));
    await tester.tap(find.byKey(const ValueKey('dictate-save')));
    await settle(tester);

    final saved = (await movements(tester)).single;
    expect(saved.amountCents, 1800);
    expect(saved.category, 'Comida');
    expect(saved.account, 'Yape');
    expect(saved.origin, MovementOrigin.voice);
    expect(find.text('Gasto de S/ 18.00 registrado'), findsOneWidget);
    await unmount(tester);
  });
}
