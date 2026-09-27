import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/app/background_capture.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/features/capture/data/android_background_capture.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_records.dart';
import 'package:el_ahorrador/features/capture/data/drift_capture_rule_repository.dart';
import 'package:el_ahorrador/features/capture/domain/background_capture.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

import 'support/capture_fakes.dart';

const yapeNotification = 'Yape\nYape\nJuan Pérez te yapeó S/ 50.00';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 27, 21, 40);

  test('a Yape notification is read as income from its sender', () {
    final r = ReceiptReader.read(yapeNotification, now: now);
    expect(r.direction, ReceiptDirection.received);
    expect(r.amountCents, 5000);
    expect(r.note, 'Te yapearon · Juan Pérez');
  });

  group('processText', () {
    late AppDatabase db;
    late CaptureService service;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await AccountRepository(
        db,
      ).create(name: 'Yape', groupId: AppDatabase.defaultAccountGroupId);
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

    test('registers a notification once', () async {
      final first = await service.processText(
        yapeNotification,
        sourceLabel: 'Aviso de Yape',
      );
      expect(first.status, CaptureStatus.registered);
      final again = await service.processText(
        yapeNotification,
        sourceLabel: 'Aviso de Yape',
      );
      expect(again.status, CaptureStatus.duplicate);
      final m = (await DriftLedgerRepository(db).watchMovements().first).single;
      expect(m.type, MovementType.income);
      expect(m.origin, MovementOrigin.screenshot);
    });

    test('the notification text of each outcome', () async {
      final registered = notificationFor(
        await service.processText(yapeNotification, sourceLabel: 'Yape'),
      );
      expect(registered['title'], 'Registrado · +S/ 50.00');
      expect(registered['body'], 'Te yapearon · Juan Pérez · Extra · Yape');
      expect(registered['movementId'], isNotNull);

      final silent = notificationFor(
        await service.processText('Hola, ¿cómo estás?', sourceLabel: 'Yape'),
      );
      expect(silent['title'], isNull);
    });
  });

  test('the Android adapter reads the service state', () async {
    const channel = MethodChannel('el_ahorrador/capture');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return {
            'enabled': call.method == 'setEnabled',
            'granted': ['photos', 'alerts', 'battery'],
          };
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    final capture = AndroidBackgroundCapture(channel: channel);
    final first = await capture.watch().first;
    expect(first.supported, isTrue);
    expect(first.enabled, isFalse);
    expect(first.granted, {
      CapturePermission.photos,
      CapturePermission.alerts,
      CapturePermission.battery,
    });
    expect(first.missingRequired, 2);

    final next = capture.watch().skip(1).first;
    await capture.setEnabled(true);
    expect((await next).enabled, isTrue);
    expect(calls, ['state', 'setEnabled']);
  });
}
