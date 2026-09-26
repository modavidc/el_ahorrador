import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Design handoff rule: no hex color, literal font size or emoji in the v1
/// screens (`lib/ui`); everything comes from `lib/theme/design_tokens.dart`.
void main() {
  final files = Directory('lib/ui')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  final rules = <String, RegExp>{
    'hex color': RegExp(r'Color\(0x'),
    'literal fontSize': RegExp(r'fontSize\s*:'),
    'Material Icons (use DesignIcons)': RegExp(r'\bIcons\.'),
    'emoji': RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true),
  };

  test('lib/ui is not empty', () => expect(files, isNotEmpty));

  for (final MapEntry(key: name, value: pattern) in rules.entries) {
    test('no $name in lib/ui', () {
      final offenders = [
        for (final file in files)
          for (final (i, line) in file.readAsLinesSync().indexed)
            if (pattern.hasMatch(line)) '${file.path}:${i + 1}: ${line.trim()}',
      ];
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  }
}
