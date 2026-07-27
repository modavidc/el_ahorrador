import 'package:el_ahorrador/core/time_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(TimeTracker.reset);
  tearDown(TimeTracker.reset);

  group('TimeTracker lifecycle', () {
    test('is safe before tracking has started', () {
      expect(TimeTracker.getTotalProcessingTime(), isNull);
      expect(TimeTracker.getProcessingTime(), isNull);
      expect(TimeTracker.getTimeSavedVsManual(), isNull);
      expect(
        TimeTracker.generateTimeSavedMessage(),
        'Tiempo de procesamiento: N/A',
      );

      final stats = TimeTracker.getStats();
      expect(stats['totalTime'], isNull);
      expect(stats['processingTime'], isNull);
      expect(stats['timeSavedVsManual'], isNull);
      expect(stats['manualRegistrationTime'], 75000);
      expect(stats['delayedRegistrationTime'], 290000);
    });

    test(
      'records a complete capture lifecycle and exposes consistent stats',
      () {
        TimeTracker.startShareTracking();
        TimeTracker.startProcessing();
        TimeTracker.endProcessing();

        final total = TimeTracker.getTotalProcessingTime();
        final processing = TimeTracker.getProcessingTime();
        expect(total, isNotNull);
        expect(processing, isNotNull);
        expect(total!.isNegative, isFalse);
        expect(processing!.isNegative, isFalse);
        expect(total, greaterThanOrEqualTo(processing));

        final stats = TimeTracker.getStats();
        final statsTotalMs = stats['totalTime'] as int;
        final statsProcessingMs = stats['processingTime'] as int;
        expect(statsTotalMs, greaterThanOrEqualTo(total.inMilliseconds));
        expect(
          statsProcessingMs,
          greaterThanOrEqualTo(processing.inMilliseconds),
        );
        expect(stats['timeSavedVsManual'], closeTo(75000 - statsTotalMs, 1));
        expect(stats['timeSavedVsDelayed'], closeTo(290000 - statsTotalMs, 1));
        expect(
          stats['totalTimeFormatted'],
          TimeTracker.formatDuration(Duration(milliseconds: statsTotalMs)),
        );
      },
    );

    test('reset removes all timestamps after a completed run', () {
      TimeTracker.startShareTracking();
      TimeTracker.startProcessing();
      TimeTracker.endProcessing();
      TimeTracker.reset();

      expect(TimeTracker.getTotalProcessingTime(), isNull);
      expect(TimeTracker.getProcessingTime(), isNull);
      expect(
        TimeTracker.generateShortTimeSavedMessage(),
        'Tiempo ahorrado: N/A',
      );
    });
  });

  group('duration formatting boundaries', () {
    test('formats seconds, minutes and hours without unstable fractions', () {
      expect(
        TimeTracker.formatDuration(const Duration(milliseconds: 999)),
        '0s',
      );
      expect(TimeTracker.formatDuration(const Duration(seconds: 59)), '59s');
      expect(TimeTracker.formatDuration(const Duration(seconds: 60)), '1m');
      expect(TimeTracker.formatDuration(const Duration(seconds: 61)), '1m 1s');
      expect(
        TimeTracker.formatDuration(const Duration(minutes: 59, seconds: 59)),
        '59m 59s',
      );
      expect(TimeTracker.formatDuration(const Duration(hours: 1)), '1h');
      expect(
        TimeTracker.formatDuration(const Duration(hours: 2, minutes: 5)),
        '2h 5m',
      );
    });
  });
}
