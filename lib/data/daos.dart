import 'package:drift/drift.dart';
import 'app_database.dart';

class ExpenseWithLabels {
  const ExpenseWithLabels({
    required this.expense,
    this.categoryName,
    this.subcategoryName,
  });

  final Expense expense;
  final String? categoryName;
  final String? subcategoryName;
}

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

  Future<void> setProcessing(String id) =>
      (update(captures)..where((t) => t.id.equals(id))).write(
        CapturesCompanion(status: Value('PROCESSING')),
      );

  Future<void> setFailed(String id) =>
      (update(captures)..where((t) => t.id.equals(id))).write(
        const CapturesCompanion(status: Value('FAILED')),
      );

  /// A PROCESSING row cannot belong to the new process: OCR runs in memory and
  /// Android does not resume that Future after killing the application.
  Future<int> failInterruptedCaptures() =>
      (update(captures)..where((t) => t.status.equals('PROCESSING'))).write(
        const CapturesCompanion(status: Value('FAILED')),
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
    String? accountId,
    String? vendor,
    String? description,
    String? notes,
    String? sourceApp,
    String? source,
    String? destination,
    String? origination,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final resolvedCategory = categoryId == null
        ? null
        : await (select(categories)..where(
                (row) =>
                    row.id.equals(categoryId) | row.name.equals(categoryId),
              ))
              .getSingleOrNull();
    final resolvedSubcategory =
        subcategoryId == null || resolvedCategory == null
        ? null
        : await (select(subcategories)..where(
                (row) =>
                    row.categoryId.equals(resolvedCategory.id) &
                    (row.id.equals(subcategoryId) |
                        row.name.equals(subcategoryId)),
              ))
              .getSingleOrNull();
    accountId ??= (await (select(
      accounts,
    )..where((row) => row.isDefault.equals(true))).getSingle()).id;
    await into(expenses).insert(
      ExpensesCompanion.insert(
        id: id,
        captureId: Value(captureId),
        date: dateEpochMs,
        amountCents: amountCents,
        currency: Value(currency),
        categoryId: Value(resolvedCategory?.id),
        subcategoryId: Value(resolvedSubcategory?.id),
        account: Value(account),
        accountId: Value(accountId),
        vendor: Value(vendor),
        description: Value(description),
        notes: Value(notes),
        sourceApp: Value(sourceApp),
        source: Value(source),
        destination: Value(destination),
        origination: Value(origination),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// Persists a transfer as two linked ledger entries. The outgoing entry is
  /// negative and the incoming entry is positive, so the transfer is neutral
  /// in the combined balance while remaining visible on each account.
  Future<void> insertTransfer({
    required String id,
    required int dateEpochMs,
    required int amountCents,
    required String currency,
    required String sourceAccountId,
    required String destinationAccountId,
    String? sourceAccount,
    String? destinationAccount,
    String? description,
    String? notes,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError.value(amountCents, 'amountCents', 'must be positive');
    }
    if (sourceAccountId == destinationAccountId) {
      throw ArgumentError('Source and destination accounts must be different');
    }

    final transferId = id;
    await transaction(() async {
      await insertExpenseFromParser(
        id: '${id}_out',
        dateEpochMs: dateEpochMs,
        amountCents: -amountCents,
        currency: currency,
        accountId: sourceAccountId,
        vendor: 'Transferencia',
        description: description,
        notes: notes,
        sourceApp: 'Manual',
        source: sourceAccount,
        destination: destinationAccount,
        origination: transferId,
      );
      await insertExpenseFromParser(
        id: '${id}_in',
        dateEpochMs: dateEpochMs,
        amountCents: amountCents,
        currency: currency,
        accountId: destinationAccountId,
        vendor: 'Transferencia',
        description: description,
        notes: notes,
        sourceApp: 'Manual',
        source: sourceAccount,
        destination: destinationAccount,
        origination: transferId,
      );
    });
  }

  Stream<List<Expense>> watchExpenses() =>
      (select(expenses)..orderBy([(t) => OrderingTerm.desc(t.date)])).watch();

  Stream<List<ExpenseWithLabels>> watchExpensesWithLabels() {
    final query = select(expenses).join([
      leftOuterJoin(categories, categories.id.equalsExp(expenses.categoryId)),
      leftOuterJoin(
        subcategories,
        subcategories.id.equalsExp(expenses.subcategoryId),
      ),
    ])..orderBy([OrderingTerm.desc(expenses.date)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => ExpenseWithLabels(
              expense: row.readTable(expenses),
              categoryName: row.readTableOrNull(categories)?.name,
              subcategoryName: row.readTableOrNull(subcategories)?.name,
            ),
          )
          .toList(),
    );
  }

  Future<int> updateExpenseFromParser({
    required String id,
    required int dateEpochMs,
    required int amountCents,
    required String currency,
    String? categoryId,
    String? subcategoryId,
    String? account,
    String? accountId,
    String? vendor,
    String? description,
    String? notes,
  }) => (update(expenses)..where((row) => row.id.equals(id))).write(
    ExpensesCompanion(
      date: Value(dateEpochMs),
      amountCents: Value(amountCents),
      currency: Value(currency),
      categoryId: Value(categoryId),
      subcategoryId: Value(subcategoryId),
      account: Value(account),
      accountId: accountId == null ? const Value.absent() : Value(accountId),
      vendor: Value(vendor),
      description: Value(description),
      notes: Value(notes),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ),
  );

  Future<int> deleteExpense(String id) =>
      (delete(expenses)..where((row) => row.id.equals(id))).go();
}

// Pequeño modelo de proyección para la UI (opcional)
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
