import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:el_ahorrador/data/app_database.dart';

void main() {
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
