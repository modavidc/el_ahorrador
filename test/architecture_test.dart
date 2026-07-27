import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Small, dependency-free architecture checks.
///
/// These tests intentionally inspect source code: they protect boundaries that
/// the Dart type system cannot express and fail with the exact offending file.
void main() {
  final projectRoot = Directory.current;
  final libDirectory = Directory(
    '${projectRoot.path}${Platform.pathSeparator}lib',
  );

  group('architecture boundaries', () {
    test('only the composition root and data layer create AppDatabase', () {
      final offenders = <String>[];

      for (final file in _dartFiles(libDirectory)) {
        final relativePath = _relativePath(projectRoot, file);
        final isAllowed =
            relativePath == 'lib/main.dart' ||
            relativePath.startsWith('lib/data/');
        if (!isAllowed &&
            RegExp(
              r'\bAppDatabase\s*\(\s*\)',
            ).hasMatch(file.readAsStringSync())) {
          offenders.add(relativePath);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'AppDatabase has a single owner. Inject it instead of creating '
            'a second connection in:\n${offenders.join('\n')}',
      );
    });

    test('libraries never import the composition root', () {
      final offenders = <String>[];
      for (final file in _dartFiles(libDirectory)) {
        final relativePath = _relativePath(projectRoot, file);
        if (relativePath == 'lib/main.dart') continue;
        if (_imports(
          file,
        ).any((path) => path.endsWith('/main.dart') || path == 'main.dart')) {
          offenders.add(relativePath);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'main.dart wires dependencies and must never become a '
            'reusable dependency. Offenders:\n${offenders.join('\n')}',
      );
    });

    test('core and data do not depend on presentation', () {
      final offenders = <String>[];
      for (final file in _dartFiles(libDirectory)) {
        final relativePath = _relativePath(projectRoot, file);
        if (!relativePath.startsWith('lib/core/') &&
            !relativePath.startsWith('lib/data/')) {
          continue;
        }
        final invalid = _imports(file).where(
          (path) =>
              path.contains('/screens/') ||
              path.contains('/widgets/') ||
              path.startsWith('../screens/') ||
              path.startsWith('../widgets/'),
        );
        if (invalid.isNotEmpty) offenders.add(relativePath);
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Inner layers cannot depend on screens or widgets. '
            'Offenders:\n${offenders.join('\n')}',
      );
    });

    test('capture application layer is framework and infrastructure free', () {
      final applicationDirectory = Directory(
        '${libDirectory.path}${Platform.pathSeparator}features'
        '${Platform.pathSeparator}capture${Platform.pathSeparator}application',
      );
      final offenders = <String>[];
      for (final file in _dartFiles(applicationDirectory)) {
        final imports = _imports(file);
        final invalid = imports.where(
          (path) =>
              path.startsWith('package:flutter/') ||
              path.startsWith('package:share_handler/') ||
              path.contains('/data/') ||
              path.startsWith('../../../data/'),
        );
        if (invalid.isNotEmpty) {
          offenders.add(
            '${_relativePath(projectRoot, file)}: ${invalid.join(', ')}',
          );
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'Application code must use ports and Dart/domain types, not '
            'Flutter, plugins, or data adapters:\n${offenders.join('\n')}',
      );
    });

    test('shared capture orchestration lives outside main.dart', () {
      final coordinator = File(
        '${libDirectory.path}${Platform.pathSeparator}features'
        '${Platform.pathSeparator}capture${Platform.pathSeparator}application'
        '${Platform.pathSeparator}shared_capture_coordinator.dart',
      );
      final mainFile = File(
        '${libDirectory.path}${Platform.pathSeparator}main.dart',
      );

      expect(
        coordinator.existsSync(),
        isTrue,
        reason: 'Create the application-level SharedCaptureCoordinator.',
      );
      final coordinatorSource = coordinator.readAsStringSync();
      expect(
        coordinatorSource,
        contains('class SharedCaptureCoordinator'),
        reason: 'The coordinator must expose an explicit application boundary.',
      );
      final mainImports = _imports(mainFile);
      expect(
        mainImports,
        contains('features/capture/shared_capture_runtime.dart'),
        reason: 'main.dart must delegate capture to its production adapter.',
      );
      expect(
        mainImports,
        isNot(
          anyOf(
            contains('core/ocr_engine.dart'),
            contains('core/capture_validator.dart'),
            contains('core/fast_parser.dart'),
            contains('core/yape_parser.dart'),
            contains('core/banco_parser.dart'),
            contains('core/binance_parser.dart'),
          ),
        ),
        reason: 'main.dart is a composition root, not the capture pipeline.',
      );

      expect(
        coordinatorSource,
        contains('sealed class CaptureProcessingState'),
        reason: 'Capture state transitions must remain explicit.',
      );
      expect(
        coordinatorSource,
        contains('abstract interface class CaptureRepository'),
        reason: 'Persistence must remain behind an application port.',
      );
      expect(
        coordinatorSource,
        contains('abstract interface class IncomingFileStore'),
        reason: 'File storage must remain behind an application port.',
      );
      expect(
        coordinatorSource,
        contains('if (_isProcessing) return const CaptureBusy()'),
        reason: 'The coordinator must continue to own concurrency control.',
      );
    });
  });
}

Iterable<String> _imports(File file) sync* {
  final source = file.readAsStringSync();
  final pattern = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''', multiLine: true);
  for (final match in pattern.allMatches(source)) {
    yield match.group(1)!;
  }
}

Iterable<File> _dartFiles(Directory directory) sync* {
  if (!directory.existsSync()) return;
  for (final entity in directory.listSync(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

String _relativePath(Directory root, File file) {
  final prefix = '${root.absolute.path}${Platform.pathSeparator}';
  return file.absolute.path
      .substring(prefix.length)
      .replaceAll(Platform.pathSeparator, '/');
}
