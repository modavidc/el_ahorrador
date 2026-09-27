import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CaptureKeyStore {
  Future<List<int>> getOrCreateKey();
}

/// Keeps the capture encryption key separate from the database key.
class SecureCaptureKeyStore implements CaptureKeyStore {
  SecureCaptureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const _storageKey = 'captures.aes_gcm.key.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<List<int>> getOrCreateKey() async {
    final existing = await _storage.read(key: _storageKey);
    if (existing != null) {
      final decoded = base64Url.decode(existing);
      if (decoded.length != 32) {
        throw const FormatException('Invalid capture encryption key');
      }
      return decoded;
    }

    final random = Random.secure();
    final generated = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: _storageKey, value: base64Url.encode(generated));
    return generated;
  }
}
