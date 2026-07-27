import 'dart:io';

const expectedAppId = 'com.misgasticos.app';

void main() {
  final failures = <String>[];
  final checks = <({String path, RegExp pattern, String label})>[
    (
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'applicationId\s*=\s*"com\.misgasticos\.app"'),
      label: 'Android applicationId',
    ),
    (
      path: 'android/app/build.gradle.kts',
      pattern: RegExp(r'namespace\s*=\s*"com\.misgasticos\.app"'),
      label: 'Android namespace',
    ),
    (
      path: 'ios/Runner.xcodeproj/project.pbxproj',
      pattern: RegExp(
        r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*com\.misgasticos\.app;',
      ),
      label: 'iOS Runner bundle identifier',
    ),
  ];

  for (final check in checks) {
    final file = File(check.path);
    if (!file.existsSync()) {
      failures.add('Falta ${check.path}.');
    } else if (!check.pattern.hasMatch(file.readAsStringSync())) {
      failures.add('${check.label} no coincide con $expectedAppId.');
    }
  }

  for (final root in ['android', 'ios']) {
    final directory = Directory(root);
    if (!directory.existsSync()) continue;
    for (final entity in directory.listSync(recursive: true)) {
      if (entity is! File ||
          _isGenerated(entity.path) ||
          !_isTextConfiguration(entity.path)) {
        continue;
      }
      final contents = entity.readAsStringSync();
      if (contents.contains('com.example') || contents.contains('misGastos')) {
        failures.add('Identificador de ejemplo en ${entity.path}.');
      }
    }
  }

  if (failures.isNotEmpty) {
    stderr.writeln('Gate de identificadores: FALLÓ');
    for (final failure in failures.toSet()) {
      stderr.writeln('  - $failure');
    }
    exitCode = 1;
    return;
  }
  stdout.writeln('Gate de identificadores: OK ($expectedAppId)');
}

bool _isTextConfiguration(String path) {
  const extensions = {
    '.gradle',
    '.kts',
    '.kt',
    '.xml',
    '.plist',
    '.pbxproj',
    '.xcconfig',
    '.swift',
    '.entitlements',
  };
  final normalized = path.replaceAll('\\', '/');
  return extensions.any(normalized.endsWith);
}

bool _isGenerated(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.contains('/build/') ||
      normalized.contains('/.dart_tool/') ||
      normalized.endsWith('.xcuserstate');
}
