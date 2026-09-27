import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:el_ahorrador/core/database/app_database.dart';

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

  test(
    'v6 databases gain budgets, settings, account details and hiding',
    () async {
      // Build the current schema, then strip what v7 adds to get a v6 file.
      final sqlite = sqlite3.openInMemory();
      final fresh = AppDatabase.forTesting(
        NativeDatabase.opened(sqlite, closeUnderlyingOnClose: false),
      );
      await fresh.customSelect('SELECT 1').get();
      await fresh.close();
      sqlite
        ..execute('DROP TABLE budgets')
        ..execute('DROP TABLE app_settings')
        ..execute('ALTER TABLE accounts DROP COLUMN description')
        ..execute('ALTER TABLE accounts DROP COLUMN credit_limit_cents')
        ..execute('ALTER TABLE accounts DROP COLUMN is_hidden')
        ..execute('PRAGMA user_version = 6');

      final db = AppDatabase.forTesting(NativeDatabase.opened(sqlite));
      addTearDown(db.close);

      final columns = await db
          .customSelect('PRAGMA table_info(accounts)')
          .get();
      expect(
        columns.map((row) => row.read<String>('name')),
        containsAll(['description', 'credit_limit_cents', 'is_hidden']),
      );
      expect(await db.select(db.budgets).get(), isEmpty);
      expect(await db.select(db.appSettings).get(), isEmpty);
      expect(
        (await db.select(db.accounts).getSingle()).id,
        AppDatabase.defaultAccountId,
      );
    },
  );
}
