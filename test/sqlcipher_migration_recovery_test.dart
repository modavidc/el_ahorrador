import 'dart:io';

import 'package:el_ahorrador/data/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  final key = List<int>.generate(32, (index) => index + 1);

  test(
    'promotes a verified encrypted file after an interrupted rename',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'cipher_recovery_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/data.sqlite');
      final plaintextBytes = _createPlaintextDatabase(file);

      await file.rename('${file.path}.plaintext-backup');
      final encryptedBytes = List<int>.generate(64, (index) => 255 - index);
      await File(
        '${file.path}.encrypted',
      ).writeAsBytes(encryptedBytes, flush: true);

      await reconcileInterruptedSqlcipherMigration(
        file,
        key,
        verifier: (candidate, _) async => candidate.path.endsWith('.encrypted'),
      );

      expect(await file.exists(), isTrue);
      expect(await File('${file.path}.encrypted').exists(), isFalse);
      expect(await File('${file.path}.plaintext-backup').exists(), isFalse);
      expect(await file.readAsBytes(), encryptedBytes);
      expect(plaintextBytes, isNotEmpty);
    },
  );

  test('discards a partial encrypted file and rebuilds from backup', () async {
    final directory = await Directory.systemTemp.createTemp('cipher_rollback_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/data.sqlite');
    final plaintextBytes = _createPlaintextDatabase(file);
    await file.rename('${file.path}.plaintext-backup');
    await File('${file.path}.encrypted').writeAsBytes([1, 2, 3], flush: true);

    await reconcileInterruptedSqlcipherMigration(
      file,
      key,
      verifier: (_, _) async => false,
    );

    expect(await file.exists(), isTrue);
    expect(await File('${file.path}.encrypted').exists(), isFalse);
    expect(await File('${file.path}.plaintext-backup').exists(), isFalse);
    expect(await file.readAsBytes(), plaintextBytes);
  });
}

List<int> _createPlaintextDatabase(File file) {
  final database = sqlite3.open(file.path);
  try {
    database.execute('CREATE TABLE durable_state (value TEXT NOT NULL)');
    database.execute("INSERT INTO durable_state VALUES ('preserved')");
  } finally {
    database.dispose();
  }
  return file.readAsBytesSync();
}
