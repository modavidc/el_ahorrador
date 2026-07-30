import 'package:flutter/material.dart';

import 'local_auth_service.dart';

/// Allows deterministic lock requests (for example from security policy and
/// tests) without exposing the gate's internal state.
class AppLockController {
  VoidCallback? _lockCallback;

  void lock() => _lockCallback?.call();
}

/// Keeps every Navigator route and overlay hidden until the OS authenticates
/// the user. It locks again whenever the app actually enters the background.
class AppLockGate extends StatefulWidget {
  const AppLockGate({
    required this.child,
    this.authenticator,
    this.controller,
    this.gracePeriod = const Duration(minutes: 5),
    super.key,
  });

  final Widget child;
  final LocalAuthenticator? authenticator;
  final AppLockController? controller;
  final Duration gracePeriod;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late final LocalAuthenticator _authenticator;
  bool _locked = true;
  bool _authenticating = false;
  LocalAuthenticationResult? _lastResult;
  int _authenticationGeneration = 0;
  final Stopwatch _monotonicClock = Stopwatch();
  Duration? _lastAuthenticatedAt;

  @override
  void initState() {
    super.initState();
    _authenticator = widget.authenticator ?? SystemLocalAuthenticator();
    _monotonicClock.start();
    widget.controller?._lockCallback = _lock;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.controller?._lockCallback = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        if (!_authenticating) _coverForBackground();
      case AppLifecycleState.resumed:
        if (_locked && !_authenticating) _restoreSessionWithinGracePeriod();
      case AppLifecycleState.inactive:
        // Native authentication prompts can make the app inactive. Locking on
        // this transition would invalidate a successful prompt.
        break;
    }
  }

  void _lock() {
    _lastAuthenticatedAt = null;
    _coverForBackground();
  }

  void _coverForBackground() {
    _authenticationGeneration++;
    if (mounted) {
      setState(() {
        _locked = true;
        _authenticating = false;
        _lastResult = null;
      });
    }
  }

  void _restoreSessionWithinGracePeriod() {
    final lastAuthenticatedAt = _lastAuthenticatedAt;
    final graceIsValid =
        lastAuthenticatedAt != null &&
        _monotonicClock.elapsed - lastAuthenticatedAt <= widget.gracePeriod;
    if (graceIsValid) {
      if (mounted) setState(() => _locked = false);
    }
  }

  Future<void> _unlock() async {
    if (!mounted || !_locked || _authenticating) return;
    final generation = ++_authenticationGeneration;
    setState(() {
      _authenticating = true;
      _lastResult = null;
    });

    final result = await _authenticator.authenticate();
    if (!mounted || generation != _authenticationGeneration) return;

    setState(() {
      _authenticating = false;
      _lastResult = result;
      if (result == LocalAuthenticationResult.authenticated) {
        _locked = false;
        _lastAuthenticatedAt = _monotonicClock.elapsed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;

    final unavailable = _lastResult == LocalAuthenticationResult.unavailable;
    final failed = _lastResult == LocalAuthenticationResult.error;
    final rejected = _lastResult == LocalAuthenticationResult.rejected;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'El Ahorrador está bloqueado',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    unavailable
                        ? 'Configura una huella, Face ID o bloqueo de pantalla seguro en tu dispositivo para acceder.'
                        : failed
                        ? 'No se pudo abrir la autenticación del dispositivo. Inténtalo nuevamente.'
                        : rejected
                        ? 'La autenticación fue cancelada o rechazada. Puedes intentarlo nuevamente.'
                        : 'Usa tu biometría o la credencial segura del dispositivo para continuar.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  if (_authenticating)
                    const CircularProgressIndicator()
                  else
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
