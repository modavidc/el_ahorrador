import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/app/home/app_home.dart';

import 'support/capture_fakes.dart';

void main() {
  late AppDatabase db;
  late AppDependencies dependencies;
  late CaptureController capture;

  setUp(() async {
    AppClock.pin(DateTime(2026, 9, 27, 10));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AccountRepository(
      db,
    ).create(name: 'Yape', groupId: AppDatabase.defaultAccountGroupId);
    dependencies = fakeDependencies(db);
    capture = dependencies.capture;
  });
  tearDown(() async {
    AppClock.reset();
    dependencies.dispose();
    await db.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(),
        home: AppHome(dependencies: dependencies),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  /// Shares images and lets the reading finish; the database needs real
  /// time while the sheet needs frames.
  Future<void> share(WidgetTester tester, List<String> paths) async {
    var finished = false;
    capture.start(paths).whenComplete(() => finished = true);
    for (var i = 0; i < 200 && !finished; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(finished, isTrue);
    await tester.pumpAndSettle();
  }

  testWidgets('sharing a Yape shows Registrado and can be undone', (
    tester,
  ) async {
    await pumpHome(tester);
    await share(tester, ['sent']);

    expect(find.text('Registrado'), findsOneWidget);
    expect(find.text('Yapeaste a Bodega Don Lucho'), findsWidgets);
    expect(find.text('Lectura 97%'), findsOneWidget);
    expect(find.text('Regla “Yapeaste” → Gasto · Yape'), findsOneWidget);

    await tester.tap(find.text('Deshacer').last);
    await tester.pumpAndSettle();
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(find.text('Registro deshecho'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('Listo keeps the movement with its Registrado pill', (
    tester,
  ) async {
    await pumpHome(tester);
    await share(tester, ['received']);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(find.text('Te yapearon · Juan Pérez'), findsOneWidget);
    expect(find.text('Registrado ·'), findsOneWidget);
    expect(find.text('+S/ 450.00'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('several images: summary, Por revisar and approval', (
    tester,
  ) async {
    await pumpHome(tester);
    await share(tester, ['sent', 'person', 'selfie', 'sent#copy']);

    expect(find.text('4 imágenes procesadas'), findsOneWidget);
    expect(
      find.text('1 registrado · 1 por revisar · 1 duplicado · 1 con error'),
      findsOneWidget,
    );
    expect(find.text('No es un comprobante'), findsOneWidget);
    expect(find.text('Duplicado · omitido'), findsOneWidget);

    await tester.tap(find.text('Ver Por revisar'));
    await tester.pumpAndSettle();
    expect(find.text('Yapeaste a Rosa Quispe M.'), findsOneWidget);
    expect(find.text('Falta la categoría'), findsWidgets);

    await tester.tap(find.text('Otros'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aprobar'));
    await tester.pumpAndSettle();
    expect(find.text('Todo al día'), findsOneWidget);
    expect(await db.select(db.expenses).get(), hasLength(2));
    await unmount(tester);
  });

  testWidgets('Movimientos shows the Por revisar notice', (tester) async {
    await tester.runAsync(() => capture.service.process('blurry'));
    await pumpHome(tester);
    expect(find.text('1 pago necesita un dato'), findsOneWidget);

    // Second card of the carousel, after "Prueba la función principal".
    await tester.drag(
      find.text('Prueba la función principal'),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    expect(find.text('No se leyó el monto'), findsWidgets);
    expect(find.text('Falta el monto'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('rules change from Ajustes', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Funciones de captura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reglas de captura'));
    await tester.pumpAndSettle();
    expect(find.text('4 activas'), findsOneWidget);

    await tester.tap(find.text('Automática (IA)').first);
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('the letter of a category changes from Ajustes', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();
    final categories = find.text('Categorías');
    await tester.ensureVisible(categories);
    await tester.pumpAndSettle();
    await tester.tap(categories);
    await tester.pumpAndSettle();
    final letters = find.text('LETRAS');
    await tester.scrollUntilVisible(
      letters,
      200,
      scrollable: find
          .ancestor(
            of: find.text('Comida').first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    // Transporte is in Gastos and again under Letras, with its "T".
    final transporte = find.text('Transporte').last;
    await tester.ensureVisible(transporte);
    await tester.tap(transporte);
    await tester.pumpAndSettle();
    expect(find.text('Letra de Transporte'), findsOneWidget);

    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    final stored = (await tester.runAsync(
      () => dependencies.ledger.watchCategoryLetters().first,
    ))!;
    expect(stored.letterOf(Category.transporte), 'B');
    expect(stored['T'], isNull);
    expect(find.text('B'), findsOneWidget);
    await unmount(tester);
  });
}
