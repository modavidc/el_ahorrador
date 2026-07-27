import '../../../core/capture_validator.dart';
import '../../../core/ocr_engine.dart';
import '../../../core/parser.dart';

abstract interface class IncomingFileStore {
  Future<String> fingerprint(String sourcePath);

  Future<String> persist(String sourcePath);

  Future<String> materializeForRead(String storedPath);

  Future<void> releaseMaterialized(String path);

  Future<void> delete(String path);
}

abstract interface class CaptureRepository {
  Future<String?> findByFingerprint(String fingerprint);

  Future<void> createCapture({
    required String id,
    required String imagePath,
    required String fingerprint,
  });

  Future<void> deleteCapture(String captureId);

  Future<void> saveOcrResult({
    required String captureId,
    required String text,
    String? confidence,
    Map<String, dynamic> metadata = const {},
  });

  Future<void> createExpense({
    required String id,
    required String captureId,
    required ParsedExpense expense,
  });
}

typedef CaptureIdFactory = String Function();
typedef CaptureValidatorCallback = CaptureType Function(String text);
typedef ExpenseParser =
    Future<ParsedExpense> Function(
      String text, {
      int? fallbackDateEpoch,
      String? ocrConfidence,
    });

enum CaptureProcessingStage {
  fingerprinting,
  checkingDuplicate,
  persistingFile,
  creatingCapture,
  recognizingText,
  savingOcr,
  validating,
  parsing,
  creatingExpense,
}

sealed class CaptureProcessingState {
  const CaptureProcessingState();
}

final class CaptureIdle extends CaptureProcessingState {
  const CaptureIdle();
}

final class CaptureProcessing extends CaptureProcessingState {
  const CaptureProcessing(this.stage, {this.captureId});

  final CaptureProcessingStage stage;
  final String? captureId;
}

final class CaptureCompleted extends CaptureProcessingState {
  const CaptureCompleted(this.result);

  final CaptureSuccess result;
}

final class CaptureRejected extends CaptureProcessingState {
  const CaptureRejected(this.result);

  final CaptureResult result;
}

final class CaptureFailed extends CaptureProcessingState {
  const CaptureFailed(this.result);

  final CaptureFailure result;
}

sealed class CaptureResult {
  const CaptureResult();
}

final class CaptureSuccess extends CaptureResult {
  const CaptureSuccess({
    required this.captureId,
    required this.expenseId,
    required this.imagePath,
    required this.expense,
  });

  final String captureId;
  final String expenseId;
  final String imagePath;
  final ParsedExpense expense;
}

final class InvalidCapture extends CaptureResult {
  const InvalidCapture({required this.captureId, required this.type});

  final String captureId;
  final CaptureType type;
}

final class MissingAmount extends CaptureResult {
  const MissingAmount({required this.captureId, required this.expense});

  final String captureId;
  final ParsedExpense expense;
}

final class CaptureBusy extends CaptureResult {
  const CaptureBusy();
}

final class DuplicateCapture extends CaptureResult {
  const DuplicateCapture({
    required this.existingCaptureId,
    required this.fingerprint,
  });

  final String existingCaptureId;
  final String fingerprint;
}

final class CaptureFailure extends CaptureResult {
  const CaptureFailure({
    required this.stage,
    required this.error,
    required this.stackTrace,
    this.captureId,
  });

  final CaptureProcessingStage stage;
  final Object error;
  final StackTrace stackTrace;
  final String? captureId;
}

class SharedCaptureCoordinator {
  SharedCaptureCoordinator({
    required IncomingFileStore fileStore,
    required CaptureRepository repository,
    required OcrEngine ocr,
    required CaptureIdFactory newId,
    required CaptureValidatorCallback validate,
    required ExpenseParser parse,
    this.ocrTimeout = const Duration(seconds: 30),
    void Function(CaptureProcessingState state)? onStateChanged,
  }) : _fileStore = fileStore,
       _repository = repository,
       _ocr = ocr,
       _newId = newId,
       _validate = validate,
       _parse = parse,
       _onStateChanged = onStateChanged;

  final IncomingFileStore _fileStore;
  final CaptureRepository _repository;
  final OcrEngine _ocr;
  final CaptureIdFactory _newId;
  final CaptureValidatorCallback _validate;
  final ExpenseParser _parse;
  final Duration ocrTimeout;
  final void Function(CaptureProcessingState state)? _onStateChanged;

  CaptureProcessingState _state = const CaptureIdle();
  bool _isProcessing = false;

  CaptureProcessingState get state => _state;
  bool get isProcessing => _isProcessing;

  Future<CaptureResult> process(
    String sourcePath, {
    int? fallbackDateEpoch,
  }) async {
    if (_isProcessing) return const CaptureBusy();

    _isProcessing = true;
    String? captureId;
    String? persistedImagePath;
    String? materializedImagePath;
    var stage = CaptureProcessingStage.fingerprinting;

    try {
      _emit(CaptureProcessing(stage));
      final fingerprint = await _fileStore.fingerprint(sourcePath);

      stage = CaptureProcessingStage.checkingDuplicate;
      _emit(CaptureProcessing(stage));
      final existingCaptureId = await _repository.findByFingerprint(
        fingerprint,
      );
      if (existingCaptureId != null) {
        final result = DuplicateCapture(
          existingCaptureId: existingCaptureId,
          fingerprint: fingerprint,
        );
        _emit(CaptureRejected(result));
        return result;
      }

      stage = CaptureProcessingStage.persistingFile;
      _emit(CaptureProcessing(stage));
      final imagePath = await _fileStore.persist(sourcePath);
      persistedImagePath = imagePath;

      captureId = _newId();
      stage = CaptureProcessingStage.creatingCapture;
      _emit(CaptureProcessing(stage, captureId: captureId));
      await _repository.createCapture(
        id: captureId,
        imagePath: imagePath,
        fingerprint: fingerprint,
      );

      stage = CaptureProcessingStage.recognizingText;
      _emit(CaptureProcessing(stage, captureId: captureId));
      materializedImagePath = await _fileStore.materializeForRead(imagePath);
      final ocrResult = await _ocr
          .run(materializedImagePath)
          .timeout(ocrTimeout);
      await _fileStore.releaseMaterialized(materializedImagePath);
      materializedImagePath = null;
      final confidence = ocrResult.meta['confidence']?.toString();

      stage = CaptureProcessingStage.savingOcr;
      _emit(CaptureProcessing(stage, captureId: captureId));
      await _repository.saveOcrResult(
        captureId: captureId,
        text: ocrResult.text,
        confidence: confidence,
        metadata: ocrResult.meta,
      );

      stage = CaptureProcessingStage.validating;
      _emit(CaptureProcessing(stage, captureId: captureId));
      final captureType = _validate(ocrResult.text);
      if (!CaptureValidator.isProcessable(captureType)) {
        final result = InvalidCapture(captureId: captureId, type: captureType);
        _emit(CaptureRejected(result));
        return result;
      }

      stage = CaptureProcessingStage.parsing;
      _emit(CaptureProcessing(stage, captureId: captureId));
      final expense = await _parse(
        ocrResult.text,
        fallbackDateEpoch: fallbackDateEpoch,
        ocrConfidence: confidence,
      );
      if (expense.amountCents <= 0) {
        final result = MissingAmount(captureId: captureId, expense: expense);
        _emit(CaptureRejected(result));
        return result;
      }

      final expenseId = _newId();
      stage = CaptureProcessingStage.creatingExpense;
      _emit(CaptureProcessing(stage, captureId: captureId));
      await _repository.createExpense(
        id: expenseId,
        captureId: captureId,
        expense: expense,
      );

      final result = CaptureSuccess(
        captureId: captureId,
        expenseId: expenseId,
        imagePath: imagePath,
        expense: expense,
      );
      _emit(CaptureCompleted(result));
      return result;
    } catch (error, stackTrace) {
      if (stage == CaptureProcessingStage.creatingExpense &&
          captureId != null) {
        var captureDeleted = false;
        try {
          await _repository.deleteCapture(captureId);
          captureDeleted = true;
        } catch (_) {
          // Preserve the expense failure as the actionable root cause.
        }
        // Never remove the file while a database row still references it.
        if (captureDeleted && persistedImagePath != null) {
          try {
            await _fileStore.delete(persistedImagePath);
          } catch (_) {
            // Preserve the expense failure as the actionable root cause.
          }
        }
      }
      if (stage == CaptureProcessingStage.creatingCapture &&
          persistedImagePath != null) {
        try {
          await _fileStore.delete(persistedImagePath);
        } catch (_) {
          // Preserve the repository failure as the actionable root cause.
        }
      }
      final result = CaptureFailure(
        stage: stage,
        error: error,
        stackTrace: stackTrace,
        captureId: captureId,
      );
      _emit(CaptureFailed(result));
      return result;
    } finally {
      if (materializedImagePath != null) {
        try {
          await _fileStore.releaseMaterialized(materializedImagePath);
        } catch (_) {
          // The original processing error remains the actionable failure.
        }
      }
      _isProcessing = false;
    }
  }

  void _emit(CaptureProcessingState state) {
    _state = state;
    _onStateChanged?.call(state);
  }
}
