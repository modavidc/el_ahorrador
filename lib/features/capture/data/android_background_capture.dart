import 'dart:async';

import 'package:flutter/services.dart';

import 'package:el_ahorrador/features/capture/domain/background_capture.dart';

/// [BackgroundCapture] backed by the Android service
/// (`android/app/src/main/kotlin/.../capture`).
///
/// Channel `solito/capture`:
/// - `state` → `{enabled: bool, granted: [permission names]}`
/// - `setEnabled(bool)` and `openSettings(permission name)` → state
/// - native → Dart `captured`: the background engine registered something.
class AndroidBackgroundCapture implements BackgroundCapture {
  AndroidBackgroundCapture({
    MethodChannel channel = const MethodChannel('solito/capture'),
  }) : _channel = channel {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'captured') _captured.add(null);
      if (call.method == 'state') _publish(call.arguments);
    });
  }

  final MethodChannel _channel;
  final _states = StreamController<BackgroundCaptureState>.broadcast();
  final _captured = StreamController<void>.broadcast();
  BackgroundCaptureState? _last;

  @override
  Stream<BackgroundCaptureState> watch() {
    // Subscribes before asking, so no state published meanwhile is lost.
    StreamSubscription<BackgroundCaptureState>? source;
    late final StreamController<BackgroundCaptureState> out;
    out = StreamController(
      onListen: () {
        source = _states.stream.listen(out.add);
        final last = _last;
        if (last != null) {
          out.add(last);
        } else {
          refresh();
        }
      },
      onCancel: () => source?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<void> refresh() async {
    try {
      _publish(await _channel.invokeMethod<Object?>('state'));
    } on MissingPluginException {
      // No Android service (tests, other platforms).
      _last = BackgroundCaptureState.unsupported;
      _states.add(_last!);
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async =>
      _publish(await _channel.invokeMethod<Object?>('setEnabled', enabled));

  @override
  Future<void> openSettings(CapturePermission permission) async => _publish(
    await _channel.invokeMethod<Object?>('openSettings', permission.name),
  );

  @override
  Stream<void> get captured => _captured.stream;

  void _publish(Object? raw) {
    if (raw is! Map) return;
    final granted = {
      for (final name in raw['granted'] as List? ?? const [])
        ...CapturePermission.values.where((p) => p.name == name),
    };
    _last = BackgroundCaptureState(
      supported: true,
      enabled: raw['enabled'] == true,
      granted: granted,
    );
    _states.add(_last!);
  }
}
