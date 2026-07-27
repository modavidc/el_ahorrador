import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';

void main() {
  test('invalid monetary rows are rejected before persistence', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await expectLater(
      db.insertExpenseFromParser(
        id: 'invalid',
        dateEpochMs: 1,
        amountCents: 0,
        currency: 'soles',
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.expenses).get(), isEmpty);
  });

  test('editing an OCR expense updates the original row', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
    await db.insertExpenseFromParser(
      id: 'expense-1',
      captureId: 'capture-1',
      dateEpochMs: 1000,
      amountCents: 1500,
      currency: 'PEN',
    );

    await db.updateExpenseFromParser(
      id: 'expense-1',
      dateEpochMs: 2000,
      amountCents: 1750,
      currency: 'PEN',
      vendor: 'Comercio corregido',
    );

    final rows = await db.select(db.expenses).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'expense-1');
    expect(rows.single.amountCents, 1750);
    expect(rows.single.vendor, 'Comercio corregido');
    expect(rows.single.captureId, 'capture-1');
  });

  test('one capture cannot create two expenses', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
    await db.insertExpenseFromParser(
      id: 'expense-1',
      captureId: 'capture-1',
      dateEpochMs: 1000,
      amountCents: 1500,
      currency: 'PEN',
    );

    expect(
      () => db.insertExpenseFromParser(
        id: 'expense-2',
        captureId: 'capture-1',
        dateEpochMs: 1000,
        amountCents: 1500,
        currency: 'PEN',
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('coordinated deletion removes expense, capture and file', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertCapture(id: 'capture-1', imagePath: '/encrypted.eac');
    await db.insertExpenseFromParser(
      id: 'expense-1',
      captureId: 'capture-1',
      dateEpochMs: 1000,
      amountCents: 1500,
      currency: 'PEN',
    );
    final deleted = <String>[];

    await db.deleteExpenseWithCapture(
      'expense-1',
      deleteFile: (path) async => deleted.add(path),
    );

    expect(deleted, ['/encrypted.eac']);
    expect(await db.select(db.expenses).get(), isEmpty);
    expect(await db.select(db.captures).get(), isEmpty);
  });

  test(
    'failed file deletion restores capture state and accounting row',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await db.insertCapture(id: 'capture-1', imagePath: '/encrypted.eac');
      await db.insertExpenseFromParser(
        id: 'expense-1',
        captureId: 'capture-1',
        dateEpochMs: 1000,
        amountCents: 1500,
        currency: 'PEN',
      );

      await expectLater(
        db.deleteExpenseWithCapture(
          'expense-1',
          deleteFile: (_) async => throw const FileSystemException('denied'),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect((await db.select(db.expenses).get()).single.id, 'expense-1');
      expect((await db.select(db.captures).get()).single.status, 'PENDING');
    },
  );

  test('migration from v1 preserves accounting data', () async {
    final directory = await Directory.systemTemp.createTemp('ahorrador_db_');
    final file = File('${directory.path}/migration.sqlite');
    addTearDown(() => directory.delete(recursive: true));

    final original = AppDatabase.forTesting(NativeDatabase(file));
    await original.insertCapture(
      id: 'capture-before-upgrade',
      imagePath: '/capture.png',
    );
    await original.insertExpenseFromParser(
      id: 'expense-before-upgrade',
      captureId: 'capture-before-upgrade',
      dateEpochMs: 1000,
      amountCents: 9900,
      currency: 'PEN',
    );
    await original.customStatement('DROP INDEX captures_hash_unique');
    await original.customStatement('DROP INDEX expenses_capture_id_unique');
    await original.insertExpenseFromParser(
      id: 'duplicate-created-by-v1',
      captureId: 'capture-before-upgrade',
      dateEpochMs: 1001,
      amountCents: 9900,
      currency: 'PEN',
    );
    await original.customStatement('PRAGMA user_version = 1');
    await original.close();

    final upgraded = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(upgraded.close);
    final expenses = await upgraded.select(upgraded.expenses).get();
    final captures = await upgraded.select(upgraded.captures).get();

    expect(expenses, hasLength(2));
    expect(expenses.map((row) => row.id), contains('expense-before-upgrade'));
    expect(expenses.every((row) => row.amountCents == 9900), isTrue);
    expect(expenses.where((row) => row.captureId != null), hasLength(1));
    expect(captures.single.id, 'capture-before-upgrade');
  });
}
