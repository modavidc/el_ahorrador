import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/screens/account_settings_screen.dart';
import 'package:el_ahorrador/screens/home_screen.dart';
import 'package:el_ahorrador/screens/settings_screen.dart';
import 'package:el_ahorrador/screens/stats_screen.dart';

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

  // Unmount so drift stream subscriptions are cancelled before tearDown
  // closes the database; otherwise their cleanup timers stay pending.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
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
      await tester.tap(
        find.descendant(of: find.byType(TabBar), matching: find.text(entry.$1)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey(entry.$2)), findsOneWidget);
    }

    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coming-soon-Notas')), findsOneWidget);

    // Switching to another bottom tab and back keeps the selected tab.
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('calendar-view')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('cada destino inferior responde al toque', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();
    expect(find.byType(StatsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(StatsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountsTabBody), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trans.'));
    await tester.pumpAndSettle();
    expect(find.text('Daily'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    await unmount(tester);
  });
}
