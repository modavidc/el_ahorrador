import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';

class FileStore {
  static const _uuid = Uuid();

  static Future<String> persistIncomingFile(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = _uuid.v4();
    final ext = p.extension(
      sourcePath.isEmpty ? '' : sourcePath,
      5,
    ); // best effort
    final dest = p.join(dir.path, 'captures', '$id$ext');
    await Directory(p.join(dir.path, 'captures')).create(recursive: true);
    final temporary = '$dest.partial';
    try {
      final sink = File(temporary).openWrite();
      await sink.addStream(File(sourcePath).openRead());
      await sink.flush();
      await sink.close();
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

  static Future<String> materializeForRead(String storedPath) async =>
      storedPath;

  static Future<void> releaseMaterializedFile(String path) async {}

  static Future<void> securelyDelete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
