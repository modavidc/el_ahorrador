import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class FileStore {
  static const _uuid = Uuid();
  static const _allowedExtensions = {'.jpg', '.jpeg', '.png', '.webp'};
  static const _captureKeyName = 'capture_file_key_v1';
  static const _magic = <int>[0x45, 0x41, 0x48, 0x43, 0x01]; // EAHC + v1
  static const _secureStorage = FlutterSecureStorage();
  static final _cipher = AesGcm.with256bits();

  static Future<String> persistIncomingFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    final rawExtension = p.extension(sourcePath).toLowerCase();
    final ext = _allowedExtensions.contains(rawExtension) ? rawExtension : '';
    final capturesDirectory = Directory(p.join(dir.path, 'captures'));
    await capturesDirectory.create(recursive: true);
    await _restrictToCurrentUser(capturesDirectory.path, isDirectory: true);

    // The random name deliberately avoids retaining merchant/account details
    // that may have appeared in the name of a shared screenshot.
    final dest = p.join(capturesDirectory.path, '$id$ext.eac');
    final key = await _captureKey();
    final plaintext = await File(sourcePath).readAsBytes();
    final box = await _cipher.encrypt(plaintext, secretKey: key);
    final payload = BytesBuilder(copy: false)
      ..add(_magic)
      ..add(box.nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    await File(dest).writeAsBytes(payload.takeBytes(), flush: true);
    await _restrictToCurrentUser(dest);
    return dest;
  }

  /// Materializes an encrypted capture only for the short OCR window.
  /// The caller must always invoke [releaseMaterializedFile] in a finally block.
  static Future<String> materializeForRead(String encryptedPath) async {
    final bytes = await File(encryptedPath).readAsBytes();
    if (bytes.length < _magic.length + 12 + 16 || !_startsWith(bytes, _magic)) {
      throw const FormatException('Invalid encrypted capture');
    }
    final nonceStart = _magic.length;
    final macStart = nonceStart + 12;
    final cipherStart = macStart + 16;
    final box = SecretBox(
      bytes.sublist(cipherStart),
      nonce: bytes.sublist(nonceStart, macStart),
      mac: Mac(bytes.sublist(macStart, cipherStart)),
    );
    final plaintext = await _cipher.decrypt(
      box,
      secretKey: await _captureKey(),
    );
    final cache = await getTemporaryDirectory();
    final ocrDirectory = Directory(p.join(cache.path, 'ocr_ephemeral'));
    await ocrDirectory.create(recursive: true);
    await _restrictToCurrentUser(ocrDirectory.path, isDirectory: true);
    final encryptedName = p.basenameWithoutExtension(encryptedPath);
    final ext = p.extension(encryptedName);
    final output = p.join(ocrDirectory.path, '${_uuid.v4()}$ext');
    await File(output).writeAsBytes(plaintext, flush: true);
    await _restrictToCurrentUser(output);
    return output;
  }

  static Future<void> releaseMaterializedFile(String path) =>
      securelyDelete(path);

  static Future<SecretKey> _captureKey() async {
    final encoded = await _secureStorage.read(key: _captureKeyName);
    if (encoded != null) return SecretKey(base64Url.decode(encoded));
    final key = await _cipher.newSecretKey();
    final bytes = await key.extractBytes();
    await _secureStorage.write(
      key: _captureKeyName,
      value: base64UrlEncode(bytes),
    );
    return SecretKey(bytes);
  }

  static bool _startsWith(List<int> value, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (value[i] != prefix[i]) return false;
    }
    return true;
  }

  static Future<void> _restrictToCurrentUser(
    String path, {
    bool isDirectory = false,
  }) async {
    if (Platform.isWindows) return;

    // Android/iOS app sandboxes already enforce this boundary. chmod is also
    // applied for desktop Unix targets, where the process umask may be broad.
    final mode = isDirectory ? '700' : '600';
    final result = await Process.run('chmod', [mode, path]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not secure local capture permissions',
        path,
      );
    }
  }

  static Future<String> sha256OfFile(String path) async {
    return (await sha256.bind(File(path).openRead()).first).toString();
  }

  /// Removes a retained capture while minimizing recoverable plaintext on
  /// conventional filesystems. Call this only after its database row has been
  /// removed (or inside the application's coordinated deletion workflow).
  static Future<void> securelyDelete(String path) async {
    final file = File(path);
    if (!await file.exists()) return;

    final length = await file.length();
    final handle = await file.open(mode: FileMode.writeOnly);
    try {
      const zeroBlockSize = 64 * 1024;
      final zeroBlock = List<int>.filled(zeroBlockSize, 0);
      var remaining = length;
      while (remaining > 0) {
        final bytesToWrite = remaining < zeroBlockSize
            ? remaining
            : zeroBlockSize;
        await handle.writeFrom(zeroBlock, 0, bytesToWrite);
        remaining -= bytesToWrite;
      }
      await handle.flush();
    } finally {
      await handle.close();
    }
    await file.delete();
  }
}
