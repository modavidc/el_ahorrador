/// Feature switches for protections that may be temporarily disabled during
/// development and visual validation.
abstract final class SecurityConfig {
  /// Enables the biometric/device-PIN gate when supplied at build time with:
  /// `--dart-define=ENABLE_APP_LOCK=true`.
  static const bool enableAppLock = bool.fromEnvironment(
    'ENABLE_APP_LOCK',
    defaultValue: false,
  );
}
