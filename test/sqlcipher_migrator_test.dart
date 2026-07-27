import 'dart:io';

import 'package:el_ahorrador/data/sqlcipher_migrator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  const migrator = SqlCipherMigrator();
  final key = List<int>.generate(32, (index) => index + 1);
  late Directory temporaryDirectory;
  late File databaseFile;

  final hasSqlCipher = _hasSqlCipher();

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sqlcipher-test-',
    );
    databaseFile = File(p.join(temporaryDirectory.path, 'legacy.sqlite'));
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('invalid key is rejected before touching the legacy database', () async {
    final plaintext = sqlite3.open(databaseFile.path);
    plaintext.execute('CREATE TABLE sentinel (value TEXT)');
    plaintext.dispose();
    final before = await databaseFile.readAsBytes();

    await expectLater(
      migrator.prepare(databaseFile, List<int>.filled(31, 1)),
      throwsA(isA<SqlCipherMigrationException>()),
    );
    expect(await databaseFile.readAsBytes(), before);
  });

  test(
    'missing native SQLCipher fails closed and preserves plaintext',
    () async {
      final plaintext = sqlite3.open(databaseFile.path);
      plaintext.execute('CREATE TABLE sentinel (value TEXT)');
      plaintext.dispose();
      final before = await databaseFile.readAsBytes();

      await expectLater(
        migrator.prepare(databaseFile, key),
        throwsA(isA<SqlCipherMigrationException>()),
      );
      expect(await databaseFile.readAsBytes(), before);
      expect(await File('${databaseFile.path}.encrypted.partial').exists(), false);
      expect(await File('${databaseFile.path}.plaintext.rollback').exists(), false);
      expect(await File('${databaseFile.path}.migration.json').exists(), false);
    },
    skip: hasSqlCipher ? 'Only applies when SQLCipher is unavailable' : false,
  );

  test(
    'migrates plaintext data and rejects access without the key',
    () async {
      final plaintext = sqlite3.open(databaseFile.path);
      plaintext.execute('CREATE TABLE expenses (id TEXT, amount INTEGER)');
      plaintext.execute("INSERT INTO expenses VALUES ('expense-1', 1990)");
      plaintext.userVersion = 7;
      plaintext.dispose();

      expect(
        await migrator.prepare(databaseFile, key),
        SqlCipherMigrationResult.migrated,
      );
      final bytes = await databaseFile.readAsBytes();
      expect(bytes.take(16), isNot(orderedEquals(sqliteHeader)));

      final encrypted = sqlite3.open(databaseFile.path);
      migrator.configure(encrypted, key);
      expect(encrypted.userVersion, 7);
      expect(
        encrypted.select('SELECT amount FROM expenses').single['amount'],
        1990,
      );
      encrypted.dispose();

      final withoutKey = sqlite3.open(databaseFile.path);
      expect(
        () => withoutKey.select('SELECT * FROM expenses'),
        throwsA(anything),
      );
      withoutKey.dispose();
    },
    skip: hasSqlCipher ? false : 'SQLCipher native test library is unavailable',
  );

  test(
    'an interrupted swap restores its rollback copy',
    () async {
      final backup = File('${databaseFile.path}.plaintext.rollback');
      final marker = File('${databaseFile.path}.migration.json');
      final plaintext = sqlite3.open(backup.path);
      plaintext.execute('CREATE TABLE sentinel (value TEXT)');
      plaintext.execute("INSERT INTO sentinel VALUES ('preserved')");
      plaintext.dispose();
      await marker.writeAsString('{"version":1,"stage":"swapping"}');

      expect(
        await migrator.prepare(databaseFile, key),
        SqlCipherMigrationResult.migrated,
      );
      expect(await backup.exists(), isFalse);
      expect(await marker.exists(), isFalse);

      final encrypted = sqlite3.open(databaseFile.path);
      migrator.configure(encrypted, key);
      expect(
        encrypted.select('SELECT value FROM sentinel').single['value'],
        'preserved',
      );
      encrypted.dispose();
    },
    skip: hasSqlCipher ? false : 'SQLCipher native test library is unavailable',
  );

  test(
    'wrong key never removes a valid encrypted database',
    () async {
      expect(
        await migrator.prepare(databaseFile, key),
        SqlCipherMigrationResult.created,
      );
      final encrypted = sqlite3.open(databaseFile.path);
      migrator.configure(encrypted, key);
      encrypted.execute('CREATE TABLE sentinel (value TEXT)');
      encrypted.dispose();
      final before = await databaseFile.readAsBytes();

      await expectLater(
        migrator.prepare(databaseFile, List<int>.filled(32, 99)),
        throwsA(isA<SqlCipherMigrationException>()),
      );
      expect(await databaseFile.readAsBytes(), before);
    },
    skip: hasSqlCipher ? false : 'SQLCipher native test library is unavailable',
  );
}

const sqliteHeader = <int>[
  83,
  81,
  76,
  105,
  116,
  101,
  32,
  102,
  111,
  114,
  109,
  97,
  116,
  32,
  51,
  0,
];

bool _hasSqlCipher() {
  final database = sqlite3.openInMemory();
  try {
    return database.select('PRAGMA cipher_version').isNotEmpty;
  } finally {
    database.dispose();
  }
}
