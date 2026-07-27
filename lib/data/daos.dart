import 'package:drift/drift.dart';
import 'app_database.dart';

extension CapturesDao on AppDatabase {
  Future<void> insertCapture({
    required String id,
    required String imagePath,
    String? sourceApp,
    String? hash,
  }) async {
    await into(captures).insert(
      CapturesCompanion.insert(
        id: id,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        imagePath: imagePath,
        sourceApp: Value(sourceApp),
        hash: Value(hash),
        status: 'PENDING',
      ),
    );
  }

  Future<String?> findCaptureIdByHash(String hash) async {
    final row =
        await (select(captures)
              ..where((capture) => capture.hash.equals(hash))
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<void> deleteCapture(String id) =>
      (delete(captures)..where((t) => t.id.equals(id))).go();

  Future<void> setProcessing(String id) =>
      (update(captures)..where((t) => t.id.equals(id))).write(
        CapturesCompanion(status: Value('PROCESSING')),
      );

  Future<void> setOcrResult({
    required String id,
    required String text,
    String? confidence,
    String? metaJson,
  }) async {
    await (update(captures)..where((t) => t.id.equals(id))).write(
      CapturesCompanion(
        ocrText: Value(text),
        ocrConfidence: Value(confidence),
        status: const Value('PROCESSED'),
        metaJson: Value(metaJson),
      ),
    );
  }

  Stream<List<CaptureModel>> watchCaptures() =>
      (select(captures)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch()
          .map((rows) => rows.map((r) => CaptureModel.fromData(r)).toList());

  Future<List<CaptureWithOcr>> getAllCapturesWithOcr() async {
    final query = select(captures)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    final rows = await query.get();
    return rows.map((r) => CaptureWithOcr.fromData(r)).toList();
  }

  Future<void> insertExpenseFromParser({
    required String id,
    String? captureId,
    required int dateEpochMs,
    required int amountCents,
    required String currency,
    String? categoryId,
    String? subcategoryId,
    String? account,
    String? vendor,
    String? description,
    String? notes,
    String? sourceApp,
    String? transactionType,
  }) async {
    _validateExpense(amountCents: amountCents, currency: currency);
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(expenses).insert(
      ExpensesCompanion.insert(
        id: id,
        captureId: Value(captureId),
        date: dateEpochMs,
        amountCents: amountCents,
        currency: Value(currency),
        categoryId: Value(categoryId),
        subcategoryId: Value(subcategoryId),
        account: Value(account),
        vendor: Value(vendor),
        description: Value(description),
        notes: Value(notes),
        sourceApp: Value(sourceApp),
        origination: Value(transactionType),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Stream<List<Expense>> watchExpenses() =>
      (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Future<void> updateExpenseFromParser({
    required String id,
    String? captureId,
    required int dateEpochMs,
    required int amountCents,
    required String currency,
    String? categoryId,
    String? subcategoryId,
    String? account,
    String? vendor,
    String? description,
    String? notes,
  }) async {
    _validateExpense(amountCents: amountCents, currency: currency);
    await (update(expenses)..where((row) => row.id.equals(id))).write(
      ExpensesCompanion(
        date: Value(dateEpochMs),
        amountCents: Value(amountCents),
        currency: Value(currency),
        categoryId: Value(categoryId),
        subcategoryId: Value(subcategoryId),
        account: Value(account),
        vendor: Value(vendor),
        description: Value(description),
        notes: Value(notes),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> deleteExpense(String id) async {
    await (delete(expenses)..where((row) => row.id.equals(id))).go();
  }

  /// Deletes an expense and its retained capture through a recoverable flow.
  /// DELETE_PENDING makes a crash after filesystem deletion safe to retry.
  Future<void> deleteExpenseWithCapture(
    String id, {
    required Future<void> Function(String path) deleteFile,
  }) async {
    final expense = await (select(
      expenses,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    final captureId = expense?.captureId;
    if (expense == null) return;
    if (captureId == null) {
      await deleteExpense(id);
      return;
    }

    final capture = await (select(
      captures,
    )..where((row) => row.id.equals(captureId))).getSingleOrNull();
    if (capture == null) {
      await deleteExpense(id);
      return;
    }

    final previousStatus = capture.status;
    await (update(captures)..where((row) => row.id.equals(captureId))).write(
      const CapturesCompanion(status: Value('DELETE_PENDING')),
    );
    try {
      await deleteFile(capture.imagePath);
    } catch (_) {
      await (update(captures)..where((row) => row.id.equals(captureId))).write(
        CapturesCompanion(status: Value(previousStatus)),
      );
      rethrow;
    }
    await transaction(() async {
      await (delete(expenses)..where((row) => row.id.equals(id))).go();
      await (delete(captures)..where((row) => row.id.equals(captureId))).go();
    });
  }

  /// Reconciles deletions interrupted after the durable pending marker.
  Future<void> purgePendingCaptureDeletions({
    required Future<void> Function(String path) deleteFile,
  }) async {
    final pending = await (select(
      captures,
    )..where((row) => row.status.equals('DELETE_PENDING'))).get();
    for (final capture in pending) {
      await deleteFile(capture.imagePath);
      await transaction(() async {
        await (delete(
          expenses,
        )..where((row) => row.captureId.equals(capture.id))).go();
        await (delete(
          captures,
        )..where((row) => row.id.equals(capture.id))).go();
      });
    }
  }
}

void _validateExpense({required int amountCents, required String currency}) {
  if (amountCents <= 0) {
    throw ArgumentError.value(amountCents, 'amountCents', 'must be positive');
  }
  if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
    throw ArgumentError.value(currency, 'currency', 'must be an ISO 4217 code');
  }
}

// PequeÃ±o modelo de proyecciÃ³n para la UI (opcional)
class CaptureModel {
  final String id, imagePath, status;
  final String? ocrText, ocrConfidence;
  final int createdAt;
  CaptureModel({
    required this.id,
    required this.imagePath,
    required this.status,
    required this.createdAt,
    this.ocrText,
    this.ocrConfidence,
  });
  factory CaptureModel.fromData(Capture d) => CaptureModel(
    id: d.id,
    imagePath: d.imagePath,
    status: d.status,
    createdAt: d.createdAt,
    ocrText: d.ocrText,
    ocrConfidence: d.ocrConfidence,
  );
}

// Modelo para capturas con OCR para debug
class CaptureWithOcr {
  final String id, imagePath, status;
  final String? ocrText, ocrConfidence, metaJson, sourceApp;
  final int createdAtEpochMs;

  CaptureWithOcr({
    required this.id,
    required this.imagePath,
    required this.status,
    required this.createdAtEpochMs,
    this.ocrText,
    this.ocrConfidence,
    this.metaJson,
    this.sourceApp,
  });

  factory CaptureWithOcr.fromData(Capture d) => CaptureWithOcr(
    id: d.id,
    imagePath: d.imagePath,
    status: d.status,
    createdAtEpochMs: d.createdAt,
    ocrText: d.ocrText,
    ocrConfidence: d.ocrConfidence,
    metaJson: d.metaJson,
    sourceApp: d.sourceApp,
  );
}
