import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:el_ahorrador/core/capture_key_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class FileStore {
  static const _uuid = Uuid();
  static const _magic = <int>[0x45, 0x41, 0x43, 0x46]; // EACF
  static const _version = 1;
  static final _cipher = AesGcm.with256bits();
  static final Set<String> _materializedFiles = <String>{};
  static Future<List<int>>? _defaultKey;

  static Future<String> persistIncomingFile(
    String sourcePath, {
    Directory? documentsDirectory,
    CaptureKeyStore? keyStore,
  }) async {
    final dir = documentsDirectory ?? await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    final ext = p.extension(sourcePath.isEmpty ? '' : sourcePath, 16);
    final dest = p.join(dir.path, 'captures', '$id.capture');
    await Directory(p.join(dir.path, 'captures')).create(recursive: true);
    final temporary = '$dest.partial';
    try {
      final cleartext = await File(sourcePath).readAsBytes();
      final extensionBytes = utf8.encode(ext);
      if (extensionBytes.length > 255) {
        throw const FormatException('Capture extension is too long');
      }
      final header = <int>[
        ..._magic,
        _version,
        12,
        extensionBytes.length,
        ...extensionBytes,
      ];
      final nonce = _cipher.newNonce();
      final key = await _keyFrom(keyStore);
      final box = await _cipher.encrypt(
        cleartext,
        secretKey: SecretKey(key),
        nonce: nonce,
        aad: header,
      );
      await File(temporary).writeAsBytes(<int>[
        ...header,
        ...nonce,
        ...box.cipherText,
        ...box.mac.bytes,
      ], flush: true);
      await File(temporary).rename(dest);
    } catch (_) {
      final partial = File(temporary);
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
    return dest;
  }

  static Future<String> sha256OfFile(String path) async {
    return (await sha256.bind(File(path).openRead()).first).toString();
  }

  static Future<String> materializeForRead(
    String storedPath, {
    Directory? temporaryDirectory,
    CaptureKeyStore? keyStore,
  }) async {
    final encoded = await File(storedPath).readAsBytes();
    final parsed = _parse(encoded);
    final key = await _keyFrom(keyStore);
    final cleartext = await _cipher.decrypt(
      SecretBox(parsed.cipherText, nonce: parsed.nonce, mac: Mac(parsed.mac)),
      secretKey: SecretKey(key),
      aad: parsed.header,
    );

    final root = temporaryDirectory ?? await getTemporaryDirectory();
    final ocrDirectory = Directory(p.join(root.path, 'el_ahorrador_ocr'));
    await ocrDirectory.create(recursive: true);
    final output = File(
      p.join(ocrDirectory.path, '${_uuid.v4()}${parsed.extension}'),
    );
    try {
      await output.writeAsBytes(cleartext, flush: true);
      _materializedFiles.add(p.normalize(output.absolute.path));
      return output.path;
    } catch (_) {
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }

  static Future<void> releaseMaterializedFile(String path) async {
    final normalized = p.normalize(File(path).absolute.path);
    if (!_materializedFiles.remove(normalized)) return;
    await securelyDelete(normalized);
  }

  static Future<void> securelyDelete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static _EncryptedCapture _parse(List<int> bytes) {
    const fixedHeaderLength = 7;
    if (bytes.length < fixedHeaderLength + 12 + 16 ||
        !_startsWith(bytes, _magic) ||
        bytes[4] != _version) {
      throw const FormatException('Unsupported encrypted capture format');
    }
    final nonceLength = bytes[5];
    final extensionLength = bytes[6];
    final headerLength = fixedHeaderLength + extensionLength;
    final cipherEnd = bytes.length - 16;
    if (nonceLength != 12 || headerLength + nonceLength > cipherEnd) {
      throw const FormatException('Invalid encrypted capture');
    }
    final extension = utf8.decode(bytes.sublist(7, headerLength));
    if (extension.isNotEmpty &&
        (!extension.startsWith('.') || extension.contains(RegExp(r'[\\/]')))) {
      throw const FormatException('Invalid capture extension');
    }
    return _EncryptedCapture(
      header: bytes.sublist(0, headerLength),
      extension: extension,
      nonce: bytes.sublist(headerLength, headerLength + nonceLength),
      cipherText: bytes.sublist(headerLength + nonceLength, cipherEnd),
      mac: bytes.sublist(cipherEnd),
    );
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static Future<List<int>> _keyFrom(CaptureKeyStore? keyStore) {
    if (keyStore != null) return keyStore.getOrCreateKey();
    return _defaultKey ??= SecureCaptureKeyStore().getOrCreateKey();
  }
}

class _EncryptedCapture {
  const _EncryptedCapture({
    required this.header,
    required this.extension,
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> header;
  final String extension;
  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;
}
