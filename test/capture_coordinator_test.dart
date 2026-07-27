import 'dart:async';

import 'package:el_ahorrador/core/capture_validator.dart';
import 'package:el_ahorrador/core/ocr_engine.dart';
import 'package:el_ahorrador/core/parser.dart';
import 'package:el_ahorrador/features/capture/application/shared_capture_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SharedCaptureCoordinator', () {
    test('persiste, reconoce, valida, parsea y crea el gasto', () async {
      final fixture = _Fixture();

      final result = await fixture.coordinator.process(
        '/incoming.png',
        fallbackDateEpoch: 123,
      );

      expect(result, isA<CaptureSuccess>());
      final success = result as CaptureSuccess;
      expect(success.captureId, 'id-1');
      expect(success.expenseId, 'id-2');
      expect(fixture.repository.createdImagePath, '/stored.png');
      expect(fixture.repository.createdFingerprint, 'sha256-image');
      expect(fixture.repository.savedOcrText, 'YAPE S/ 12.50');
      expect(fixture.repository.savedConfidence, '91');
      expect(fixture.repository.expense?.amountCents, 1250);
      expect(fixture.states.last, isA<CaptureCompleted>());
      expect(fixture.coordinator.isProcessing, isFalse);
    });

    test('double process creates one expense and skips repeated OCR', () async {
      final fixture = _Fixture();
      final first = await fixture.coordinator.process('/same.png');
      final second = await fixture.coordinator.process('/same.png');
      expect(first, isA<CaptureSuccess>());
      expect(second, isA<DuplicateCapture>());
      expect((second as DuplicateCapture).existingCaptureId, 'id-1');
      expect(fixture.ocr.calls, 1);
      expect(fixture.parseCalls, 1);
      expect(fixture.repository.captureCount, 1);
      expect(fixture.repository.expenseCount, 1);
    });

    test('captura invÃ¡lida guarda OCR pero no parsea ni crea gasto', () async {
      final fixture = _Fixture(type: CaptureType.invalid);

      final result = await fixture.coordinator.process('/incoming.png');

      expect(result, isA<InvalidCapture>());
      expect(fixture.repository.savedOcrText, isNotNull);
      expect(fixture.parseCalls, 0);
      expect(fixture.repository.expense, isNull);
    });

    test('monto ausente devuelve resultado explÃ­cito', () async {
      final fixture = _Fixture(amountCents: 0);

      final result = await fixture.coordinator.process('/incoming.png');

      expect(result, isA<MissingAmount>());
      expect(fixture.repository.expense, isNull);
    });

    test('fallo OCR identifica su etapa y libera el bloqueo', () async {
      final fixture = _Fixture(ocrError: StateError('OCR unavailable'));

      final result = await fixture.coordinator.process('/incoming.png');

      expect(result, isA<CaptureFailure>());
      expect(
        (result as CaptureFailure).stage,
        CaptureProcessingStage.recognizingText,
      );
      expect(fixture.coordinator.isProcessing, isFalse);
      expect(fixture.states.last, isA<CaptureFailed>());
    });

    test('fallo al persistir gasto identifica la etapa', () async {
      final fixture = _Fixture(expenseError: StateError('database full'));

      final result = await fixture.coordinator.process('/incoming.png');

      expect(result, isA<CaptureFailure>());
      expect(
        (result as CaptureFailure).stage,
        CaptureProcessingStage.creatingExpense,
      );
      expect(fixture.fileStore.deletedPaths, ['/stored.png']);
    });

    test('timeout OCR libera el bloqueo y permite otra operación', () async {
      final gate = Completer<OcrResult>();
      final fixture = _Fixture(
        ocrFuture: gate.future,
        ocrTimeout: Duration.zero,
      );

      final first = await fixture.coordinator.process('/first.png');

      expect(first, isA<CaptureFailure>());
      expect(
        (first as CaptureFailure).stage,
        CaptureProcessingStage.recognizingText,
      );
      expect(first.error, isA<TimeoutException>());
      expect(fixture.coordinator.isProcessing, isFalse);

      final second = await fixture.coordinator.process('/second.png');
      expect(second, isNot(isA<CaptureBusy>()));
    });

    test('fallo al crear captura elimina el archivo una vez', () async {
      final original = StateError('database unavailable');
      final fixture = _Fixture(captureError: original);

      final result = await fixture.coordinator.process('/incoming.png');

      expect(result, isA<CaptureFailure>());
      final failure = result as CaptureFailure;
      expect(failure.stage, CaptureProcessingStage.creatingCapture);
      expect(failure.error, same(original));
      expect(fixture.fileStore.deletedPaths, ['/stored.png']);
    });
    test(
      'fallo al crear gasto permite reintento sin captura duplicada',
      () async {
        final fixture = _Fixture(expenseError: StateError('database full'));

        final first = await fixture.coordinator.process('/incoming.png');
        expect(first, isA<CaptureFailure>());
        expect(fixture.repository.captureCount, 1);
        expect(fixture.fileStore.deletedPaths, ['/stored.png']);

        fixture.repository.expenseError = null;
        final second = await fixture.coordinator.process('/incoming.png');

        expect(second, isA<CaptureSuccess>());
        expect(fixture.repository.captureCount, 2);
        expect(fixture.repository.expenseCount, 1);
      },
    );
    test(
      'rechaza una segunda operaciÃ³n mientras la primera continÃºa',
      () async {
        final gate = Completer<OcrResult>();
        final fixture = _Fixture(ocrFuture: gate.future);

        final first = fixture.coordinator.process('/first.png');
        await Future<void>.delayed(Duration.zero);
        final second = await fixture.coordinator.process('/second.png');

        expect(second, isA<CaptureBusy>());
        gate.complete(OcrResult('YAPE S/ 12.50', {'confidence': 91}));
        expect(await first, isA<CaptureSuccess>());
      },
    );
  });
}

class _Fixture {
  _Fixture({
    this.type = CaptureType.yape,
    this.amountCents = 1250,
    Object? ocrError,
    Object? expenseError,
    Object? captureError,
    Future<OcrResult>? ocrFuture,
    Duration ocrTimeout = const Duration(seconds: 30),
  }) : repository = _Repository(
         expenseError: expenseError,
         captureError: captureError,
       ),
       ocr = _Ocr(error: ocrError, future: ocrFuture) {
    var sequence = 0;
    coordinator = SharedCaptureCoordinator(
      fileStore: fileStore,
      repository: repository,
      ocr: ocr,
      newId: () => 'id-${++sequence}',
      validate: (_) => type,
      parse: (text, {fallbackDateEpoch, ocrConfidence}) async {
        parseCalls++;
        return ParsedExpense(
          amountCents: amountCents,
          currency: 'PEN',
          dateEpochMs: fallbackDateEpoch ?? 456,
          sourceApp: 'Yape',
          ocrConfidence: ocrConfidence,
        );
      },
      ocrTimeout: ocrTimeout,
      onStateChanged: states.add,
    );
  }

  final CaptureType type;
  final int amountCents;
  final _Repository repository;
  final _FileStore fileStore = _FileStore();
  final _Ocr ocr;
  final states = <CaptureProcessingState>[];
  int parseCalls = 0;
  late final SharedCaptureCoordinator coordinator;
}

class _FileStore implements IncomingFileStore {
  final deletedPaths = <String>[];
  @override
  Future<String> fingerprint(String sourcePath) async => 'sha256-image';

  @override
  Future<String> persist(String sourcePath) async => '/stored.png';

  @override
  Future<String> materializeForRead(String storedPath) async => '/ocr.png';

  @override
  Future<void> releaseMaterialized(String path) async {}

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);
}

class _Ocr implements OcrEngine {
  _Ocr({this.error, this.future});

  final Object? error;
  final Future<OcrResult>? future;
  int calls = 0;

  @override
  Future<OcrResult> run(String imagePath) async {
    calls++;
    if (error case final error?) throw error;
    return future ?? OcrResult('YAPE S/ 12.50', {'confidence': 91});
  }
}

class _Repository implements CaptureRepository {
  _Repository({this.expenseError, this.captureError});

  Object? expenseError;
  final Object? captureError;
  String? createdImagePath;
  String? createdFingerprint;
  String? savedOcrText;
  String? savedConfidence;
  ParsedExpense? expense;
  final capturesByFingerprint = <String, String>{};
  int captureCount = 0;
  int expenseCount = 0;

  @override
  Future<String?> findByFingerprint(String fingerprint) async =>
      capturesByFingerprint[fingerprint];

  @override
  Future<void> createCapture({
    required String id,
    required String imagePath,
    required String fingerprint,
  }) async {
    if (captureError case final error?) throw error;
    createdImagePath = imagePath;
    createdFingerprint = fingerprint;
    capturesByFingerprint[fingerprint] = id;
    captureCount++;
  }

  @override
  Future<void> deleteCapture(String captureId) async {
    capturesByFingerprint.removeWhere((_, id) => id == captureId);
  }

  @override
  Future<void> saveOcrResult({
    required String captureId,
    required String text,
    String? confidence,
    Map<String, dynamic> metadata = const {},
  }) async {
    savedOcrText = text;
    savedConfidence = confidence;
  }

  @override
  Future<void> createExpense({
    required String id,
    required String captureId,
    required ParsedExpense expense,
  }) async {
    if (expenseError case final error?) throw error;
    this.expense = expense;
    expenseCount++;
  }
}
