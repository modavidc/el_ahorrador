import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/app_clock.dart';
import 'package:el_ahorrador/data/account_repository.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/features/capture/capture_controller.dart';
import 'package:el_ahorrador/features/capture/capture_service.dart';
import 'package:el_ahorrador/theme/design_tokens.dart';
import 'package:el_ahorrador/ui/app_home.dart';

import 'support/capture_fakes.dart';

void main() {
  late AppDatabase db;
  late CaptureController capture;

  setUp(() async {
    AppClock.pin(DateTime(2026, 9, 27, 10));
    db = AppDatabase.forTesting(NativeDatabase.memory());
    await AccountRepository(
      db,
    ).create(name: 'Yape', groupId: AppDatabase.defaultAccountGroupId);
    capture = CaptureController(
      CaptureService(
        db: db,
        ocr: FakeOcr(),
        storage: FakeStorage(),
        now: AppClock.now,
      ),
    );
  });
  tearDown(() async {
    AppClock.reset();
    capture.dispose();
    await db.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(),
        home: AppHome(db: db, capture: capture),
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
    await tester.tap(find.text('Reglas de captura'));
    await tester.pumpAndSettle();
    expect(find.text('4 activas'), findsOneWidget);

    await tester.tap(find.text('Automática (IA)').first);
    await tester.pumpAndSettle();
    expect(find.text('Comida'), findsWidgets);
    await unmount(tester);
  });
}
