import 'package:el_ahorrador/features/capture/domain/background_capture.dart';

/// [BackgroundCapture] for platforms without it (tests, iOS).
class UnsupportedBackgroundCapture implements BackgroundCapture {
  const UnsupportedBackgroundCapture();

  @override
  Stream<BackgroundCaptureState> watch() =>
      Stream.value(BackgroundCaptureState.unsupported);

  @override
  Future<void> setEnabled(bool enabled) async {}

  @override
  Future<void> openSettings(CapturePermission permission) async {}

  @override
  Future<void> refresh() async {}

  @override
  Stream<void> get captured => const Stream.empty();
}
