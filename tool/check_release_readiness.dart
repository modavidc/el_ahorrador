import 'dart:io';

void main() {
  final failures = <String>[];
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final gradle = File('android/app/build.gradle.kts').readAsStringSync();
  final main = File('lib/main.dart').readAsStringSync();

  if (pubspec.contains('version: 1.0.0+1')) {
    failures.add('replace the template application version');
  }
  if (gradle.contains('com.example') ||
      gradle.contains('signingConfigs.getByName("debug")')) {
    failures.add('Android still uses a template identifier or debug signing');
  }
  if (!main.contains('AppObservability.run')) {
    failures.add('observability is not connected to application startup');
  }
  if (!File('.github/workflows/ci.yml').existsSync() ||
      !File('.github/workflows/release.yml').existsSync()) {
    failures.add('delivery workflows are missing');
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Release readiness failed:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Repository release-readiness checks passed.');
}
