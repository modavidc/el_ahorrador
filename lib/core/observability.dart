import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Structured diagnostics with remote reporting disabled unless the build
/// carries both a DSN and explicit telemetry consent.
abstract final class AppObservability {
  static const _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _revision = String.fromEnvironment(
    'APP_REVISION',
    defaultValue: 'local',
  );
  static const _dsn = String.fromEnvironment('SENTRY_DSN');
  static const _telemetryConsent = bool.fromEnvironment(
    'TELEMETRY_CONSENT',
    defaultValue: false,
  );

  static String _release = 'unknown';
  static bool _remoteEnabled = false;

  static String get release => _release;
  static bool get remoteEnabled => _remoteEnabled;

  static Future<void> run(Widget app) async {
    try {
      final package = await PackageInfo.fromPlatform();
      _release = '${package.version}+${package.buildNumber}';
    } catch (_) {
      _release = 'unknown';
    }
    _remoteEnabled = _dsn.isNotEmpty && _telemetryConsent;

    void start() {
      info('app_started', attributes: {'remote_reporting': _remoteEnabled});
      runApp(_remoteEnabled ? SentryWidget(child: app) : app);
    }

    if (!_remoteEnabled) {
      start();
      return;
    }
    await SentryFlutter.init((options) {
      options
        ..dsn = _dsn
        ..environment = _environment
        ..release = 'el_ahorrador@$_release'
        ..dist = _revision
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..maxRequestBodySize = MaxRequestBodySize.never
        ..tracesSampleRate = kReleaseMode ? 0.10 : 0.0;
    }, appRunner: start);
  }

  static void info(
    String event, {
    Map<String, Object?> attributes = const {},
  }) => _write('info', event, attributes);

  static void metric(
    String event,
    num value, {
    String unit = 'millisecond',
    Map<String, Object?> attributes = const {},
  }) => _write('metric', event, {'value': value, 'unit': unit, ...attributes});

  static Future<void> error(
    String event,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> attributes = const {},
  }) async {
    final safe = sanitizeAttributes(attributes);
    _write('error', event, safe);
    if (_remoteEnabled) {
      await Sentry.captureMessage(
        'Operation failed: $event (${error.runtimeType})',
        level: SentryLevel.error,
        withScope: (scope) {
          scope.setTag('operation', event);
          scope.setTag('error_type', error.runtimeType.toString());
          scope.setContexts('operation_attributes', safe);
        },
      );
    }
  }

  static void _write(
    String level,
    String event,
    Map<String, Object?> attributes,
  ) {
    final safe = sanitizeAttributes(attributes);
    developer.log(
      jsonEncode({
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'level': level,
        'event': event,
        'release': _release,
        'environment': _environment,
        'revision': _revision,
        'attributes': safe,
      }),
      name: 'el_ahorrador',
    );
    if (_remoteEnabled) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: level == 'metric' ? 'metric' : 'operation',
            message: event,
            data: safe,
            level: level == 'error' ? SentryLevel.error : SentryLevel.info,
          ),
        ),
      );
    }
  }

  /// Only explicitly approved operational dimensions may leave the process.
  @visibleForTesting
  static Map<String, Object?> sanitizeAttributes(Map<String, Object?> values) {
    const allowed = {
      'attempt',
      'count',
      'duration_ms',
      'operation',
      'remote_reporting',
      'result',
      'stage',
      'unit',
      'value',
    };
    return Map.fromEntries(
      values.entries
          .where((entry) {
            final value = entry.value;
            return allowed.contains(entry.key) &&
                (value == null ||
                    value is num ||
                    value is bool ||
                    value is Enum);
          })
          .map((entry) => MapEntry(entry.key, entry.value?.toString())),
    );
  }
}
