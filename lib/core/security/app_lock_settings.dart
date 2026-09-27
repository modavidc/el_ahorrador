import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists whether the fingerprint/device-credential lock is enabled.
abstract interface class AppLockPreferenceStore {
  Future<bool> read();
  Future<void> write(bool enabled);
}

/// Stored in the Keystore-backed secure storage so the flag cannot be flipped
/// by editing plain app preferences.
final class SecureAppLockPreferenceStore implements AppLockPreferenceStore {
  const SecureAppLockPreferenceStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'app_lock_enabled';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> read() async => await _storage.read(key: _key) == 'true';

  @override
  Future<void> write(bool enabled) =>
      _storage.write(key: _key, value: enabled.toString());
}

/// App lock preference. Disabled by default; the user turns it on from
/// Ajustes → Seguridad → Bloqueo con huella.
class AppLockSettings extends ValueNotifier<bool> {
  AppLockSettings(this._store, {bool enabled = false}) : super(enabled);

  /// In-memory settings for tests and for when no store is available.
  AppLockSettings.disabled() : _store = null, super(false);

  final AppLockPreferenceStore? _store;

  bool get enabled => value;

  static Future<AppLockSettings> load(AppLockPreferenceStore store) async {
    var enabled = false;
    try {
      enabled = await store.read();
    } catch (_) {
      // Unreadable storage must not keep the app from starting; the lock
      // stays off, which is also the default.
    }
    return AppLockSettings(store, enabled: enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    await _store?.write(enabled);
    value = enabled;
  }
}

/// Exposes [AppLockSettings] to screens such as Ajustes.
class AppLockScope extends InheritedNotifier<AppLockSettings> {
  const AppLockScope({
    required AppLockSettings settings,
    required super.child,
    super.key,
  }) : super(notifier: settings);

  static AppLockSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLockScope>()?.notifier;
}
