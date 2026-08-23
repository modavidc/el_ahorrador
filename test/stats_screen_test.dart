import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/screens/home_screen.dart';
import 'package:el_ahorrador/screens/stats_screen.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('Stats opens from the bottom navigation and shows empty state', (
    tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: HomeScreen(db: db)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.byType(StatsScreen), findsOneWidget);
    expect(find.text('No data available.'), findsOneWidget);
    expect(find.text('Monthly'), findsOneWidget);
  });
}
