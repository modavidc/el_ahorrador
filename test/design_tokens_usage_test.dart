import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Design handoff rule: no hex color, literal font size or emoji in the
/// interface (`presentation/` of every feature, `app/` and the design system
/// kit); everything comes from `lib/design_system/tokens.dart`.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .where(
        (f) =>
            (f.path.contains('/presentation/') &&
                !f.path.contains('/legacy/')) ||
            f.path.startsWith('lib/app/') ||
            f.path == 'lib/design_system/kit.dart',
      )
      .toList();

  final rules = <String, RegExp>{
    'hex color': RegExp(r'Color\(0x'),
    'literal fontSize': RegExp(r'fontSize\s*:'),
    'Material Icons (use DesignIcons)': RegExp(r'\bIcons\.'),
    'emoji': RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
  };

  test('the interface is not empty', () => expect(files, isNotEmpty));

  for (final MapEntry(key: name, value: pattern) in rules.entries) {
    test('no $name in the interface', () {
      final offenders = [
        for (final file in files)
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (pattern.hasMatch(line)) '${file.path}:${i + 1}: ${line.trim()}',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}
