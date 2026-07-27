import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/capture_validator.dart';
import '../../core/fast_parser.dart';
import '../../core/file_store.dart';
import '../../core/ocr_engine.dart';
import '../../core/parser.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';
import 'application/shared_capture_coordinator.dart';

export 'application/shared_capture_coordinator.dart';
export '../../core/parser.dart' show ParsedExpense;

/// Fachada de producciÃ³n del flujo de capturas compartidas.
///
/// Mantiene plugins e infraestructura fuera de la capa de presentaciÃ³n.
class SharedCaptureRuntime {
  SharedCaptureRuntime._({
    required SharedCaptureCoordinator coordinator,
    required MlKitEngine ocr,
    required StreamController<CaptureProcessingState> states,
  }) : _coordinator = coordinator,
       _ocr = ocr,
       _states = states;

  factory SharedCaptureRuntime.create(
    AppDatabase database, {
    void Function(CaptureProcessingState state)? onStateChanged,
  }) {
    final ocr = MlKitEngine();
    final states = StreamController<CaptureProcessingState>.broadcast();
    const uuid = Uuid();
    return SharedCaptureRuntime._(
      coordinator: SharedCaptureCoordinator(
        fileStore: const _ProductionFileStore(),
        repository: _DatabaseCaptureRepository(database),
        ocr: ocr,
        newId: uuid.v4,
        validate: CaptureValidator.validateCapture,
        parse: FastParser.fromOcr,
        onStateChanged: (state) {
          states.add(state);
          onStateChanged?.call(state);
        },
      ),
      ocr: ocr,
      states: states,
    );
  }

  final SharedCaptureCoordinator _coordinator;
  final MlKitEngine _ocr;
  final StreamController<CaptureProcessingState> _states;

  CaptureProcessingState get state => _coordinator.state;
  bool get isProcessing => _coordinator.isProcessing;

  /// Reactive source of truth consumed by the presentation layer.
  Stream<CaptureProcessingState> get states => _states.stream;

  Future<CaptureResult> process(String sourcePath, {int? fallbackDateEpoch}) =>
      _coordinator.process(sourcePath, fallbackDateEpoch: fallbackDateEpoch);

  Future<void> dispose() async {
    await _states.close();
    await _ocr.dispose();
  }
}

class _ProductionFileStore implements IncomingFileStore {
  const _ProductionFileStore();

  @override
  Future<String> fingerprint(String sourcePath) =>
      FileStore.sha256OfFile(sourcePath);

  @override
  Future<String> persist(String sourcePath) =>
      FileStore.persistIncomingFile(sourcePath);

  @override
  Future<String> materializeForRead(String storedPath) =>
      FileStore.materializeForRead(storedPath);

  @override
  Future<void> releaseMaterialized(String path) =>
      FileStore.releaseMaterializedFile(path);

  @override
  Future<void> delete(String path) => FileStore.securelyDelete(path);
}

class _DatabaseCaptureRepository implements CaptureRepository {
  const _DatabaseCaptureRepository(this._database);

  final AppDatabase _database;

  @override
  Future<String?> findByFingerprint(String fingerprint) =>
      _database.findCaptureIdByHash(fingerprint);

  @override
  Future<void> createCapture({
    required String id,
    required String imagePath,
    required String fingerprint,
  }) => _database.transaction(() async {
    await _database.insertCapture(
      id: id,
      imagePath: imagePath,
      hash: fingerprint,
    );
    await _database.setProcessing(id);
  });

  @override
  Future<void> deleteCapture(String captureId) =>
      _database.deleteCapture(captureId);

  @override
  Future<void> saveOcrResult({
    required String captureId,
    required String text,
    String? confidence,
    Map<String, dynamic> metadata = const {},
  }) => _database.setOcrResult(
    id: captureId,
    text: text,
    confidence: confidence,
    metaJson: jsonEncode(metadata),
  );

  @override
  Future<void> createExpense({
    required String id,
    required String captureId,
    required ParsedExpense expense,
  }) => _database.transaction(() async {
    // Parsers classify with human-readable labels, while SQLite stores stable
    // IDs. Resolve both values together so a subcategory can never belong to
    // a different category.
    final category = expense.category == null
        ? null
        : await (_database.select(_database.categories)
                ..where((row) => row.name.equals(expense.category!))
                ..limit(1))
              .getSingleOrNull();
    final subcategory = category == null || expense.subcategory == null
        ? null
        : await (_database.select(_database.subcategories)
                ..where((row) => row.categoryId.equals(category.id))
                ..where((row) => row.name.equals(expense.subcategory!))
                ..limit(1))
              .getSingleOrNull();

    await _database.insertExpenseFromParser(
      id: id,
      captureId: captureId,
      dateEpochMs: expense.dateEpochMs,
      amountCents: expense.amountCents,
      currency: expense.currency,
      categoryId: category?.id,
      subcategoryId: subcategory?.id,
      account: expense.account,
      vendor: expense.vendor,
      description: expense.description,
      notes: expense.notes,
      sourceApp: expense.sourceApp,
      transactionType: expense.origination,
    );
  });
}
