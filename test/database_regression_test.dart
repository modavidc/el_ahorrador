import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('database integrity regressions', () {
    test(
      'capture hashes are unique while null hashes remain allowed',
      () async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);

        await _insertCapture(db, id: 'capture-1', hash: 'same-image');
        await _insertCapture(db, id: 'capture-without-hash-1');
        await _insertCapture(db, id: 'capture-without-hash-2');

        expect(
          () => _insertCapture(db, id: 'capture-2', hash: 'same-image'),
          throwsA(isA<SqliteException>()),
        );

        final captures = await db.select(db.captures).get();
        expect(captures, hasLength(3));
        expect(captures.where((row) => row.hash == null), hasLength(2));
      },
    );

    test('foreign keys reject expenses linked to missing captures', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      expect(
        () => db
            .into(db.expenses)
            .insert(
              ExpensesCompanion.insert(
                id: 'orphan-expense',
                captureId: const Value('missing-capture'),
                date: 1000,
                amountCents: 2500,
                createdAt: 1000,
                updatedAt: 1000,
              ),
            ),
        throwsA(isA<SqliteException>()),
      );
      expect(await db.select(db.expenses).get(), isEmpty);
    });

    test('OCR completion persists payload and processed status', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.insertCapture(id: 'capture-1', imagePath: '/capture.png');
      await db.setProcessing('capture-1');
      await db.setOcrResult(
        id: 'capture-1',
        text: 'Pago S/ 18.50',
        confidence: '{"score":0.97}',
        metaJson: '{"engine":"mlkit"}',
      );

      final capture = await (db.select(
        db.captures,
      )..where((row) => row.id.equals('capture-1'))).getSingle();
      expect(capture.status, 'PROCESSED');
      expect(capture.ocrText, 'Pago S/ 18.50');
      expect(capture.ocrConfidence, '{"score":0.97}');
      expect(capture.metaJson, '{"engine":"mlkit"}');
    });

    test(
      'v1 migration removes duplicate hash links without losing captures',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'hash_migration_',
        );
        final file = File('${directory.path}/database.sqlite');
        addTearDown(() => directory.delete(recursive: true));

        final original = AppDatabase.forTesting(NativeDatabase(file));
        await _insertCapture(original, id: 'capture-1', hash: 'duplicate-hash');
        await original.customStatement('DROP INDEX captures_hash_unique');
        await _insertCapture(original, id: 'capture-2', hash: 'duplicate-hash');
        await original.customStatement('PRAGMA user_version = 1');
        await original.close();

        final upgraded = AppDatabase.forTesting(NativeDatabase(file));
        addTearDown(upgraded.close);
        final captures = await upgraded.select(upgraded.captures).get();

        expect(captures, hasLength(2));
        expect(
          captures.where((row) => row.hash == 'duplicate-hash'),
          hasLength(1),
        );
        expect(captures.where((row) => row.hash == null), hasLength(1));
        expect(
          captures.map((row) => row.id),
          containsAll(['capture-1', 'capture-2']),
        );

        expect(
          () =>
              _insertCapture(upgraded, id: 'capture-3', hash: 'duplicate-hash'),
          throwsA(isA<SqliteException>()),
        );
      },
    );
  });
}

Future<void> _insertCapture(
  AppDatabase db, {
  required String id,
  String? hash,
}) {
  return db
      .into(db.captures)
      .insert(
        CapturesCompanion.insert(
          id: id,
          createdAt: 1000,
          imagePath: '/$id.png',
          hash: Value(hash),
          status: 'PENDING',
        ),
      );
}
