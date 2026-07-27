import 'package:el_ahorrador/core/ai_notes_generator.dart';
import 'package:el_ahorrador/core/capture_validator.dart';
import 'package:el_ahorrador/core/fast_parser.dart';
import 'package:el_ahorrador/core/time_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptureValidator regressions', () {
    test('recognizes correctly encoded Spanish banking text', () {
      expect(
        CaptureValidator.validateCapture('Depósito recibido'),
        CaptureType.banco,
      );
      expect(
        CaptureValidator.validateCapture('Operación bancaria completada'),
        CaptureType.banco,
      );
      expect(CaptureValidator.validateCapture('¡Yapeaste!'), CaptureType.yape);
    });

    test('validation messages exist for every enum value', () {
      for (final type in CaptureType.values) {
        expect(CaptureValidator.getValidationMessage(type), isNotEmpty);
      }
    });
  });

  group('FastParser regressions', () {
    test(
      'parses decimal dot and comma without multiplying by one hundred',
      () async {
        final dot = await FastParser.fromOcr('Ticket local S/ 10.50');
        final comma = await FastParser.fromOcr('Ticket local PEN 10,50');
        expect(dot.amountCents, 1050);
        expect(comma.amountCents, 1050);
      },
    );

    test('parses thousands separators in both common formats', () async {
      final latin = await FastParser.fromOcr('Ticket local S/ 1.234,56');
      final english = await FastParser.fromOcr('Ticket local USD 1,234.56');
      expect(latin.amountCents, 123456);
      expect(english.amountCents, 123456);
    });

    test('normalizes two digit years and preserves OCR metadata', () async {
      final result = await FastParser.fromOcr(
        'Ticket local USD 8.25 09/07/26',
        fallbackDateEpoch: 1,
        ocrConfidence: '94',
      );
      expect(result.currency, 'USD');
      expect(result.dateEpochMs, DateTime(2026, 7, 9).millisecondsSinceEpoch);
      expect(result.ocrConfidence, '94');
    });

    test(
      'returns a safe empty result and exact fallback without an amount',
      () async {
        const fallback = 1700000000000;
        final result = await FastParser.fromOcr(
          'un recibo sin importe',
          fallbackDateEpoch: fallback,
          ocrConfidence: 'low',
        );
        expect(result.amountCents, 0);
        expect(result.currency, 'PEN');
        expect(result.dateEpochMs, fallback);
        expect(result.ocrConfidence, 'low');
      },
    );
  });

  group('TimeTracker', () {
    setUp(TimeTracker.reset);
    tearDown(TimeTracker.reset);

    test('starts empty and exposes stable manual baselines', () {
      expect(TimeTracker.getTotalProcessingTime(), isNull);
      expect(TimeTracker.getProcessingTime(), isNull);
      expect(TimeTracker.getTimeSavedVsManual(), isNull);
      expect(
        TimeTracker.getManualRegistrationTime(),
        const Duration(seconds: 75),
      );
      expect(
        TimeTracker.getDelayedRegistrationTime(),
        const Duration(seconds: 290),
      );
      expect(
        TimeTracker.generateTimeSavedMessage(),
        'Tiempo de procesamiento: N/A',
      );
    });

    test('formats boundary durations', () {
      expect(TimeTracker.formatDuration(const Duration(seconds: 59)), '59s');
      expect(TimeTracker.formatDuration(const Duration(seconds: 60)), '1m');
      expect(TimeTracker.formatDuration(const Duration(seconds: 125)), '2m 5s');
      expect(TimeTracker.formatDuration(const Duration(hours: 1)), '1h');
      expect(
        TimeTracker.formatDuration(const Duration(hours: 2, minutes: 3)),
        '2h 3m',
      );
    });

    test(
      'completed tracking produces internally consistent statistics',
      () async {
        TimeTracker.startShareTracking();
        TimeTracker.startProcessing();
        await Future<void>.delayed(const Duration(milliseconds: 2));
        TimeTracker.endProcessing();
        final stats = TimeTracker.getStats();
        expect(stats['totalTime'], isA<int>());
        expect(stats['processingTime'], isA<int>());
        expect(
          stats['totalTime'],
          greaterThanOrEqualTo(stats['processingTime'] as int),
        );
        expect(stats['manualRegistrationTime'], 75000);
        expect(stats['delayedRegistrationTime'], 290000);
        expect(stats['totalTimeFormatted'], isNotNull);
        expect(
          TimeTracker.generateShortTimeSavedMessage(),
          contains('vs manual'),
        );
      },
    );
  });

  group('AINotesGenerator invariants', () {
    test('generated notes are bounded and include useful context', () {
      final note = AINotesGenerator.generateNote(
        category: 'Comida',
        subcategory: 'Restaurante',
        vendor: 'Mercado Central',
        amount: 80,
      );
      expect(note.split(RegExp(r'\s+')).length, lessThanOrEqualTo(15));
      expect(note, contains('Mercado Central'));
    });

    test('unknown categories safely fall back to a non-empty note', () {
      final note = AINotesGenerator.generateNote(category: 'No configurada');
      expect(note, isNotEmpty);
      expect(note.split(RegExp(r'\s+')).length, lessThanOrEqualTo(15));
    });
  });
}
