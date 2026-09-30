import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/ledger/domain/speech_input.dart';

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

/// Current Yape receipt: logo "S/" on top, amount split from its "S/",
/// shortened name with an asterisk, a message box, security code and the
/// transaction data read row by row.
const yapeWithMessage = '''
S/
yape
JOSÉ
QUIÑONES
¡Yapeaste!
S/
2
Carla Nue*
29 set. 2026 | 05:33 p. m.
pasaje bus
CÓDIGO DE SEGURIDAD
6 9 9
DATOS DE LA TRANSACCIÓN
Nro. de celular
*** *** 281
Destino
Yape
Nro. de operación
23760001
''';

/// The same layout when the OCR reads the label column before the values
/// and the time on its own line.
const yapeColumns = '''
yape
¡Yapeaste!
S/ 12
Luis Paz*
29 set. 2026
| 06:41 p. m.
almuerzo menu lomo saltado
CÓDIGO DE SEGURIDAD
4
8
6
DATOS DE LA TRANSACCIÓN
Nro. de celular
Destino
Nro. de operación
*** *** 810
Yape
26520002
''';

/// Current Yape receipt without a message.
const yapeNoMessage = '''
yape
¡Yapeaste!
S/ 10
Ana Ruiz*
28 set. 2026 | 10:31 p. m.
CÓDIGO DE SEGURIDAD
9 3 8
DATOS DE LA TRANSACCIÓN
Nro. de celular
*** *** 257
Destino
Yape
Nro. de operación
33940003
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

/// Photo of a supermarket ticket (Escanear boleta).
const plazaVeaTicket = '''
PLAZA VEA
SUPERMERCADOS PERUANOS S.A.
RUC 20100070970
BOLETA DE VENTA ELECTRONICA B123-00045678
Fecha: 26/09/2026 19:42
LECHE GLORIA 6X400G      27.90
PAN MOLDE BIMBO          9.60
ARROZ COSTENO 5KG        32.00
POLLO ENTERO KG          30.00
SUBTOTAL                 84.32
IGV 18%                  15.18
TOTAL S/                 99.50
EFECTIVO                100.00
VUELTO                    0.50
''';

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
  'message': yapeWithMessage,
  'columns': yapeColumns,
  'blurry': yapeBlurry,
  'bcp': bcpCard,
  'selfie': selfie,
  'ticket': plazaVeaTicket,
};

/// Camera that "takes" the given fake file names in order; null = closed.
class FakeCamera implements ReceiptCamera {
  FakeCamera([this.photos = const ['ticket']]);

  final List<String?> photos;
  var _next = 0;

  @override
  Future<String?> takePhoto() async =>
      _next < photos.length ? photos[_next++] : null;
}

/// Speech recognition that "hears" [text].
class FakeSpeech implements SpeechInput {
  FakeSpeech([this.text = 'almuerzo 18 soles con yape']);

  final String text;
  var stops = 0;

  @override
  Stream<SpeechText> listen() => Stream.fromIterable([
    SpeechText(text.split(' ').first),
    SpeechText(text, done: true),
  ]);

  @override
  Future<void> stop() async => stops++;
}

/// The real app wiring over [db], with fake OCR and image storage and the
/// pinned [AppClock].
AppDependencies fakeDependencies(AppDatabase db) => AppDependencies(
  db,
  ocr: FakeOcr(),
  images: FakeStorage(),
  camera: FakeCamera(),
  speech: FakeSpeech(),
  now: AppClock.now,
);
