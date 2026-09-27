import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/data/account_repository.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/features/capture/capture_rules.dart';
import 'package:el_ahorrador/features/capture/capture_service.dart';
import 'package:el_ahorrador/features/capture/receipt_reader.dart';
import 'package:el_ahorrador/features/ledger/ledger.dart';

import 'support/capture_fakes.dart';

void main() {
  final now = DateTime(2026, 9, 27, 21, 40);

  group('ReceiptReader', () {
    test('reads a sent Yape', () {
      final r = ReceiptReader.read(yapeSent, now: now);
      expect(r.isReceipt, isTrue);
      expect(r.direction, ReceiptDirection.sent);
      expect(r.source, ReceiptSource.yape);
      expect(r.amountCents, 2350);
      expect(r.counterpart, 'Bodega Don Lucho');
      expect(r.at, DateTime(2026, 9, 27, 21, 38));
      expect(r.operation, '04718822');
      expect(r.note, 'Yapeaste a Bodega Don Lucho');
    });

    test('a received Yape is income', () {
      final r = ReceiptReader.read(yapeReceived, now: now);
      expect(r.direction, ReceiptDirection.received);
      expect(r.amountCents, 45000);
      expect(r.note, 'Te yapearon · Juan Pérez');
    });

    test('bank card consumption with thousands', () {
      final r = ReceiptReader.read(bcpCard, now: now);
      expect(r.source, ReceiptSource.bcp);
      expect(r.amountCents, 123450);
      expect(r.counterpart, 'Saga Falabella');
      expect(r.at, DateTime(2026, 9, 15, 18, 20));
    });

    test('without an amount the merchant still follows the title', () {
      final r = ReceiptReader.read(yapeBlurry, now: now);
      expect(r.amountCents, isNull);
      expect(r.note, 'Yapeaste a Tambo');
    });

    test('a photo that is not a receipt', () {
      expect(ReceiptReader.read(selfie, now: now).isReceipt, isFalse);
    });
  });

  group('CaptureService', () {
    late AppDatabase db;
    late CaptureService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final accounts = AccountRepository(db);
      await accounts.create(
        name: 'Yape',
        groupId: AppDatabase.defaultAccountGroupId,
      );
      await accounts.create(
        name: 'BCP Soles',
        groupId: AppDatabase.defaultAccountGroupId,
      );
      service = CaptureService(
        db: db,
        ocr: FakeOcr(),
        storage: FakeStorage(),
        now: () => now,
      );
    });
    tearDown(() => db.close());

    Future<List<Movement>> movements() =>
        LedgerRepository(db).watchMovements().first;

    test('a sent Yape is registered as an expense on Yape', () async {
      final out = await service.process('sent');
      expect(out.status, CaptureStatus.registered);
      expect(out.draft!.ruleLabel, 'Regla “Yapeaste” → Gasto · Yape');
      final m = (await movements()).single;
      expect(m.type, MovementType.expense);
      expect(m.amountCents, 2350);
      expect(m.account, 'Yape');
      expect(m.category, 'Mercado');
      expect(m.note, 'Yapeaste a Bodega Don Lucho');
      expect(m.origin, MovementOrigin.shared);
      expect(m.ocrPercent, 97);
    });

    test('a received Yape is registered as income', () async {
      final out = await service.process('received');
      expect(out.status, CaptureStatus.registered);
      final m = (await movements()).single;
      expect(m.type, MovementType.income);
      expect(m.category, 'Extra');
      expect(m.account, 'Yape');
    });

    test('the same image or operation is a duplicate', () async {
      final first = await service.process('sent');
      final again = await service.process('sent');
      expect(again.status, CaptureStatus.duplicate);
      expect(again.originalMovementId, first.movementId);
      // A different file of the same receipt: same operation number.
      final copy = await service.process('sent#copy');
      expect(copy.status, CaptureStatus.duplicate);
      expect(await movements(), hasLength(1));
    });

    test('a deleted movement no longer blocks its receipt', () async {
      await service.process('sent');
      await LedgerRepository(db).delete((await movements()).single);
      expect((await service.process('sent')).status, CaptureStatus.registered);
    });

    test('missing category or amount goes to Por revisar', () async {
      final person = await service.process('person');
      expect(person.status, CaptureStatus.review);
      expect(person.draft!.why, 'Falta la categoría');
      final blurry = await service.process('blurry');
      expect(blurry.draft!.why, 'No se leyó el monto');
      expect(await movements(), isEmpty);

      final inbox = await service.watchInbox().first;
      expect(inbox, hasLength(2));
      final item = inbox.firstWhere((i) => i.captureId == person.captureId);
      await expectLater(service.approve(item), throwsArgumentError);
      await service.approve(item, category: 'Otros');
      expect((await movements()).single.category, 'Otros');

      final rest = (await service.watchInbox().first).single;
      await service.discard(rest);
      expect(await service.watchInbox().first, isEmpty);
    });

    test('bank account names resolve to the user account', () async {
      await service.process('bcp');
      final m = (await movements()).single;
      expect(m.account, 'BCP Soles');
      expect(m.category, 'Compras');
    });

    test('an image that is not a receipt is rejected', () async {
      final out = await service.process('selfie');
      expect(out.status, CaptureStatus.notReceipt);
      expect(await movements(), isEmpty);
    });

    test('rules can be edited', () async {
      final store = CaptureRuleStore(db);
      final rules = await store.load();
      await store.update(
        rules.first.copyWith(category: 'Comida', account: 'BCP'),
      );
      await service.process('person');
      final m = (await movements()).single;
      expect(m.category, 'Comida');
      expect(m.account, 'BCP Soles');
    });
  });
}
