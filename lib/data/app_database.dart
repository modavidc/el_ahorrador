import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite;

part 'app_database.g.dart';

class Captures extends Table {
  TextColumn get id => text()(); // uuid
  IntColumn get createdAt => integer()(); // epoch ms
  TextColumn get sourceApp => text().nullable()();
  TextColumn get imagePath => text()();
  TextColumn get hash => text().nullable()();
  TextColumn get lang => text().nullable()();
  TextColumn get status =>
      text()(); // PENDING | PROCESSING | PROCESSED | FAILED
  TextColumn get ocrText => text().nullable()();
  TextColumn get ocrConfidence =>
      text().nullable()(); // Nivel de confianza del OCR (JSON)
  TextColumn get metaJson => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get name => text()(); // Comida, Transporte, etc.
  TextColumn get icon => text()(); // 🍽️, 🚗, etc.
  TextColumn get color => text()(); // orange, blue, etc.
  IntColumn get order => integer()(); // Para ordenar las categorías
  IntColumn get createdAt => integer()(); // epoch ms
  IntColumn get updatedAt => integer()(); // epoch ms
  @override
  Set<Column> get primaryKey => {id};
}

class Subcategories extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get categoryId =>
      text().references(Categories, #id)(); // FK a Categories
  TextColumn get name => text()(); // Carnes, Taxi, etc.
  IntColumn get order => integer()(); // Para ordenar las subcategorías
  IntColumn get createdAt => integer()(); // epoch ms
  IntColumn get updatedAt => integer()(); // epoch ms
  @override
  Set<Column> get primaryKey => {id};
}

class Expenses extends Table {
  TextColumn get id => text()(); // uuid
  TextColumn get captureId => text().nullable().references(Captures, #id)();
  IntColumn get date => integer()(); // epoch ms
  IntColumn get amountCents => integer()(); // 1050 = S/10.50
  TextColumn get currency => text().withDefault(const Constant('PEN'))();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)(); // FK a Categories
  TextColumn get subcategoryId =>
      text().nullable().references(Subcategories, #id)(); // FK a Subcategories
  TextColumn get account => text().nullable()(); // BCP Soles, Visa Light, etc.
  TextColumn get vendor => text().nullable()(); // Destinatario/Proveedor
  TextColumn get description => text().nullable()(); // Descripción detallada
  TextColumn get notes => text().nullable()(); // Notas generadas por IA
  TextColumn get sourceApp => text().nullable()(); // Yape, Binance, Banco, etc.
  TextColumn get source =>
      text().nullable()(); // De dónde viene el dinero (para ingresos)
  TextColumn get destination =>
      text().nullable()(); // A dónde va el dinero (para gastos)
  TextColumn get origination => text().nullable()(); // Origen de la transacción
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Captures, Categories, Subcategories, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _createIntegrityIndexes();
      await _initializeDefaultCategories();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Older builds could create duplicates. Keep every accounting row and
        // detach only the repeated link before enforcing one expense/capture.
        await customStatement(
          'UPDATE expenses SET capture_id = NULL '
          'WHERE capture_id IS NOT NULL AND rowid NOT IN '
          '(SELECT MIN(rowid) FROM expenses WHERE capture_id IS NOT NULL '
          'GROUP BY capture_id)',
        );
        await customStatement(
          'UPDATE captures SET hash = NULL '
          'WHERE hash IS NOT NULL AND rowid NOT IN '
          '(SELECT MIN(rowid) FROM captures WHERE hash IS NOT NULL '
          'GROUP BY hash)',
        );
        await _createIntegrityIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIntegrityIndexes() async {
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS captures_hash_unique '
      'ON captures (hash) WHERE hash IS NOT NULL',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS expenses_capture_id_unique '
      'ON expenses (capture_id) WHERE capture_id IS NOT NULL',
    );
  }

  // Inicializar categorías por defecto
  Future<void> _initializeDefaultCategories() async {
    final defaultCategories = [
      CategoriesCompanion.insert(
        id: 'cat_1',
        name: 'Comida',
        icon: '🍽️',
        color: 'orange',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_2',
        name: 'Transporte',
        icon: '🚗',
        color: 'blue',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_3',
        name: 'Servicios',
        icon: '⚡',
        color: 'purple',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_4',
        name: 'Salud',
        icon: '🏥',
        color: 'red',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_5',
        name: 'Entretenimiento',
        icon: '🎬',
        color: 'pink',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_6',
        name: 'Educación',
        icon: '📚',
        color: 'green',
        order: 5,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_7',
        name: 'Familia',
        icon: '👨‍👩‍👧‍👦',
        color: 'teal',
        order: 6,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      CategoriesCompanion.insert(
        id: 'cat_8',
        name: 'Otros',
        icon: '📦',
        color: 'grey',
        order: 7,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ];

    for (final category in defaultCategories) {
      await into(categories).insert(category);
    }

    // Agregar subcategorías por defecto
    final defaultSubcategories = [
      // Comida
      SubcategoriesCompanion.insert(
        id: 'sub_1',
        categoryId: 'cat_1',
        name: 'Carnes y pollo',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_2',
        categoryId: 'cat_1',
        name: 'Vegetales y verduras',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_3',
        categoryId: 'cat_1',
        name: 'Verduras y túbérculos',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_4',
        categoryId: 'cat_1',
        name: 'Frutas',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_5',
        categoryId: 'cat_1',
        name: 'Lácteos',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_6',
        categoryId: 'cat_1',
        name: 'Pan y cereales',
        order: 5,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_7',
        categoryId: 'cat_1',
        name: 'Snacks',
        order: 6,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_8',
        categoryId: 'cat_1',
        name: 'Bebidas',
        order: 7,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_9',
        categoryId: 'cat_1',
        name: 'Comidas fuera',
        order: 8,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_10',
        categoryId: 'cat_1',
        name: 'Supermercado',
        order: 9,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_11',
        categoryId: 'cat_1',
        name: 'Otros',
        order: 10,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Transporte
      SubcategoriesCompanion.insert(
        id: 'sub_12',
        categoryId: 'cat_2',
        name: 'Taxi',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_13',
        categoryId: 'cat_2',
        name: 'Uber/Didi',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_14',
        categoryId: 'cat_2',
        name: 'Bus',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_15',
        categoryId: 'cat_2',
        name: 'Metro',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_16',
        categoryId: 'cat_2',
        name: 'Gasolina',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_17',
        categoryId: 'cat_2',
        name: 'Estacionamiento',
        order: 5,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_18',
        categoryId: 'cat_2',
        name: 'Otros',
        order: 6,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Servicios
      SubcategoriesCompanion.insert(
        id: 'sub_19',
        categoryId: 'cat_3',
        name: 'Luz',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_20',
        categoryId: 'cat_3',
        name: 'Agua',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_21',
        categoryId: 'cat_3',
        name: 'Internet',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_22',
        categoryId: 'cat_3',
        name: 'Teléfono',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_23',
        categoryId: 'cat_3',
        name: 'Streaming',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_24',
        categoryId: 'cat_3',
        name: 'Software',
        order: 5,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_25',
        categoryId: 'cat_3',
        name: 'Otros',
        order: 6,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Salud
      SubcategoriesCompanion.insert(
        id: 'sub_26',
        categoryId: 'cat_4',
        name: 'Medicinas',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_27',
        categoryId: 'cat_4',
        name: 'Doctor',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_28',
        categoryId: 'cat_4',
        name: 'Farmacia',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_29',
        categoryId: 'cat_4',
        name: 'Seguro',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_30',
        categoryId: 'cat_4',
        name: 'Otros',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Entretenimiento
      SubcategoriesCompanion.insert(
        id: 'sub_31',
        categoryId: 'cat_5',
        name: 'Cine',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_32',
        categoryId: 'cat_5',
        name: 'Música',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_33',
        categoryId: 'cat_5',
        name: 'Juegos',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_34',
        categoryId: 'cat_5',
        name: 'Deportes',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_35',
        categoryId: 'cat_5',
        name: 'Otros',
        order: 4,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Educación
      SubcategoriesCompanion.insert(
        id: 'sub_36',
        categoryId: 'cat_6',
        name: 'Cursos',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_37',
        categoryId: 'cat_6',
        name: 'Libros',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_38',
        categoryId: 'cat_6',
        name: 'Materiales',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_39',
        categoryId: 'cat_6',
        name: 'Otros',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Familia
      SubcategoriesCompanion.insert(
        id: 'sub_40',
        categoryId: 'cat_7',
        name: 'Regalos',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_41',
        categoryId: 'cat_7',
        name: 'Ayuda económica',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_42',
        categoryId: 'cat_7',
        name: 'Actividades',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_43',
        categoryId: 'cat_7',
        name: 'Otros',
        order: 3,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),

      // Otros
      SubcategoriesCompanion.insert(
        id: 'sub_44',
        categoryId: 'cat_8',
        name: 'Misceláneos',
        order: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_45',
        categoryId: 'cat_8',
        name: 'Emergencias',
        order: 1,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
      SubcategoriesCompanion.insert(
        id: 'sub_46',
        categoryId: 'cat_8',
        name: 'Otros',
        order: 2,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    ];

    for (final subcategory in defaultSubcategories) {
      await into(subcategories).insert(subcategory);
    }
  }
}

LazyDatabase _open() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'misgastos.sqlite'));
    final key = await _DatabaseKey.loadOrCreate();
    await migratePlaintextDatabase(file, key);

    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        database.execute('PRAGMA key = "x\'${_hex(key)}\'"');
        // Fail closed if the linked native library is plain SQLite.
        final cipher = database.select('PRAGMA cipher_version');
        if (cipher.isEmpty) {
          throw StateError('SQLCipher is required to open the local database');
        }
        database.execute('PRAGMA cipher_memory_security = ON');
      },
    );
  });
}

class _DatabaseKey {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'local_database_key_v1';

  static Future<List<int>> loadOrCreate() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null) return base64Url.decode(stored);

    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: _storageKey, value: base64UrlEncode(key));
    return key;
  }
}

/// Converts a legacy plaintext database and reconciles files left by a process
/// termination at any point of the replacement sequence.
///
/// Public primarily so the crash-recovery state machine can be regression
/// tested without opening the application database singleton.
Future<void> migratePlaintextDatabase(File file, List<int> key) async {
  await reconcileInterruptedSqlcipherMigration(file, key);
  final encrypted = File('${file.path}.encrypted');
  final backup = File('${file.path}.plaintext-backup');

  if (!await file.exists() || !await _isPlaintextDatabase(file)) return;

  if (await encrypted.exists()) await encrypted.delete();

  final database = sqlite.sqlite3.open(file.path);
  try {
    final escapedPath = encrypted.path.replaceAll("'", "''");
    database.execute(
      'ATTACH DATABASE \'$escapedPath\' AS encrypted KEY "x\'${_hex(key)}\'"',
    );
    database.execute("SELECT sqlcipher_export('encrypted')");
    database.execute('DETACH DATABASE encrypted');
  } finally {
    database.dispose();
  }

  if (!await _canOpenEncryptedDatabase(encrypted, key)) {
    if (await encrypted.exists()) await encrypted.delete();
    throw StateError('SQLCipher migration produced an invalid database');
  }

  // Keep the original only during the atomic replacement. It is removed as
  // soon as the encrypted copy has been successfully opened and verified.
  if (await backup.exists()) await backup.delete();
  await file.rename(backup.path);
  await encrypted.rename(file.path);
  try {
    final verification = sqlite.sqlite3.open(file.path);
    try {
      verification.execute('PRAGMA key = "x\'${_hex(key)}\'"');
      verification.select('SELECT count(*) FROM sqlite_master');
    } finally {
      verification.dispose();
    }
    await backup.delete();
  } catch (_) {
    if (await file.exists()) await file.delete();
    await backup.rename(file.path);
    rethrow;
  }
}

typedef EncryptedDatabaseVerifier =
    Future<bool> Function(File file, List<int> key);

/// Repairs filesystem states left between migration renames.
Future<void> reconcileInterruptedSqlcipherMigration(
  File file,
  List<int> key, {
  EncryptedDatabaseVerifier verifier = _canOpenEncryptedDatabase,
}) async {
  final encrypted = File('${file.path}.encrypted');
  final backup = File('${file.path}.plaintext-backup');

  // A verified encrypted copy is always the newest complete state. Promoting
  // it first also covers termination after moving the plaintext original out
  // of the way but before the second rename.
  if (!await file.exists() && await encrypted.exists()) {
    if (await verifier(encrypted, key)) {
      await encrypted.rename(file.path);
      if (await backup.exists()) await backup.delete();
      return;
    }
    await encrypted.delete();
  }
  if (!await file.exists() && await backup.exists()) {
    await backup.rename(file.path);
  }
  if (!await file.exists()) return;

  // Termination after promotion leaves a valid main database and a stale
  // plaintext backup. Remove it only after proving the promoted file opens.
  if (!await _isPlaintextDatabase(file)) {
    if (await backup.exists() && await verifier(file, key)) {
      await backup.delete();
    }
    if (await encrypted.exists()) await encrypted.delete();
    return;
  }
}

Future<bool> _isPlaintextDatabase(File file) async {
  final header = await file
      .openRead(0, 16)
      .fold<List<int>>([], (a, b) => a..addAll(b));
  return ascii.decode(header, allowInvalid: true) == 'SQLite format 3\u0000';
}

Future<bool> _canOpenEncryptedDatabase(File file, List<int> key) async {
  if (!await file.exists()) return false;
  final database = sqlite.sqlite3.open(file.path);
  try {
    database.execute('PRAGMA key = "x\'${_hex(key)}\'"');
    database.select('SELECT count(*) FROM sqlite_master');
    return true;
  } catch (_) {
    return false;
  } finally {
    database.dispose();
  }
}

String _hex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
