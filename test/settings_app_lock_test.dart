import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/main.dart';
import 'package:el_ahorrador/features/settings/presentation/settings_screen.dart';
import 'package:el_ahorrador/core/security/app_lock_settings.dart';
import 'package:el_ahorrador/core/security/local_auth_service.dart';

class _MemoryStore implements AppLockPreferenceStore {
  bool stored = false;

  @override
  Future<bool> read() async => stored;

  @override
  Future<void> write(bool enabled) async => stored = enabled;
}

class _FakeAuthenticator implements LocalAuthenticator {
  _FakeAuthenticator(this.result);

  final LocalAuthenticationResult result;
  int calls = 0;

  @override
  Future<LocalAuthenticationResult> authenticate() async {
    calls++;
    return result;
  }
}

void main() {
  Future<void> pumpSettings(
    WidgetTester tester,
    AppLockSettings settings,
    LocalAuthenticator authenticator,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockScope(
          settings: settings,
          child: SecurityScreen(authenticator: authenticator),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
  }

  test('the lock is disabled until the user stores a preference', () async {
    final store = _MemoryStore();
    expect((await AppLockSettings.load(store)).enabled, isFalse);

    store.stored = true;
    expect((await AppLockSettings.load(store)).enabled, isTrue);
  });

  testWidgets('Seguridad enables the lock after authenticating', (
    tester,
  ) async {
    final store = _MemoryStore();
    final settings = AppLockSettings(store);
    final authenticator = _FakeAuthenticator(
      LocalAuthenticationResult.authenticated,
    );
    await pumpSettings(tester, settings, authenticator);

    expect(find.text('BLOQUEO'), findsOneWidget);
    await tester.tap(find.text('Bloqueo con huella'));
    await tester.pumpAndSettle();

    expect(authenticator.calls, 1);
    expect(settings.enabled, isTrue);
    expect(store.stored, isTrue);
    await unmount(tester);
  });

  testWidgets('the lock stays off when the device cannot authenticate', (
    tester,
  ) async {
    final store = _MemoryStore();
    final settings = AppLockSettings(store);
    await pumpSettings(
      tester,
      settings,
      _FakeAuthenticator(LocalAuthenticationResult.unavailable),
    );

    await tester.tap(find.text('Bloqueo con huella'));
    await tester.pumpAndSettle();

    expect(settings.enabled, isFalse);
    expect(store.stored, isFalse);
    expect(find.textContaining('Configura una huella'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an app started with the lock enabled opens locked', (
    tester,
  ) async {
    final settings = AppLockSettings(_MemoryStore(), enabled: true);
    await tester.pumpWidget(SolitoApp(appLockSettings: settings));

    expect(find.textContaining('bloqueado'), findsOneWidget);
    await unmount(tester);
  });
}
