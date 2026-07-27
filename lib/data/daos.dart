import 'package:drift/drift.dart';
import 'app_database.dart';

extension CapturesDao on AppDatabase {
  Future<void> insertCapture({
    required String id,
    required String imagePath,
    String? sourceApp,
    String? hash,
  }) async {
    await into(captures).insert(CapturesCompanion.insert(
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imagePath: imagePath,
      sourceApp: Value(sourceApp),
      hash: Value(hash),
      status: 'PENDING',
    ));
  }

  Future<void> setProcessing(String id) =>
      (update(captures)..where((t) => t.id.equals(id)))
          .write(CapturesCompanion(status: Value('PROCESSING')));

  Future<void> setOcrResult(
      {required String id,
      required String text,
      String? confidence,
      String? metaJson}) async {
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
      (select(captures)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch().map(
        (rows) => rows.map((r) => CaptureModel.fromData(r)).toList(),
      );

  Future<List<CaptureWithOcr>> getAllCapturesWithOcr() async {
    final query = select(captures)..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
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
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(expenses).insert(ExpensesCompanion.insert(
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
      createdAt: now,
      updatedAt: now,
    ));
  }

  Stream<List<Expense>> watchExpenses() =>
      (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();
}

// Pequeño modelo de proyección para la UI (opcional)
class CaptureModel {
  final String id, imagePath, status;
  final String? ocrText, ocrConfidence;
  final int createdAt;
  CaptureModel({required this.id, required this.imagePath, required this.status, required this.createdAt, this.ocrText, this.ocrConfidence});
  factory CaptureModel.fromData(Capture d) =>
      CaptureModel(id: d.id, imagePath: d.imagePath, status: d.status, createdAt: d.createdAt, ocrText: d.ocrText, ocrConfidence: d.ocrConfidence);
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
