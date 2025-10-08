# 0) Requisitos rápidos

* Flutter 3.x ✅
* Android Studio + SDK (probemos primero en Android; iOS Share Extension lo vemos luego)
* `flutter doctor` sin rojos

```bash
flutter create mis_gastos
cd mis_gastos
flutter pub add share_handler google_mlkit_text_recognition path_provider uuid drift sqlite3_flutter_libs
flutter pub add dev:drift_dev build_runner
```

> ML Kit funciona offline y no paga llamadas. Mantiene el objetivo de costo ≈ 0.

---

# 1) Android: recibir “Compartir con…”

Edita **`android/app/src/main/AndroidManifest.xml`** dentro del `<activity android:name="io.flutter.embedding.android.FlutterActivity" ...>`:

```xml
<!-- Recibir UNA imagen -->
<intent-filter>
  <action android:name="android.intent.action.SEND" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
</intent-filter>

<!-- Recibir MÚLTIPLES imágenes -->
<intent-filter>
  <action android:name="android.intent.action.SEND_MULTIPLE" />
  <category android:name="android.intent.category.DEFAULT" />
  <data android:mimeType="image/*" />
</intent-filter>
```

---

# 2) Estructura simple de carpetas (sugerida)

```
lib/
  main.dart
  core/
    ocr_engine.dart
    parser.dart
    file_store.dart
  data/
    app_database.dart
    daos.dart
  features/
    inbox/inbox_page.dart
    detail/detail_page.dart
```

---

# 3) DB local con Drift (capturas + gastos)

## `lib/data/app_database.dart`

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Captures extends Table {
  TextColumn get id => text()(); // uuid
  IntColumn get createdAt => integer()(); // epoch ms
  TextColumn get sourceApp => text().nullable()();
  TextColumn get imagePath => text()();
  TextColumn get hash => text().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get status => text()(); // PENDING | PROCESSING | PROCESSED | FAILED
  TextColumn get ocrText => text().nullable()();
  TextColumn get metaJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get captureId => text().nullable().references(Captures, #id)();
  IntColumn get date => integer()(); // epoch ms
  IntColumn get amountCents => integer()(); // 1050 = S/10.50
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get vendor => text().nullable()();
  TextColumn get notes => text().nullable()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Captures, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  @override
  int get schemaVersion => 1;
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'mis_gastos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
```

## `lib/data/daos.dart`

```dart
import 'package:drift/drift.dart';
import 'app_database.dart';

extension CapturesDao on AppDatabase {
  Future<void> insertCapture({
    required String id,
    required String imagePath,
    String? sourceApp,
  }) async {
    await into(captures).insert(CapturesCompanion.insert(
      id: id,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      imagePath: imagePath,
      sourceApp: Value(sourceApp),
      status: 'PENDING',
    ));
  }

  Future<void> setProcessing(String id) =>
      (update(captures)..where((t) => t.id.equals(id)))
          .write(CapturesCompanion(status: Value('PROCESSING')));

  Future<void> setOcrResult(
      {required String id,
      required String text,
      String? metaJson}) async {
    await (update(captures)..where((t) => t.id.equals(id))).write(
      CapturesCompanion(
        ocrText: Value(text),
        status: const Value('PROCESSED'),
        metaJson: Value(metaJson),
      ),
    );
  }

  Stream<List<Capture>> watchCaptures() =>
      (select(captures)..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch().map(
        (rows) => rows.map((r) => Capture.fromData(r)).toList(),
      );

  Future<void> insertExpenseFromParser({
    required String id,
    String? captureId,
    required int dateEpochMs,
    required int amountCents,
    required String currency,
    String? vendor,
    String? notes,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await into(expenses).insert(ExpensesCompanion.insert(
      id: id,
      captureId: Value(captureId),
      date: dateEpochMs,
      amountCents: amountCents,
      currency: currency,
      vendor: Value(vendor),
      notes: Value(notes),
      createdAt: now,
      updatedAt: now,
    ));
  }
}

// Pequeño modelo de proyección para la UI (opcional)
class Capture {
  final String id, imagePath, status;
  final String? ocrText;
  final int createdAt;
  Capture({required this.id, required this.imagePath, required this.status, required this.createdAt, this.ocrText});
  factory Capture.fromData(CapturesData d) =>
      Capture(id: d.id, imagePath: d.imagePath, status: d.status, createdAt: d.createdAt, ocrText: d.ocrText);
}
```

> Genera el código de Drift:

```bash
flutter pub run build_runner build -d
```

---

# 4) Servicios core: guardar archivo, OCR, parser

## `lib/core/file_store.dart`

```dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

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
```

## `lib/core/ocr_engine.dart` (ML Kit)

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  final String text;
  final Map<String, dynamic> meta;
  OcrResult(this.text, this.meta);
}

abstract class OcrEngine {
  Future<OcrResult> run(String imagePath);
}

class MlKitEngine implements OcrEngine {
  @override
  Future<OcrResult> run(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await recognizer.processImage(input);
      final blocks = res.blocks.length;
      final lines = res.blocks.fold<int>(0, (a, b) => a + b.lines.length);
      return OcrResult(res.text, {'engine': 'mlkit', 'blocks': blocks, 'lines': lines});
    } finally {
      await recognizer.close();
    }
  }
}
```

## `lib/core/parser.dart` (heurísticas MVP)

```dart
class ParsedExpense {
  final int amountCents;
  final String currency;
  final int dateEpochMs;
  final String? vendor;
  final String? notes;
  ParsedExpense({required this.amountCents, required this.currency, required this.dateEpochMs, this.vendor, this.notes});
}

class Parser {
  // PEN, S/ 10.50, $ 4.20, 12,34 etc.
  static final _money = RegExp(r'(?i)(S\/|PEN|\$|USD)\s*([\d][\d\.\,]*)');
  static final _date1 = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})'); // dd/mm/yyyy
  static int _toCents(String s) {
    // normaliza "10.50", "10,50"
    final norm = s.replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(norm) ?? 0;
    return (v * 100).round();
  }

  static ParsedExpense fromOcr(String text, {int? fallbackDateEpoch}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final currencyMatch = _money.firstMatch(text);
    final int amountCents = currencyMatch != null ? _toCents(currencyMatch.group(2)!) : 0;
    final String currency = currencyMatch != null
        ? (currencyMatch.group(1)!.toUpperCase().contains('USD') || currencyMatch.group(1) == '\$' ? 'USD' : 'PEN')
        : 'PEN';

    int dateMs = fallbackDateEpoch ?? now;
    final dm = _date1.firstMatch(text);
    if (dm != null) {
      final d = int.parse(dm.group(1)!);
      final m = int.parse(dm.group(2)!);
      final y = int.parse(dm.group(3)!);
      final yyyy = (y < 100) ? (2000 + y) : y;
      dateMs = DateTime(yyyy, m, d).millisecondsSinceEpoch;
    }

    // vendor: primera línea "fuerte" (heurística simple)
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    String? vendor;
    if (lines.isNotEmpty) {
      final first = lines.first;
      if (!first.toLowerCase().contains('total') && !first.toLowerCase().contains('factura')) {
        vendor = first;
      }
    }

    return ParsedExpense(
      amountCents: amountCents,
      currency: currency,
      dateEpochMs: dateMs,
      vendor: vendor,
      notes: null,
    );
  }
}
```

---

# 5) UI + Share Handler + Pegado del flujo

## `lib/features/inbox/inbox_page.dart`

```dart
import 'package:flutter/material.dart';
import '../../data/app_database.dart';

class InboxPage extends StatelessWidget {
  final AppDatabase db;
  const InboxPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('mis_gastos 🐾💸')),
      body: StreamBuilder(
        stream: db.watchCaptures(),
        builder: (context, snapshot) {
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Comparte una captura para empezar'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: const Icon(Icons.image),
                title: Text('${c.status} • ${DateTime.fromMillisecondsSinceEpoch(c.createdAt)}'),
                subtitle: Text((c.ocrText ?? '').take(80)),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}

extension _Str on String {
  String take(int n) => length <= n ? this : substring(0, n) + '…';
}
```

## `lib/main.dart`

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:share_handler/share_handler.dart';
import 'package:uuid/uuid.dart';
import 'core/file_store.dart';
import 'core/ocr_engine.dart';
import 'core/parser.dart';
import 'data/app_database.dart';
import 'data/daos.dart';
import 'features/inbox/inbox_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(mis_gastosApp());
}

class mis_gastosApp extends StatefulWidget {
  @override
  State<mis_gastosApp> createState() => _mis_gastosAppState();
}

class _mis_gastosAppState extends State<mis_gastosApp> {
  final db = AppDatabase();
  final _uuid = const Uuid();
  final _ocr = MlKitEngine();
  StreamSubscription<SharedMedia>? _sub;

  @override
  void initState() {
    super.initState();
    _initShareHandler();
  }

  Future<void> _initShareHandler() async {
    final share = ShareHandlerPlatform.instance;
    final initial = await share.getInitialSharedMedia();
    if (initial != null) { _handleShare(initial); }
    _sub = share.sharedMediaStream.listen(_handleShare);
  }

  Future<void> _handleShare(SharedMedia media) async {
    for (final att in media.attachments) {
      if (att.type == SharedAttachmentType.image && att.path != null) {
        final localPath = await FileStore.persistIncomingFile(att.path!);
        final id = _uuid.v4();
        await db.insertCapture(id: id, imagePath: localPath);
        await db.setProcessing(id);
        // OCR
        final res = await _ocr.run(localPath);
        await db.setOcrResult(id: id, text: res.text);
        // Parse → expense
        final parsed = Parser.fromOcr(res.text, fallbackDateEpoch: DateTime.now().millisecondsSinceEpoch);
        // regla de umbral (no compartir/agregar si es < S/3), pero igual lo guardamos como gasto
        await db.insertExpenseFromParser(
          id: _uuid.v4(),
          captureId: id,
          dateEpochMs: parsed.dateEpochMs,
          amountCents: parsed.amountCents,
          currency: parsed.currency,
          vendor: parsed.vendor,
          notes: parsed.notes,
        );
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: InboxPage(db: db),
    );
  }
}
```

> Ejecuta el codegen de Drift antes de compilar:

```bash
flutter pub run build_runner build -d
flutter run
```

Ahora:

* Abre tu galería / app de fotos → **Compartir** una captura → elige **mis_gastos**.
* Deberías verla en la lista con `PENDING` → `PROCESSED` y el snippet del texto OCR.
* Ya se crea también un **expense** básico con monto/fecha si los detecta.

---

# 6) Próximos pasos (rápidos)

1. **Detalle de gasto**: pantalla para editar `amount`, `currency`, `vendor`, `notes`.
2. **Búsqueda**: añade FTS5 (opcional) para buscar en `ocrText`/`vendor`.
3. **Compartir gasto 3–4 personas**: agrega un botón “Compartir” en detalle (más adelante le conectamos backend de links firmados).
4. **Round-Robin**: crea las tablas `groups`, `group_members`, `rr_cycles`, `rr_assignments` (ya te las dejé en el diseño anterior) y un servicio `nextAssignee()`.

---

# 7) Mini diagrama de este MVP (Mermaid)

```mermaid
flowchart LR
  A[Share Intent (Android)] --> B[FileStore: copiar imagen a app dir]
  B --> C[DB.insertCapture PENDING]
  C --> D[OCR ML Kit]
  D --> E[DB.setOcrResult PROCESSED]
  E --> F[Parser: total/fecha/vendor]
  F --> G[DB.insertExpense]
  G --> H[UI Inbox: lista de capturas/gastos]
```

---

¿Listo para compilar? Si te tira algún error en versiones/compat, pégame el log y lo resolvemos. Cuando esto corra, en la siguiente vuelta añadimos el **botón Compartir gasto (3–4)** y el esqueleto para **Round-Robin**.
