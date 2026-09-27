import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Dependency rules of the layers (see docs/arquitectura.md):
///
/// - `features/*/domain`: pure Dart. Entities, ports and use cases only; no
///   Flutter, no drift, no other layer except other domains and
///   `core/format`.
/// - `features/*/application`: orchestrates use cases for the interface;
///   never touches `data/` or the database.
/// - `features/*/presentation`: widgets; talks to domain and application,
///   never to `data/` or the database. Implementations reach it through
///   `app/dependencies.dart`.
/// - `features/*/data`: implements domain ports; knows nothing of the
///   interface.
/// - `core/` and `design_system/`: shared by everyone, so they depend on no
///   feature (the design system may read domain enums such as Category).
void main() {
  final files = [
    for (final f in Directory('lib').listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart') && !f.path.endsWith('.g.dart'))
        f,
  ];

  List<String> importsOf(File f) => [
    for (final m in RegExp(
      r"^(?:import|export)\s+'([^']+)'",
      multiLine: true,
    ).allMatches(f.readAsStringSync()))
      m.group(1)!,
  ];

  String layerOf(String path) =>
      RegExp(r'features/[^/]+/(\w+)/').firstMatch(path)?.group(1) ?? '';

  void check(
    String name,
    bool Function(String path) applies,
    bool Function(String import) forbidden,
  ) {
    test(name, () {
      final offenders = [
        for (final f in files.where((f) => applies(f.path)))
          for (final i in importsOf(f).where(forbidden)) '${f.path} → $i',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }

  bool isInternal(String i) => i.startsWith('package:el_ahorrador/');

  check(
    'domain is pure Dart',
    (p) => layerOf(p) == 'domain',
    (i) =>
        i.startsWith('package:flutter/') ||
        i.startsWith('package:drift') ||
        (isInternal(i) &&
            !RegExp(r'features/\w+/domain/').hasMatch(i) &&
            !i.contains('/core/format/')),
  );

  check(
    'application does not reach data or the database',
    (p) => layerOf(p) == 'application',
    (i) =>
        i.startsWith('package:drift') ||
        i.contains('/data/') ||
        i.contains('/core/database/') ||
        i.contains('/presentation/'),
  );

  check(
    'presentation does not reach data or the database',
    (p) => layerOf(p) == 'presentation',
    (i) =>
        i.startsWith('package:drift') ||
        i.contains('/data/') ||
        i.contains('/core/database/'),
  );

  check(
    'data knows nothing of the interface',
    (p) => layerOf(p) == 'data',
    (i) =>
        i.startsWith('package:flutter/material') ||
        i.contains('/presentation/') ||
        i.contains('/application/') ||
        i.contains('/design_system/'),
  );

  check(
    'core and design system depend on no feature',
    (p) => p.startsWith('lib/core/') || p.startsWith('lib/design_system/'),
    (i) =>
        i.contains('/app/') ||
        (i.contains('/features/') &&
            !RegExp(r'features/\w+/domain/').hasMatch(i)),
  );

  check(
    'core does not depend on the design system',
    (p) => p.startsWith('lib/core/'),
    (i) => i.contains('/design_system/'),
  );

  test('every feature file sits in a layer', () {
    final loose = [
      for (final f in files)
        if (f.path.startsWith('lib/features/') &&
            !RegExp(
              r'^lib/features/\w+/(domain|data|application|presentation)/',
            ).hasMatch(f.path))
          f.path,
    ];
    expect(loose, isEmpty, reason: loose.join('\n'));
  });
}
