import 'package:drift/native.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('CapturesDao', () {
    test('persists capture fields and resolves its hash', () async {
      await db.insertCapture(
        id: 'capture-1',
        imagePath: '/private/capture-1.png',
        sourceApp: 'Yape',
        hash: 'sha256-1',
      );

      final capture = await db.select(db.captures).getSingle();
      expect(capture.id, 'capture-1');
      expect(capture.imagePath, '/private/capture-1.png');
      expect(capture.sourceApp, 'Yape');
      expect(capture.hash, 'sha256-1');
      expect(capture.status, 'PENDING');
      expect(capture.createdAt, greaterThan(0));
      expect(await db.findCaptureIdByHash('sha256-1'), 'capture-1');
      expect(await db.findCaptureIdByHash('missing'), isNull);
    });

    test('watchCaptures emits inserts and OCR updates', () async {
      final emissions = <List<CaptureModel>>[];
      final subscription = db.watchCaptures().listen(emissions.add);
      addTearDown(subscription.cancel);

      await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
      await db.setProcessing('capture-1');
      await db.setOcrResult(
        id: 'capture-1',
        text: 'Pago S/ 25.90',
        confidence: '{"score":0.96}',
        metaJson: '{"engine":"mlkit"}',
      );

      await expectLater(
        db.watchCaptures(),
        emits(
          isA<List<CaptureModel>>()
              .having((rows) => rows, 'rows', hasLength(1))
              .having((rows) => rows.single.status, 'status', 'PROCESSED')
              .having((rows) => rows.single.ocrText, 'ocrText', 'Pago S/ 25.90')
              .having(
                (rows) => rows.single.ocrConfidence,
                'ocrConfidence',
                '{"score":0.96}',
              ),
        ),
      );
      expect(emissions, isNotEmpty);

      final projected = await db.getAllCapturesWithOcr();
      expect(projected.single.id, 'capture-1');
      expect(projected.single.status, 'PROCESSED');
      expect(projected.single.ocrText, 'Pago S/ 25.90');
      expect(projected.single.ocrConfidence, '{"score":0.96}');
      expect(projected.single.metaJson, '{"engine":"mlkit"}');
    });
  });

  group('ExpensesDao', () {
    test('persists every parser field', () async {
      await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
      await _insertClassification(db, 'food', 'restaurants');
      await db.insertExpenseFromParser(
        id: 'expense-1',
        captureId: 'capture-1',
        dateEpochMs: 1700000000000,
        amountCents: 2590,
        currency: 'PEN',
        categoryId: 'food',
        subcategoryId: 'restaurants',
        account: 'BCP',
        vendor: 'Cafeteria',
        description: 'Almuerzo',
        notes: 'Con propina',
        sourceApp: 'Yape',
        transactionType: 'expense',
      );

      final expense = await db.select(db.expenses).getSingle();
      expect(expense.id, 'expense-1');
      expect(expense.captureId, 'capture-1');
      expect(expense.date, 1700000000000);
      expect(expense.amountCents, 2590);
      expect(expense.currency, 'PEN');
      expect(expense.categoryId, 'food');
      expect(expense.subcategoryId, 'restaurants');
      expect(expense.account, 'BCP');
      expect(expense.vendor, 'Cafeteria');
      expect(expense.description, 'Almuerzo');
      expect(expense.notes, 'Con propina');
      expect(expense.sourceApp, 'Yape');
      expect(expense.origination, 'expense');
      expect(expense.createdAt, greaterThan(0));
      expect(expense.updatedAt, greaterThan(0));
    });

    test('watchExpenses orders by date and emits changes', () async {
      await db.insertExpenseFromParser(
        id: 'older',
        dateEpochMs: 1000,
        amountCents: 100,
        currency: 'PEN',
      );
      await db.insertExpenseFromParser(
        id: 'newer',
        dateEpochMs: 2000,
        amountCents: 200,
        currency: 'PEN',
      );

      await expectLater(
        db.watchExpenses(),
        emits(
          isA<List<Expense>>()
              .having((rows) => rows.map((row) => row.id), 'order', [
                'newer',
                'older',
              ]),
        ),
      );
    });

    test('updates editable fields, preserves origin, and deletes by id', () async {
      await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
      await _insertClassification(db, 'transport', 'taxi');
      await db.insertExpenseFromParser(
        id: 'expense-1',
        captureId: 'capture-1',
        dateEpochMs: 1000,
        amountCents: 100,
        currency: 'USD',
        sourceApp: 'Yape',
        transactionType: 'expense',
      );
      final original = await db.select(db.expenses).getSingle();

      await db.updateExpenseFromParser(
        id: 'expense-1',
        captureId: null,
        dateEpochMs: 2000,
        amountCents: 350,
        currency: 'PEN',
        categoryId: 'transport',
        subcategoryId: 'taxi',
        account: 'Efectivo',
        vendor: 'Taxi',
        description: 'Traslado',
        notes: 'Editado',
      );

      final updated = await db.select(db.expenses).getSingle();
      expect(updated.date, 2000);
      expect(updated.amountCents, 350);
      expect(updated.currency, 'PEN');
      expect(updated.categoryId, 'transport');
      expect(updated.subcategoryId, 'taxi');
      expect(updated.account, 'Efectivo');
      expect(updated.vendor, 'Taxi');
      expect(updated.description, 'Traslado');
      expect(updated.notes, 'Editado');
      expect(updated.captureId, 'capture-1');
      expect(updated.sourceApp, 'Yape');
      expect(updated.origination, 'expense');
      expect(updated.createdAt, original.createdAt);
      expect(updated.updatedAt, greaterThanOrEqualTo(original.updatedAt));

      await db.deleteExpense('expense-1');
      expect(await db.select(db.expenses).get(), isEmpty);
    });
  });
}

Future<void> _insertClassification(
  AppDatabase db,
  String categoryId,
  String subcategoryId,
) async {
  await db.into(db.categories).insert(CategoriesCompanion.insert(
        id: categoryId,
        name: categoryId,
        icon: 'test',
        color: 'test',
        order: 0,
        createdAt: 1000,
        updatedAt: 1000,
      ));
  await db.into(db.subcategories).insert(SubcategoriesCompanion.insert(
        id: subcategoryId,
        categoryId: categoryId,
        name: subcategoryId,
        order: 0,
        createdAt: 1000,
        updatedAt: 1000,
      ));
}
