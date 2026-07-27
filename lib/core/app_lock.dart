import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

/// Protects financial data with operating-system local authentication.
///
/// Authentication is delegated to the operating system; the app never sees or
/// stores biometric material. Devices without a configured screen lock remain
/// locked so financial data is never exposed through a fail-open path.
class AppLock extends StatefulWidget {
  const AppLock({required this.child, super.key});

  final Widget child;

  @override
  State<AppLock> createState() => _AppLockState();
}

class _AppLockState extends State<AppLock> with WidgetsBindingObserver {
  final LocalAuthentication _authentication = LocalAuthentication();
  bool _checking = true;
  bool _locked = true;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      if (mounted) {
        setState(() => _locked = true);
      }
    } else if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    _authInProgress = true;
    try {
      final supported = await _authentication.isDeviceSupported();
      final canCheck = await _authentication.canCheckBiometrics;
      if (!supported && !canCheck) {
        if (mounted) {
          setState(() => _checking = false);
        }
        return;
      }
      final authenticated = await _authentication.authenticate(
        localizedReason:
            'Desbloquea El Ahorrador para proteger tus datos financieros',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      if (mounted) {
        setState(() {
          _locked = !authenticated;
          _checking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _locked = true;
          _checking = false;
        });
      }
    } finally {
      _authInProgress = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: _checking
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text('El Ahorrador está bloqueado'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Desbloquear'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
