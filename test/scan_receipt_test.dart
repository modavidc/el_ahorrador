import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_records.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_rule_repository.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';
import 'package:el_ahorrador/features/capture/domain/ticket_reader.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

import 'support/capture_fakes.dart';

void main() {
  final now = DateTime(2026, 9, 27, 10);

  group('TicketReader', () {
    test('reads merchant, TOTAL and date of a supermarket ticket', () {
      final r = TicketReader.read(plazaVeaTicket, now: now);
      expect(r.isReceipt, isTrue);
      expect(r.counterpart, 'Plaza Vea');
      expect(r.amountCents, 9950);
      expect(r.at, DateTime(2026, 9, 26, 19, 42));
      expect(r.direction, ReceiptDirection.sent);
    });

    test('takes the figure of the next line when TOTAL stands alone', () {
      final r = TicketReader.read(
        'CHIFA KAM LEN\nRUC 10456789012\nTOTAL\nS/ 42,50\n',
        now: now,
      );
      expect(r.counterpart, 'Chifa Kam Len');
      expect(r.amountCents, 4250);
    });

    test('a photo without a total is not a ticket', () {
      expect(TicketReader.read(selfie, now: now).isReceipt, isFalse);
    });
  });

  group('CaptureService.scan', () {
    late AppDatabase db;
    late CaptureService service;
    late DriftLedgerRepository ledger;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      ledger = DriftLedgerRepository(db);
      service = CaptureService(
        ocr: FakeOcr(),
        images: FakeStorage(),
        records: DriftCaptureRecords(db),
        rules: DriftCaptureRuleRepository(db),
        ledger: ledger,
        now: () => now,
      );
    });
    tearDown(() => db.close());

    test('reads without registering until Guardar', () async {
      final scan = await service.scan('ticket');
      expect(scan.draft.note, 'Plaza Vea');
      expect(scan.draft.amountCents, 9950);
      expect(scan.draft.category, 'Mercado');
      expect(scan.draft.ocrPercent, 97);
      expect(await ledger.watchMovements().first, isEmpty);

      final id = await service.saveScan(
        scan,
        category: 'Comida',
        account: scan.draft.account,
      );
      final saved = (await ledger.watchMovements().first).single;
      expect(saved.id, id);
      expect(saved.category, 'Comida');
      expect(saved.amountCents, 9950);
      expect(saved.origin, MovementOrigin.receipt);
    });

    test('the same ticket twice is refused', () async {
      final scan = await service.scan('ticket');
      await service.saveScan(
        scan,
        category: 'Mercado',
        account: scan.draft.account,
      );
      await expectLater(
        service.scan('ticket'),
        throwsA(
          isA<ScanException>().having(
            (e) => e.message,
            'message',
            'Esta boleta ya está registrada',
          ),
        ),
      );
    });

    test('a closed scan can be taken again', () async {
      await service.cancelScan(await service.scan('ticket'));
      expect((await service.scan('ticket')).draft.amountCents, 9950);
    });

    test('a photo without a total explains why', () async {
      await expectLater(service.scan('selfie'), throwsA(isA<ScanException>()));
    });
  });
}
