import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

enum SqlCipherMigrationResult { created, alreadyEncrypted, migrated, recovered }

class SqlCipherMigrationException implements Exception {
  const SqlCipherMigrationException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'SqlCipherMigrationException: $message${cause == null ? '' : ': $cause'}';
}

/// Converts the legacy plaintext database without ever overwriting its only
/// good copy. The backup exists only during the atomic swap and is restored on
/// any validation failure.
class SqlCipherMigrator {
  const SqlCipherMigrator();

  void configure(Database database, List<int> key) {
    if (database.select('PRAGMA cipher_version').isEmpty) {
      throw StateError(
        'SQLCipher is unavailable; refusing to open the database as plaintext',
      );
    }
    database.execute('PRAGMA key = "${_keySql(key)}"');
    database.execute('PRAGMA foreign_keys = ON');
  }

  Future<SqlCipherMigrationResult> prepare(File database, List<int> key) async {
    if (key.length != 32) {
      throw const SqlCipherMigrationException('Expected a 256-bit key');
    }

    final partial = File('${database.path}.encrypted.partial');
    final backup = File('${database.path}.plaintext.rollback');
    final marker = File('${database.path}.migration.json');
    final recovered = await _recover(database, partial, backup, marker, key);

    if (!await database.exists()) {
      return recovered
          ? SqlCipherMigrationResult.recovered
          : SqlCipherMigrationResult.created;
    }
    if (await _hasSqliteHeader(database)) {
      await _migrate(database, partial, backup, marker, key);
      return SqlCipherMigrationResult.migrated;
    }

    _validateEncrypted(database, key);
    return recovered
        ? SqlCipherMigrationResult.recovered
        : SqlCipherMigrationResult.alreadyEncrypted;
  }

  Future<void> _migrate(
    File database,
    File partial,
    File backup,
    File marker,
    List<int> key,
  ) async {
    await _writeMarker(marker, 'exporting');
    if (await partial.exists()) await partial.delete();

    Database? source;
    try {
      source = sqlite3.open(database.path);
      _requireSqlCipher(source);
      source.execute("ATTACH DATABASE ? AS encrypted KEY \"${_keySql(key)}\"", [
        partial.path,
      ]);
      source.execute('SELECT sqlcipher_export(\'encrypted\')');
      final userVersion = source.userVersion;
      source.execute('PRAGMA encrypted.user_version = $userVersion');
      source.execute('DETACH DATABASE encrypted');
      source.dispose();
      source = null;

      _validateEncrypted(partial, key);
      await _writeMarker(marker, 'swapping');
      await database.rename(backup.path);
      await partial.rename(database.path);
      try {
        _validateEncrypted(database, key);
      } catch (_) {
        if (await database.exists()) await database.delete();
        await backup.rename(database.path);
        rethrow;
      }
      await backup.delete();
      await marker.delete();
    } catch (error) {
      source?.dispose();
      if (!await database.exists() && await backup.exists()) {
        await backup.rename(database.path);
      }
      if (await partial.exists()) await partial.delete();
      if (await marker.exists()) await marker.delete();
      throw SqlCipherMigrationException(
        'Could not migrate the database; the plaintext original was preserved',
        error,
      );
    }
  }

  Future<bool> _recover(
    File database,
    File partial,
    File backup,
    File marker,
    List<int> key,
  ) async {
    if (!await marker.exists()) return false;

    if (await database.exists() && !await _hasSqliteHeader(database)) {
      try {
        _validateEncrypted(database, key);
        if (await backup.exists()) await backup.delete();
        if (await partial.exists()) await partial.delete();
        await marker.delete();
        return true;
      } catch (_) {
        // Restore the known plaintext copy below.
      }
    }
    if (await backup.exists()) {
      if (await database.exists()) await database.delete();
      await backup.rename(database.path);
    }
    if (await partial.exists()) await partial.delete();
    await marker.delete();
    return true;
  }

  void _validateEncrypted(File file, List<int> key) {
    final db = sqlite3.open(file.path);
    try {
      configure(db, key);
      db.select('SELECT count(*) FROM sqlite_master').single;
      final integrity = db.select('PRAGMA cipher_integrity_check');
      final messages = integrity
          .expand((row) => row.values)
          .whereType<String>()
          .toList();
      if (messages.any((message) => message.toLowerCase() != 'ok')) {
        throw StateError('SQLCipher integrity check failed: $integrity');
      }
    } finally {
      db.dispose();
    }
  }

  void _requireSqlCipher(Database database) {
    if (database.select('PRAGMA cipher_version').isEmpty) {
      throw StateError('SQLCipher native library is unavailable');
    }
  }

  Future<bool> _hasSqliteHeader(File file) async {
    final handle = await file.open();
    try {
      final header = await handle.read(16);
      return utf8.decode(header, allowMalformed: true) ==
          'SQLite format 3\u0000';
    } finally {
      await handle.close();
    }
  }

  Future<void> _writeMarker(File marker, String stage) async {
    final temporary = File('${marker.path}.partial');
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'stage': stage}),
      flush: true,
    );
    if (await marker.exists()) await marker.delete();
    await temporary.rename(marker.path);
  }

  String _keySql(List<int> key) {
    final hex = key
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return "x'$hex'";
  }
}
