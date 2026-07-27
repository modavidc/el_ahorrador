import 'dart:io';

final errors = <String>[];
final warnings = <String>[];

void main() {
  _checkVersion();
  _requireText(
    'android/app/build.gradle.kts',
    'throw GradleException("Release signing is not configured.',
    'Android release debe fallar si falta la firma',
  );
  _requireText(
    'android/app/src/main/AndroidManifest.xml',
    'android:allowBackup="false"',
    'backup Android desactivado',
  );
  _requireText(
    'ios/Runner/Info.plist',
    r'$(FLUTTER_BUILD_NAME)',
    'versión iOS derivada de pubspec',
  );
  _requireText(
    'ios/Runner/Info.plist',
    'NSFaceIDUsageDescription',
    'descripción de Face ID',
  );
  _requireFiles([
    'android/key.properties.example',
    'docs/release/README.md',
    'docs/release/permissions.md',
    'docs/release/store-listings.md',
    'docs/release/release-evidence.md',
  ]);
  _checkIgnoredSecrets();

  stdout.writeln('Release readiness (comprobaciones estáticas)');
  for (final warning in warnings) {
    stdout.writeln('WARN: $warning');
  }
  if (errors.isEmpty) {
    stdout.writeln('OK: ${warnings.length} advertencia(s), 0 error(es).');
    stdout.writeln('Los gates de tiendas/dispositivos siguen siendo manuales.');
    return;
  }
  for (final error in errors) {
    stderr.writeln('ERROR: $error');
  }
  stderr.writeln('FALLÓ: ${errors.length} error(es).');
  exitCode = 1;
}

void _checkVersion() {
  final pubspec = File('pubspec.yaml');
  if (!pubspec.existsSync()) {
    errors.add('Falta pubspec.yaml.');
    return;
  }
  final match = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync());
  if (match == null) {
    errors.add('version debe usar SemVer y build: x.y.z+n.');
    return;
  }
  final build = int.parse(match.group(4)!);
  if (build < 1) errors.add('El build debe ser mayor que cero.');
  if (build == 1) {
    warnings.add(
      'build 1 es válido, pero confirma en Play/App Store que nunca fue usado.',
    );
  }
  stdout.writeln('Versión detectada: ${match.group(0)!.split(':').last.trim()}');
}

void _requireText(String path, String expected, String label) {
  final file = File(path);
  if (!file.existsSync() || !file.readAsStringSync().contains(expected)) {
    errors.add('No se pudo verificar: $label ($path).');
  }
}

void _requireFiles(List<String> paths) {
  for (final path in paths) {
    if (!File(path).existsSync()) errors.add('Falta evidencia requerida: $path.');
  }
}

void _checkIgnoredSecrets() {
  final gitignore = File('.gitignore');
  if (!gitignore.existsSync()) {
    errors.add('Falta .gitignore.');
    return;
  }
  final text = gitignore.readAsStringSync();
  for (final rule in ['/android/key.properties', '*.jks', '*.keystore']) {
    if (!text.contains(rule)) errors.add('Falta regla sensible en .gitignore: $rule');
  }
  final result = Process.runSync('git', [
    'ls-files',
    '--error-unmatch',
    'android/key.properties',
  ]);
  if (result.exitCode == 0) {
    errors.add('android/key.properties contiene secretos y está versionado.');
  }
}
