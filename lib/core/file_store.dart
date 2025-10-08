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
    final ext = p.extension(sourcePath.isEmpty ? '' : sourcePath, 5); // best effort
    final dest = p.join(dir.path, 'captures', '$id$ext');
    await Directory(p.join(dir.path, 'captures')).create(recursive: true);
    await File(sourcePath).copy(dest);
    return dest;
  }

  static Future<String> sha256OfFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return sha256.convert(bytes).toString();
  }
}
