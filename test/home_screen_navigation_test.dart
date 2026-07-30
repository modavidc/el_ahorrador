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

    for (final tab in ['Calendario', 'Mensual', 'Total', 'Nota']) {
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
      expect(find.text('Próximamente'), findsOneWidget);
    }

    await tester.tap(find.text('Calendario'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Estad.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('coming-soon-Calendario')),
      findsOneWidget,
    );
  });

  testWidgets('cada destino inferior responde al toque', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Estad.'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('coming-soon-Estadísticas')),
      findsOneWidget,
    );
    expect(find.text('Próximamente'), findsOneWidget);

    for (final destination in ['Cuentas', 'Más']) {
      await tester.tap(find.text(destination));
      await tester.pumpAndSettle();
      expect(find.text('Configuración · Cuentas'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();
    expect(find.text('Diario'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
