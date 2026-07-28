import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/data/account_repository.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';

void main() {
  late AppDatabase db;
  late AccountRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = AccountRepository(db);
  });

  tearDown(() => db.close());

  test('creates, renames and orders active accounts', () async {
    final firstId = await repository.create(name: 'BCP');
    final secondId = await repository.create(name: 'Yape');

    await repository.rename(firstId, 'BCP Soles');
    await repository.reorder([secondId, firstId, AppDatabase.defaultAccountId]);

    final active = await repository.watchActive().first;
    expect(active.map((account) => account.name), [
      'Yape',
      'BCP Soles',
      'Efectivo',
    ]);
  });

  test(
    'default account cannot be archived and a new default is active',
    () async {
      final id = await repository.create(name: 'Tarjeta');

      expect(
        () => repository.setArchived(AppDatabase.defaultAccountId, true),
        throwsA(isA<StateError>()),
      );

      await repository.setArchived(id, true);
      await repository.setDefault(id);
      final account = await repository.defaultAccount();
      expect(account.id, id);
      expect(account.isArchived, isFalse);
    },
  );

  test('new expenses use the default account automatically', () async {
    await db.insertExpenseFromParser(
      id: 'expense-1',
      dateEpochMs: 1,
      amountCents: -100,
      currency: 'PEN',
    );

    final expense = await db.select(db.expenses).getSingle();
    expect(expense.accountId, AppDatabase.defaultAccountId);
  });

  test('archived accounts disappear from selectors', () async {
    final id = await repository.create(name: 'Ahorros');
    await repository.setArchived(id, true);

    final active = await repository.watchActive().first;
    expect(active.map((account) => account.id), isNot(contains(id)));
  });
}
