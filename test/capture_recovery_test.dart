import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('startup marks only interrupted OCR captures as failed', () async {
    await db.insertCapture(id: 'interrupted', imagePath: '/tmp/a.png');
    await db.setProcessing('interrupted');
    await db.insertCapture(id: 'pending', imagePath: '/tmp/b.png');
    await db.insertCapture(id: 'complete', imagePath: '/tmp/c.png');
    await db.setOcrResult(id: 'complete', text: 'ok');

    expect(await db.failInterruptedCaptures(), 1);

    final captures = {
      for (final capture in await db.getAllCapturesWithOcr())
        capture.id: capture.status,
    };
    expect(captures['interrupted'], 'FAILED');
    expect(captures['pending'], 'PENDING');
    expect(captures['complete'], 'PROCESSED');
  });

  test('recovery is idempotent on subsequent starts', () async {
    await db.insertCapture(id: 'capture', imagePath: '/tmp/a.png');
    await db.setProcessing('capture');

    expect(await db.failInterruptedCaptures(), 1);
    expect(await db.failInterruptedCaptures(), 0);
  });
}
