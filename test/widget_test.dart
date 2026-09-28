// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:el_ahorrador/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SolitoApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    // The fingerprint lock is off until the user enables it in Ajustes.
    expect(find.textContaining('bloqueado'), findsNothing);

    // Let drift cancel its stream queries before the test binding checks for
    // pending timers.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
