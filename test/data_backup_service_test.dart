import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:el_ahorrador/data/data_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup round-trip restores every accounting relationship', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);

    await source.insertCapture(
      id: 'capture-1',
      imagePath: '/encrypted.eac',
      hash: 'unique-hash',
    );
    await source.insertExpenseFromParser(
      id: 'expense-1',
      captureId: 'capture-1',
      dateEpochMs: 1234,
      amountCents: 2590,
      currency: 'PEN',
      categoryId: 'cat_1',
      subcategoryId: 'sub_9',
      vendor: 'Restaurante',
    );

    final backup = await DataBackupService(source).createBackup();
    await DataBackupService(target).restoreBackup(backup);

    final expenses = await target.select(target.expenses).get();
    final captures = await target.select(target.captures).get();
    expect(expenses.single.id, 'expense-1');
    expect(expenses.single.captureId, captures.single.id);
    expect(expenses.single.categoryId, 'cat_1');
    expect(expenses.single.subcategoryId, 'sub_9');
  });

  test('tampered backup is rejected before existing data changes', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertExpenseFromParser(
      id: 'keep-me',
      dateEpochMs: 1,
      amountCents: 100,
      currency: 'PEN',
    );
    final envelope =
        jsonDecode(await DataBackupService(db).createBackup())
            as Map<String, dynamic>;
    final payload = envelope['payload'] as Map<String, dynamic>;
    (payload['expenses'] as List).clear();

    await expectLater(
      DataBackupService(db).restoreBackup(jsonEncode(envelope)),
      throwsA(isA<FormatException>()),
    );
    expect((await db.select(db.expenses).get()).single.id, 'keep-me');
  });

  test('invalid relationships roll back the complete restore', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.insertExpenseFromParser(
      id: 'keep-me',
      dateEpochMs: 1,
      amountCents: 100,
      currency: 'PEN',
    );
    final envelope =
        jsonDecode(await DataBackupService(db).createBackup())
            as Map<String, dynamic>;
    final payload = envelope['payload'] as Map<String, dynamic>;
    final expense =
        (payload['expenses'] as List).single as Map<String, dynamic>;
    expense['categoryId'] = 'missing-category';
    envelope['checksum'] = sha256
        .convert(utf8.encode(jsonEncode(payload)))
        .toString();

    await expectLater(
      DataBackupService(db).restoreBackup(jsonEncode(envelope)),
      throwsA(anything),
    );
    expect((await db.select(db.expenses).get()).single.id, 'keep-me');
  });

  test('encrypted backup round-trip requires the correct password', () async {
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    final target = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(source.close);
    addTearDown(target.close);
    await source.insertExpenseFromParser(
      id: 'private-expense',
      dateEpochMs: 1,
      amountCents: 500,
      currency: 'PEN',
      notes: 'sensitive note',
    );
    final encrypted = await DataBackupService(
      source,
    ).createEncryptedBackup('correct horse battery staple');
    expect(encrypted, isNot(contains('sensitive note')));

    await expectLater(
      DataBackupService(
        target,
      ).restoreEncryptedBackup(encrypted, 'incorrect password'),
      throwsA(isA<FormatException>()),
    );
    expect(await target.select(target.expenses).get(), isEmpty);

    await DataBackupService(
      target,
    ).restoreEncryptedBackup(encrypted, 'correct horse battery staple');
    expect(
      (await target.select(target.expenses).get()).single.id,
      'private-expense',
    );
  });
}
