import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/daos.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('stores a transfer as linked outgoing and incoming movements', () async {
    final savingsId = await AccountRepository(
      db,
    ).create(name: 'Ahorros', groupId: AppDatabase.defaultAccountGroupId);
    await db.insertTransfer(
      id: 'transfer-1',
      dateEpochMs: 1000,
      amountCents: 1250,
      currency: 'PEN',
      sourceAccountId: AppDatabase.defaultAccountId,
      destinationAccountId: savingsId,
      sourceAccount: 'Efectivo',
      destinationAccount: 'Ahorros',
      description: 'Ahorro mensual',
    );

    final rows = await (db.select(
      db.expenses,
    )..where((expense) => expense.origination.equals('transfer-1'))).get();

    expect(rows, hasLength(2));
    final outgoing = rows.singleWhere((row) => row.amountCents == -1250);
    final incoming = rows.singleWhere((row) => row.amountCents == 1250);
    expect(outgoing.accountId, AppDatabase.defaultAccountId);
    expect(incoming.accountId, savingsId);
    expect(rows.every((row) => row.vendor == 'Transferencia'), isTrue);
    expect(rows.every((row) => row.categoryId == null), isTrue);
    expect(rows.every((row) => row.source == 'Efectivo'), isTrue);
    expect(rows.every((row) => row.destination == 'Ahorros'), isTrue);
  });

  test('rejects invalid transfers before writing anything', () async {
    expect(
      () => db.insertTransfer(
        id: 'invalid',
        dateEpochMs: 1000,
        amountCents: 0,
        currency: 'PEN',
        sourceAccountId: AppDatabase.defaultAccountId,
        destinationAccountId: 'other',
      ),
      throwsArgumentError,
    );
    expect(await db.select(db.expenses).get(), isEmpty);

    expect(
      () => db.insertTransfer(
        id: 'same-account',
        dateEpochMs: 1000,
        amountCents: 100,
        currency: 'PEN',
        sourceAccountId: AppDatabase.defaultAccountId,
        destinationAccountId: AppDatabase.defaultAccountId,
      ),
      throwsArgumentError,
    );
  });
}
