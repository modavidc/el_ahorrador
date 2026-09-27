import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';

const yapeSent = '''
¡Yapeaste!
S/ 23.50
Bodega Don Lucho
27 set. 2026 | 09:38 p. m.
Nro. de operación
04718822
Destino
Yape
Compartir
''';

const yapeReceived = '''
¡Te yapearon!
S/ 450
Juan Pérez
25 set. 2026 | 10:05 a. m.
Nro. de operación
05550001
''';

const yapeToPerson = '''
¡Yapeaste!
S/ 35
Rosa Quispe M.
26 set. 2026 | 01:12 p. m.
Nro. de operación
04812345
''';

const yapeBlurry = '''
¡Yapeaste!
Tambo
27 set. 2026 | 08:00 p. m.
''';

const bcpCard = '''
BCP
Consumo con tu tarjeta
S/ 1,234.50
Saga Falabella
15/09/2026 18:20
''';

const selfie = 'Feliz cumpleaños\nNos vemos el sábado';

/// OCR that returns canned text per file name.
class FakeOcr implements OcrEngine {
  FakeOcr([this.texts = receipts]);

  final Map<String, String> texts;

  @override
  Future<OcrResult> run(String imagePath) async =>
      OcrResult(texts[imagePath]!, confidence: 97);
}

/// Keeps images in place; the hash is the file name so tests control
/// "same image".
class FakeStorage implements CaptureImageStore {
  @override
  Future<String> hash(String path) async => path.split('#').first;

  @override
  Future<String> persist(String path) async => path;
}

/// Receipts by fake file name.
const receipts = {
  'sent': yapeSent,
  'sent#copy': yapeSent,
  'received': yapeReceived,
  'person': yapeToPerson,
  'blurry': yapeBlurry,
  'bcp': bcpCard,
  'selfie': selfie,
};

/// The real app wiring over [db], with fake OCR and image storage and the
/// pinned [AppClock].
AppDependencies fakeDependencies(AppDatabase db) => AppDependencies(
  db,
  ocr: FakeOcr(),
  images: FakeStorage(),
  now: AppClock.now,
);
