import 'package:el_ahorrador/core/security/encrypted_file_store.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';

/// Capture images encrypted with AES-GCM in the app's documents.
class EncryptedCaptureImageStore implements CaptureImageStore {
  const EncryptedCaptureImageStore();

  @override
  Future<String> persist(String path) => FileStore.persistIncomingFile(path);

  @override
  Future<String> hash(String path) => FileStore.sha256OfFile(path);
}
