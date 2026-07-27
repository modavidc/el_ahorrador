import 'package:flutter_test/flutter_test.dart';

import '../tool/check_coverage.dart' as checker;

void main() {
  test('parses totals and normalizes Windows coverage paths', () {
    final report = checker.CoverageReport.parse(const [
      r'SF:lib\core\financial_domain.dart',
      'LF:10',
      'LH:8',
      'end_of_record',
      'SF:lib/data/daos.dart',
      'LF:20',
      'LH:10',
      'end_of_record',
    ]);

    expect(report.found, 30);
    expect(report.hit, 18);
    expect(report.percentage, 60);
    expect(
      report.coverageFor('lib/core/financial_domain.dart')!.percentage,
      80,
    );
  });

  test('keeps an unterminated final LCOV record', () {
    final report = checker.CoverageReport.parse(const [
      'SF:lib/example.dart',
      'LF:4',
      'LH:3',
    ]);

    expect(report.coverageFor('lib/example.dart')!.percentage, 75);
  });
}
