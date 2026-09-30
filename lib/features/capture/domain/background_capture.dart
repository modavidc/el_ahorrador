/// Capture of payments in the background: a service that watches new
/// screenshots and payment notifications. Needs Android permissions that
/// HyperOS (Xiaomi) keeps off by default. Autostart and "lock in recents"
/// cannot be read by apps; the user confirms them after opening their page.
enum CapturePermission {
  photos(
    'Acceso a tus capturas',
    'Para leer las capturas de pantalla de pagos',
    true,
  ),
  alerts('Mostrar avisos', 'Te avisa "Registrado" con Deshacer', true),
  notifications(
    'Acceso a notificaciones',
    'Lee avisos de Yape, Plin y bancos',
    true,
  ),
  battery('Batería sin restricciones', 'HyperOS no cerrará la captura', true),
  autostart('Inicio automático', 'Sigue activa tras reiniciar', true),
  recents('Bloquear en recientes', 'No se cierra al limpiar', false);

  const CapturePermission(this.title, this.subtitle, this.required);

  final String title;
  final String subtitle;
  final bool required;
}

final class BackgroundCaptureState {
  const BackgroundCaptureState({
    required this.supported,
    required this.enabled,
    required this.granted,
  });

  static const unsupported = BackgroundCaptureState(
    supported: false,
    enabled: false,
    granted: {},
  );

  /// False where the platform cannot capture in the background (iOS, tests).
  final bool supported;

  /// The user wants it on (Ajustes → Captura activa).
  final bool enabled;
  final Set<CapturePermission> granted;

  int get missingRequired => CapturePermission.values
      .where((p) => p.required && !granted.contains(p))
      .length;

  /// Every required permission is granted.
  bool get ready => missingRequired == 0;

  /// On and able to run.
  bool get active => supported && enabled && ready;
}

abstract interface class BackgroundCapture {
  Stream<BackgroundCaptureState> watch();

  Future<void> setEnabled(bool enabled);

  /// Opens the system page where the user grants [permission]. The state is
  /// checked again when the app comes back.
  Future<void> openSettings(CapturePermission permission);

  /// Checks the permissions again (after returning from system settings).
  Future<void> refresh();

  /// Fires when the background engine registered something, so the open
  /// interface can refresh.
  Stream<void> get captured;
}
