import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' hide Hmac;
import 'package:cryptography/cryptography.dart';
import 'app_database.dart';

/// Creates portable, self-validating snapshots of all accounting data.
///
/// A restore validates the complete payload before opening its transaction.
/// If any row is invalid (including a foreign-key or unique-index violation),
/// Drift rolls the whole replacement back and the current database is kept.
class DataBackupService {
  DataBackupService(this._db);

  static const int formatVersion = 1;
  final AppDatabase _db;

  /// Produces a password-protected export using PBKDF2-HMAC-SHA256 and
  /// authenticated AES-256-GCM. A wrong password or any modified byte fails
  /// authentication before the database is touched.
  Future<String> createEncryptedBackup(String password) async {
    if (password.length < 12) {
      throw ArgumentError.value(
        password,
        'password',
        'must have 12+ characters',
      );
    }
    final plaintext = utf8.encode(await createBackup());
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final algorithm = AesGcm.with256bits();
    final nonce = algorithm.newNonce();
    final key = await _deriveKey(password, salt);
    final box = await algorithm.encrypt(
      plaintext,
      secretKey: key,
      nonce: nonce,
    );
    return jsonEncode({
      'format': 'el-ahorrador-encrypted-backup',
      'version': 1,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': 210000,
      'cipher': 'AES-256-GCM',
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  Future<void> restoreEncryptedBackup(String backup, String password) async {
    final envelope = _object(jsonDecode(backup), 'encrypted backup');
    if (envelope['format'] != 'el-ahorrador-encrypted-backup' ||
        envelope['version'] != 1 ||
        envelope['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        envelope['iterations'] != 210000 ||
        envelope['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported encrypted backup format');
    }
    try {
      final salt = base64Decode(envelope['salt'] as String);
      final key = await _deriveKey(password, salt);
      final plaintext = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(envelope['ciphertext'] as String),
          nonce: base64Decode(envelope['nonce'] as String),
          mac: Mac(base64Decode(envelope['mac'] as String)),
        ),
        secretKey: key,
      );
      await restoreBackup(utf8.decode(plaintext));
    } on SecretBoxAuthenticationError {
      throw const FormatException('Wrong password or damaged backup');
    } on TypeError {
      throw const FormatException('Malformed encrypted backup');
    } on FormatException {
      rethrow;
    }
  }

  static Future<SecretKey> _deriveKey(String password, List<int> salt) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: 210000,
        bits: 256,
      ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  Future<String> createBackup() async {
    final payload = <String, Object?>{
      'formatVersion': formatVersion,
      'schemaVersion': _db.schemaVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'captures': (await _db.select(_db.captures).get())
          .map((row) => row.toJson())
          .toList(),
      'categories': (await _db.select(_db.categories).get())
          .map((row) => row.toJson())
          .toList(),
      'subcategories': (await _db.select(_db.subcategories).get())
          .map((row) => row.toJson())
          .toList(),
      'expenses': (await _db.select(_db.expenses).get())
          .map((row) => row.toJson())
          .toList(),
    };
    final encodedPayload = jsonEncode(payload);
    return jsonEncode({
      'algorithm': 'SHA-256',
      'checksum': sha256.convert(utf8.encode(encodedPayload)).toString(),
      'payload': payload,
    });
  }

  Future<void> restoreBackup(String backup) async {
    final envelope = _object(jsonDecode(backup), 'backup');
    if (envelope['algorithm'] != 'SHA-256') {
      throw const FormatException('Unsupported backup checksum algorithm');
    }
    final payload = _object(envelope['payload'], 'payload');
    final expected = envelope['checksum'];
    final actual = sha256.convert(utf8.encode(jsonEncode(payload))).toString();
    if (expected is! String || expected != actual) {
      throw const FormatException('Backup checksum mismatch');
    }
    if (payload['formatVersion'] != formatVersion) {
      throw const FormatException('Unsupported backup format');
    }
    final schema = payload['schemaVersion'];
    if (schema is! int || schema > _db.schemaVersion) {
      throw const FormatException('Backup requires a newer database schema');
    }

    final captures = _rows(payload, 'captures').map(Capture.fromJson).toList();
    final categories = _rows(
      payload,
      'categories',
    ).map(Category.fromJson).toList();
    final subcategories = _rows(
      payload,
      'subcategories',
    ).map(Subcategory.fromJson).toList();
    final expenses = _rows(payload, 'expenses').map(Expense.fromJson).toList();

    await _db.transaction(() async {
      await _db.delete(_db.expenses).go();
      await _db.delete(_db.subcategories).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.captures).go();
      await _db.batch((batch) {
        batch.insertAll(
          _db.captures,
          captures.map((row) => row.toCompanion(false)).toList(),
        );
        batch.insertAll(
          _db.categories,
          categories.map((row) => row.toCompanion(false)).toList(),
        );
        batch.insertAll(
          _db.subcategories,
          subcategories.map((row) => row.toCompanion(false)).toList(),
        );
        batch.insertAll(
          _db.expenses,
          expenses.map((row) => row.toCompanion(false)).toList(),
        );
      });
      final violations = await _db
          .customSelect('PRAGMA foreign_key_check')
          .get();
      if (violations.isNotEmpty) {
        throw const FormatException('Backup contains broken relationships');
      }
    });
  }

  static Map<String, dynamic> _object(Object? value, String name) {
    if (value is! Map) throw FormatException('$name must be an object');
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  static List<Map<String, dynamic>> _rows(
    Map<String, dynamic> payload,
    String name,
  ) {
    final value = payload[name];
    if (value is! List) throw FormatException('$name must be a list');
    return value.map((row) => _object(row, '$name row')).toList();
  }
}
