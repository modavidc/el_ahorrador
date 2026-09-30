import 'package:local_auth/local_auth.dart';

enum LocalAuthenticationResult { authenticated, rejected, unavailable, error }

abstract interface class LocalAuthenticator {
  Future<LocalAuthenticationResult> authenticate();
}

/// Uses the operating system's biometric prompt with the device credential as
/// fallback. The app deliberately never stores or validates its own PIN.
final class SystemLocalAuthenticator implements LocalAuthenticator {
  SystemLocalAuthenticator({LocalAuthentication? localAuth})
    : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  @override
  Future<LocalAuthenticationResult> authenticate() async {
    try {
      if (!await _localAuth.isDeviceSupported()) {
        return LocalAuthenticationResult.unavailable;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Confirma tu identidad para acceder a Solito',
        options: const AuthenticationOptions(
          biometricOnly: false,
          // AppLockGate owns session restoration. Letting the plugin also
          // restart authentication can strand the prompt on HyperOS.
          stickyAuth: false,
          useErrorDialogs: true,
        ),
      );
      return authenticated
          ? LocalAuthenticationResult.authenticated
          : LocalAuthenticationResult.rejected;
    } catch (_) {
      // Platform errors can contain device details. Do not log them here.
      return LocalAuthenticationResult.error;
    }
  }
}
