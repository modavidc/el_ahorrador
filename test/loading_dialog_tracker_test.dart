import 'package:el_ahorrador/widgets/loading_dialog_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dismiss without an owned dialog keeps the home route', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final tracker = LoadingDialogTracker();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home route')),
      ),
    );

    tracker.dismiss(navigatorKey.currentContext!);
    await tester.pumpAndSettle();

    expect(find.text('home route'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('owned fallback dialog is dismissed only once', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final tracker = LoadingDialogTracker();

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('home route')),
      ),
    );
    final context = navigatorKey.currentContext!;

    tracker.show(
      () => showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('processing')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('processing'), findsOneWidget);

    expect(tracker.dismiss(context), isTrue);
    expect(tracker.dismiss(context), isFalse);
    await tester.pumpAndSettle();

    expect(find.text('home route'), findsOneWidget);
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });
}
