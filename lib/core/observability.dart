import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Privacy-safe, structured operational telemetry.
///
/// Never pass OCR text, file paths, transaction descriptions, vendor names,
/// account identifiers or monetary amounts in [attributes].
abstract final class AppObservability {
  static const _environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const _revision = String.fromEnvironment(
    'APP_REVISION',
    defaultValue: 'local',
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
      // Observability must never prevent the application from starting.
      _release = 'unknown';
    }
    const dsn = String.fromEnvironment('SENTRY_DSN');
    _remoteEnabled = dsn.isNotEmpty;

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
        ..dsn = dsn
        ..environment = _environment
        ..release = 'el_ahorrador@$_release'
        ..dist = _revision
        ..sendDefaultPii = false
        ..attachScreenshot = false
        ..maxRequestBodySize = MaxRequestBodySize.never
        ..tracesSampleRate = kReleaseMode ? 0.10 : 0.0;
    }, appRunner: start);
  }

  static void info(String event, {Map<String, Object?> attributes = const {}}) {
    _write('info', event, attributes);
  }

  static void warning(
    String event, {
    Map<String, Object?> attributes = const {},
  }) {
    _write('warning', event, attributes);
  }

  static Future<void> error(
    String event,
    Object error,
    StackTrace stackTrace, {
    Map<String, Object?> attributes = const {},
  }) async {
    _write('error', event, attributes);
    if (_remoteEnabled) {
      // Messages and local stack traces can contain OCR data or file paths.
      // Send a stable diagnostic envelope while retaining the failure type.
      await Sentry.captureException(
        StateError('Operation failed: $event'),
        withScope: (scope) {
          scope.setTag('operation', event);
          scope.setTag('error_type', error.runtimeType.toString());
          scope.setContexts('operation_attributes', sanitizeAttributes(attributes));
        },
      );
    }
  }

  static void metric(
    String name,
    num value, {
    String unit = 'millisecond',
    Map<String, Object?> attributes = const {},
  }) {
    _write('metric', name, {'value': value, 'unit': unit, ...attributes});
  }

  static void _write(
    String level,
    String event,
    Map<String, Object?> attributes,
  ) {
    final safeAttributes = sanitizeAttributes(attributes);
    final record = <String, Object?>{
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'level': level,
      'event': event,
      'release': _release,
      'environment': _environment,
      'revision': _revision,
      'attributes': safeAttributes,
    };
    developer.log(jsonEncode(record), name: 'el_ahorrador');
    if (_remoteEnabled) {
      unawaited(
        Sentry.addBreadcrumb(
          Breadcrumb(
            category: level == 'metric' ? 'metric' : 'operation',
            message: event,
            data: safeAttributes,
            level: level == 'warning' ? SentryLevel.warning : SentryLevel.info,
          ),
        ),
      );
    }
  }

  @visibleForTesting
  static Map<String, Object?> sanitizeAttributes(
    Map<String, Object?> attributes,
  ) {
    const blockedTerms = {
      'account',
      'amount',
      'capture',
      'description',
      'email',
      'file',
      'image',
      'name',
      'notes',
      'ocr',
      'path',
      'phone',
      'text',
      'user',
      'vendor',
    };
    return Map.fromEntries(
      attributes.entries
          .where((entry) {
            final key = entry.key.toLowerCase();
            return !blockedTerms.any(key.contains);
          })
          .map((entry) {
            final value = entry.value;
            return MapEntry(
              entry.key,
              value is num || value is bool || value == null
                  ? value
                  : value.toString(),
            );
          }),
    );
  }
}
