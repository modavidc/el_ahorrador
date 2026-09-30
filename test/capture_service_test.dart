import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_records.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_rule_repository.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';

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

    test('reads the message, recipient, phone and operation of a Yape', () {
      final r = ReceiptReader.read(yapeWithMessage, now: now);
      expect(r.direction, ReceiptDirection.sent);
      expect(r.amountCents, 200);
      expect(r.counterpart, 'Carla Nue');
      expect(r.message, 'pasaje bus');
      expect(r.counterpartPhone, '281');
      expect(r.operation, '23760001');
      expect(r.at, DateTime(2026, 9, 29, 17, 33));
      expect(r.note, 'Yapeaste a Carla Nue');
    });

    test('the same Yape read column by column', () {
      final r = ReceiptReader.read(yapeColumns, now: now);
      expect(r.amountCents, 1200);
      expect(r.counterpart, 'Luis Paz');
      expect(r.message, 'almuerzo menu lomo saltado');
      expect(r.counterpartPhone, '810');
      expect(r.operation, '26520002');
      expect(r.at, DateTime(2026, 9, 29, 18, 41));
    });

    test('a Yape without a message', () {
      final r = ReceiptReader.read(yapeNoMessage, now: now);
      expect(r.amountCents, 1000);
      expect(r.counterpart, 'Ana Ruiz');
      expect(r.message, isNull);
      expect(r.counterpartPhone, '257');
      expect(r.operation, '33940003');
    });

    test('a phone is never taken for the operation number', () {
      const text = '''
Operación exitosa
S/ 80
Celular
987654321
''';
      final r = ReceiptReader.read(text, now: now);
      expect(r.operation, isNull);
      expect(r.counterpartPhone, '321');
    });

    test('BCP paying a Plin user, with its message', () {
      final r = ReceiptReader.read(bcpToPlin, now: now);
      expect(r.source, ReceiptSource.bcp);
      expect(r.via, ReceiptSource.plin);
      expect(r.direction, ReceiptDirection.sent);
      expect(r.amountCents, 100);
      expect(r.at, DateTime(2026, 9, 29, 19, 57));
      expect(r.counterpart, 'Lucia Fernanda Paz Rojas');
      expect(r.message, 'Prueba comida');
      expect(r.counterpartPhone, isNull);
      expect(r.operation, '06080001');
      expect(r.note, 'Plin a Lucia Fernanda Paz Rojas');
    });

    test('Interbank Plin: wrapped name, full phone, no message', () {
      final r = ReceiptReader.read(interbankPlin, now: now);
      expect(r.source, ReceiptSource.interbank);
      expect(r.via, ReceiptSource.plin);
      expect(r.amountCents, 101);
      expect(r.at, DateTime(2026, 9, 29, 20, 5));
      expect(r.counterpart, 'Lucia Fernanda Paz R Ojas Torres');
      expect(r.counterpartPhone, '321');
      expect(r.message, isNull);
      expect(r.operation, '01120002');
    });

    test('older receipts have no message or phone', () {
      final r = ReceiptReader.read(yapeSent, now: now);
      expect(r.message, isNull);
      expect(r.counterpartPhone, isNull);
      expect(ReceiptReader.read(bcpCard, now: now).message, isNull);
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
        ocr: FakeOcr(),
        images: FakeStorage(),
        records: DriftCaptureRecords(db),
        rules: DriftCaptureRuleRepository(db),
        ledger: DriftLedgerRepository(db),
        now: () => now,
      );
    });
    tearDown(() => db.close());

    Future<List<Movement>> movements() =>
        DriftLedgerRepository(db).watchMovements().first;

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

    test('keeps the recipient, phone, message and operation', () async {
      final out = await service.process('columns');
      expect(out.status, CaptureStatus.registered);
      final m = (await movements()).single;
      expect(m.category, 'Comida');
      expect(m.note, 'Yapeaste a Luis Paz');
      expect(m.details.counterpart, 'Luis Paz');
      expect(m.details.counterpartPhone, '810');
      expect(m.details.message, 'almuerzo menu lomo saltado');
      expect(m.details.operation, '26520002');
      final row = await db.select(db.expenses).getSingle();
      expect(row.vendor, 'Luis Paz');
      expect(row.message, 'almuerzo menu lomo saltado');
    });

    test('"pasaje bus" registers the Yape in Transporte', () async {
      final out = await service.process('message');
      expect(out.status, CaptureStatus.registered);
      final m = (await movements()).single;
      expect(m.category, 'Transporte');
      expect(m.details.counterpart, 'Carla Nue');
      expect(m.details.counterpartPhone, '281');
      expect(m.details.message, 'pasaje bus');
      expect(m.details.operation, '23760001');
    });

    test('Por revisar keeps the receipt details until approved', () async {
      final out = await service.process('interbankPlin');
      expect(out.status, CaptureStatus.review);
      final item = (await service.watchInbox().first).single;
      await service.approve(item, category: 'Casa');
      final m = (await movements()).single;
      expect(m.category, 'Casa');
      expect(m.details.counterpart, 'Lucia Fernanda Paz R Ojas Torres');
      expect(m.details.counterpartPhone, '321');
      expect(m.details.operation, '01120002');
    });

    test('a letter as the Yape message registers it in its category', () async {
      final out = await service.process('letter');
      expect(out.status, CaptureStatus.registered);
      final m = (await movements()).single;
      expect(m.category, 'Comida');
      expect(m.details.message, 'C');
      expect(m.details.counterpart, 'Pedro Soto');
    });

    test('the user\'s letters decide, and without a letter it waits', () async {
      final ledger = DriftLedgerRepository(db);
      await ledger.setCategoryLetters(
        CategoryLetters.defaults.assign(Category.ocio, 'C'),
      );
      await service.process('letter');
      expect((await movements()).single.category, 'Ocio');

      await ledger.setCategoryLetters(const CategoryLetters({}));
      final out = await service.process('interbankPlin');
      expect(out.status, CaptureStatus.review);
      expect(out.draft!.why, 'Falta la categoría');
    });

    test('a known word in the message picks the category', () async {
      final out = await service.process('bcpPlin');
      expect(out.status, CaptureStatus.registered);
      final m = (await movements()).single;
      expect(m.category, 'Comida');
      expect(m.account, 'BCP Soles');
      expect(m.details.message, 'Prueba comida');
    });

    test('a Plin without a message waits for its category', () async {
      final out = await service.process('interbankPlin');
      expect(out.status, CaptureStatus.review);
      expect(out.draft!.why, 'Falta la categoría');
      expect(
        out.draft!.details.counterpart,
        'Lucia Fernanda Paz R Ojas Torres',
      );
      expect(out.draft!.details.counterpartPhone, '321');
    });

    test('a manual entry has no receipt details', () async {
      await DriftLedgerRepository(
        db,
      ).addEntry(type: MovementType.expense, amountCents: 500, account: 'Yape');
      expect((await movements()).single.details.isEmpty, isTrue);
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
      await DriftLedgerRepository(db).delete((await movements()).single);
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
      final store = DriftCaptureRuleRepository(db);
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
