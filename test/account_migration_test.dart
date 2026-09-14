import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:el_ahorrador/data/app_database.dart';

void main() {
  test('v4 accounts receive balance columns during v5 migration', () async {
    final sqlite = sqlite3.openInMemory();
    sqlite.execute(
      'CREATE TABLE accounts (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, currency TEXT NOT NULL DEFAULT \'PEN\', icon TEXT NOT NULL DEFAULT \'wallet\', "order" INTEGER NOT NULL, is_default INTEGER NOT NULL DEFAULT 0, is_archived INTEGER NOT NULL DEFAULT 0, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL)',
    );
    sqlite.execute('PRAGMA user_version = 4');
    final db = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
    addTearDown(db.close);

    final columns = await db.customSelect('PRAGMA table_info(accounts)').get();
    expect(
      columns.map((row) => row.read<String>('name')),
      containsAll(['starting_balance_cents', 'starting_balance_date']),
    );
    final account = await db
        .customSelect('SELECT starting_balance_cents FROM accounts')
        .get();
    expect(account, isEmpty);
  });

  test(
    'v1 expenses are linked to the default account without data loss',
    () async {
      final sqlite = sqlite3.openInMemory();
      sqlite.execute('''
      CREATE TABLE expenses (
        id TEXT NOT NULL PRIMARY KEY,
        account TEXT NULL
      )
    ''');
      sqlite.execute(
        "INSERT INTO expenses (id, account) VALUES ('legacy-1', 'BCP Soles')",
      );
      sqlite.execute('PRAGMA user_version = 1');

      final db = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
      addTearDown(db.close);

      final migrated = await db
          .customSelect('SELECT id, account, account_id FROM expenses')
          .getSingle();
      expect(migrated.read<String>('id'), 'legacy-1');
      expect(migrated.read<String>('account'), 'BCP Soles');
      expect(migrated.read<String>('account_id'), AppDatabase.defaultAccountId);
      expect(await db.select(db.accounts).getSingle(), isNotNull);
    },
  );
}
