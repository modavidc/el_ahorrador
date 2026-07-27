import 'dart:io';

final class FileCoverage {
  const FileCoverage({required this.found, required this.hit});

  final int found;
  final int hit;

  double get percentage => found == 0 ? 0 : hit * 100 / found;
}

final class CoverageReport {
  CoverageReport(this.files);

  final Map<String, FileCoverage> files;

  factory CoverageReport.parse(Iterable<String> lines) {
    final files = <String, FileCoverage>{};
    String? currentFile;
    var found = 0;
    var hit = 0;

    void finishRecord() {
      if (currentFile != null) {
        files[_normalizePath(currentFile!)] = FileCoverage(
          found: found,
          hit: hit,
        );
      }
      currentFile = null;
      found = 0;
      hit = 0;
    }

    for (final line in lines) {
      if (line.startsWith('SF:')) {
        finishRecord();
        currentFile = line.substring(3);
      } else if (line.startsWith('LF:')) {
        found = int.parse(line.substring(3));
      } else if (line.startsWith('LH:')) {
        hit = int.parse(line.substring(3));
      } else if (line == 'end_of_record') {
        finishRecord();
      }
    }
    finishRecord();
    return CoverageReport(files);
  }

  int get found => files.values.fold(0, (total, value) => total + value.found);
  int get hit => files.values.fold(0, (total, value) => total + value.hit);
  double get percentage => found == 0 ? 0 : hit * 100 / found;

  FileCoverage? coverageFor(String path) => files[_normalizePath(path)];
}

String _normalizePath(String path) => path.replaceAll('\\', '/');

void main(List<String> arguments) {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run tool/check_coverage.dart <lcov> [minimum]');
    exitCode = 64;
    return;
  }

  final report = File(arguments.first);
  final minimum = arguments.length > 1 ? double.parse(arguments[1]) : 25.0;
  if (!report.existsSync()) {
    stderr.writeln('Coverage report not found: ${report.path}');
    exitCode = 66;
    return;
  }

  final coverage = CoverageReport.parse(report.readAsLinesSync());
  stdout.writeln(
    'Line coverage: ${coverage.percentage.toStringAsFixed(2)}% '
    '(${coverage.hit}/${coverage.found}), '
    'minimum: ${minimum.toStringAsFixed(2)}%',
  );
  var failed = coverage.percentage < minimum;

  for (final argument in arguments.skip(2)) {
    final separator = argument.lastIndexOf('=');
    if (separator <= 0 || separator == argument.length - 1) {
      stderr.writeln(
        'Invalid file threshold: $argument (expected path=minimum)',
      );
      exitCode = 64;
      return;
    }
    final path = _normalizePath(argument.substring(0, separator));
    final fileMinimum = double.parse(argument.substring(separator + 1));
    final fileCoverage = coverage.coverageFor(path);
    if (fileCoverage == null) {
      stderr.writeln('Critical file missing from coverage report: $path');
      failed = true;
      continue;
    }
    stdout.writeln(
      '$path: ${fileCoverage.percentage.toStringAsFixed(2)}% '
      '(${fileCoverage.hit}/${fileCoverage.found}), '
      'minimum: ${fileMinimum.toStringAsFixed(2)}%',
    );
    if (fileCoverage.percentage < fileMinimum) failed = true;
  }

  if (failed) exitCode = 1;
}
