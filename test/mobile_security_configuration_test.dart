import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String source(String path) => File(path).readAsStringSync();

  test('Android disables unsafe backup and plaintext transport', () {
    final manifest = source('android/app/src/main/AndroidManifest.xml');
    expect(manifest, contains('android:allowBackup="false"'));
    expect(manifest, contains('android:fullBackupContent="false"'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
  });

  test('Android screenshot protection is controlled by configuration', () {
    final activity = source(
      'android/app/src/main/kotlin/com/example/mis_gastos/MainActivity.kt',
    );
    final config = source(
      'android/app/src/main/res/values/security_config.xml',
    );
    expect(activity, contains('WindowManager.LayoutParams.FLAG_SECURE'));
    expect(activity, contains('R.bool.block_screenshots'));
    expect(config, contains('<bool name="block_screenshots">false</bool>'));
  });

  test('local authentication is a user setting, disabled by default', () {
    final settings = source('lib/security/app_lock_settings.dart');
    final main = source('lib/main.dart');
    expect(settings, contains('AppLockSettings.disabled()'));
    expect(settings, contains('FlutterSecureStorage'));
    expect(main, contains('AppLockSettings.load('));
    expect(main, contains('AppLockGate('));
  });

  test('iOS installs a privacy shield before becoming inactive', () {
    final delegate = source('ios/Runner/AppDelegate.swift');
    expect(delegate, contains('applicationWillResignActive'));
    expect(delegate, contains('window.addSubview(shield)'));
    expect(delegate, contains('applicationDidBecomeActive'));
    expect(delegate, contains('privacyView?.removeFromSuperview()'));
  });

  test('iOS privacy manifest is valid and included in the app target', () {
    final manifest = source('ios/Runner/PrivacyInfo.xcprivacy');
    final project = source('ios/Runner.xcodeproj/project.pbxproj');
    expect(manifest, contains('<key>NSPrivacyTracking</key>'));
    expect(manifest, contains('<false/>'));
    expect(manifest, contains('<key>NSPrivacyCollectedDataTypes</key>'));
    expect(project, contains('PrivacyInfo.xcprivacy in Resources'));
  });

  test('release source contains no embedded Sentry DSN', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    for (final file in files) {
      final contents = file.readAsStringSync();
      expect(
        RegExp(
          r'https://[^\s@]+@[^\s]+\.ingest\.sentry\.io/\d+',
        ).hasMatch(contents),
        isFalse,
        reason: 'Hard-coded telemetry credential in ${file.path}',
      );
    }
  });
}
