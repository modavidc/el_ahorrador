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

  test(
    'calculates account balance from starting balance and signed movements',
    () async {
      final id = await repository.create(name: 'BCP');
      await repository.setStartingBalance(id, startingBalanceCents: 10000);
      await db.insertExpenseFromParser(
        id: 'income-1',
        dateEpochMs: 1,
        amountCents: 2500,
        currency: 'PEN',
        accountId: id,
      );
      await db.insertExpenseFromParser(
        id: 'expense-1',
        dateEpochMs: 2,
        amountCents: -1250,
        currency: 'PEN',
        accountId: id,
      );

      final balance = await repository.balance(id);
      expect(balance.startingBalanceCents, 10000);
      expect(balance.balanceCents, 11250);
    },
  );

  test('observes balance changes', () async {
    final id = await repository.create(name: 'Yape');
    final values = <int>[];
    final subscription = repository
        .watchBalance(id)
        .listen((balance) => values.add(balance.balanceCents));
    addTearDown(subscription.cancel);
    await Future<void>.delayed(Duration.zero);
    await db.insertExpenseFromParser(
      id: 'expense-watch',
      dateEpochMs: 1,
      amountCents: -500,
      currency: 'PEN',
      accountId: id,
    );
    await expectLater(
      repository.watchBalance(id),
      emitsThrough(
        predicate<AccountBalance>((balance) => balance.balanceCents == -500),
      ),
    );
    expect(values, contains(-500));
  });
}
