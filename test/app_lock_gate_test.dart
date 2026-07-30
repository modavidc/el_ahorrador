import 'package:el_ahorrador/security/app_lock_gate.dart';
import 'package:el_ahorrador/security/local_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeAuthenticator implements LocalAuthenticator {
  _FakeAuthenticator(this.results);

  final List<LocalAuthenticationResult> results;
  int calls = 0;

  @override
  Future<LocalAuthenticationResult> authenticate() async {
    return results[calls++];
  }
}

void main() {
  testWidgets('hides content until authenticated and locks after background', (
    tester,
  ) async {
    final authenticator = _FakeAuthenticator([
      LocalAuthenticationResult.authenticated,
      LocalAuthenticationResult.authenticated,
    ]);
    final controller = AppLockController();

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticator: authenticator,
          controller: controller,
          child: const Text('financial data'),
        ),
      ),
    );
    expect(find.text('financial data'), findsNothing);
    expect(authenticator.calls, 0);
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('financial data'), findsOneWidget);

    controller.lock();
    await tester.pumpAndSettle();
    expect(find.text('financial data'), findsNothing);
    expect(find.text('El Ahorrador está bloqueado'), findsOneWidget);

    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('financial data'), findsOneWidget);
    expect(authenticator.calls, 2);
  });

  testWidgets(
    'does not bypass lock when device authentication is unavailable',
    (tester) async {
      final authenticator = _FakeAuthenticator([
        LocalAuthenticationResult.unavailable,
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            authenticator: authenticator,
            child: const Text('financial data'),
          ),
        ),
      );
      await tester.tap(find.text('Desbloquear'));
      await tester.pumpAndSettle();

      expect(find.text('financial data'), findsNothing);
      expect(find.textContaining('Configura una huella'), findsOneWidget);
      expect(find.text('Desbloquear'), findsOneWidget);
    },
  );

  testWidgets('brief share transition reuses the authenticated session', (
    tester,
  ) async {
    final authenticator = _FakeAuthenticator([
      LocalAuthenticationResult.authenticated,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticator: authenticator,
          gracePeriod: const Duration(minutes: 1),
          child: const Text('financial data'),
        ),
      ),
    );
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('financial data'), findsOneWidget);
    expect(authenticator.calls, 1);
  });

  testWidgets('default session covers a normal share round trip', (
    tester,
  ) async {
    final authenticator = _FakeAuthenticator([
      LocalAuthenticationResult.authenticated,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticator: authenticator,
          child: const Text('financial data'),
        ),
      ),
    );
    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('financial data'), findsOneWidget);
    expect(authenticator.calls, 1);
  });

  testWidgets('a failed attempt shows feedback and the button retries', (
    tester,
  ) async {
    final authenticator = _FakeAuthenticator([
      LocalAuthenticationResult.error,
      LocalAuthenticationResult.authenticated,
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: AppLockGate(
          authenticator: authenticator,
          child: const Text('financial data'),
        ),
      ),
    );

    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No se pudo abrir'), findsOneWidget);

    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('financial data'), findsOneWidget);
    expect(authenticator.calls, 2);
  });
}
