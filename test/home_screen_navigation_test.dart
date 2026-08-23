import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/screens/home_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();
  }

  testWidgets('cada tab muestra contenido explícito y conserva la selección', (
    tester,
  ) async {
    await pumpHome(tester);

    for (final entry in const [
      ('Calendar', 'calendar-view'),
      ('Monthly', 'monthly-view'),
      ('Total', 'total-view'),
    ]) {
      await tester.tap(find.text(entry.$1));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(entry.$2)), findsOneWidget);
    }

    for (final tab in ['Note']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('Próximamente'), findsOneWidget);
    }

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-view')), findsOneWidget);
  });

  testWidgets('cada destino inferior responde al toque', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coming-soon-Estadísticas')),
      findsOneWidget,
    );
    expect(find.text('Próximamente'), findsOneWidget);

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Configuración · Cuentas'), findsOneWidget);
    Navigator.of(tester.element(find.text('Configuración · Cuentas'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Configuration'), findsOneWidget);
    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();
    expect(find.text('Daily'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
