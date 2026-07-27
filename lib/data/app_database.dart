import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'database_key_store.dart';
import 'sqlcipher_migrator.dart';
import 'sqlcipher_runtime.dart';

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
  TextColumn get ocrConfidence => text().nullable()(); // Nivel de confianza del OCR (JSON)
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
  TextColumn get categoryId => text().references(Categories, #id)(); // FK a Categories
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
  TextColumn get categoryId => text().nullable().references(Categories, #id)(); // FK a Categories
  TextColumn get subcategoryId => text().nullable().references(Subcategories, #id)(); // FK a Subcategories
  TextColumn get account => text().nullable()(); // BCP Soles, Visa Light, etc.
  TextColumn get vendor => text().nullable()(); // Destinatario/Proveedor
  TextColumn get description => text().nullable()(); // Descripción detallada
  TextColumn get notes => text().nullable()(); // Notas generadas por IA
  TextColumn get sourceApp => text().nullable()(); // Yape, Binance, Banco, etc.
  TextColumn get source => text().nullable()(); // De dónde viene el dinero (para ingresos)
  TextColumn get destination => text().nullable()(); // A dónde va el dinero (para gastos)
  TextColumn get origination => text().nullable()(); // Origen de la transacción
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Captures, Categories, Subcategories, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 1;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
      await _initializeDefaultCategories();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // En desarrollo, simplemente recreamos todo
      await m.drop(expenses);
      await m.drop(subcategories);
      await m.drop(categories);
      await m.drop(captures);
      await m.createAll();
      await _initializeDefaultCategories();
    },
  );

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
      SubcategoriesCompanion.insert(id: 'sub_1', categoryId: 'cat_1', name: 'Carnes y pollo', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_2', categoryId: 'cat_1', name: 'Vegetales y verduras', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_3', categoryId: 'cat_1', name: 'Verduras y túbérculos', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_4', categoryId: 'cat_1', name: 'Frutas', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_5', categoryId: 'cat_1', name: 'Lácteos', order: 4, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_6', categoryId: 'cat_1', name: 'Pan y cereales', order: 5, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_7', categoryId: 'cat_1', name: 'Snacks', order: 6, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_8', categoryId: 'cat_1', name: 'Bebidas', order: 7, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_9', categoryId: 'cat_1', name: 'Comidas fuera', order: 8, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_10', categoryId: 'cat_1', name: 'Supermercado', order: 9, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_11', categoryId: 'cat_1', name: 'Otros', order: 10, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Transporte
      SubcategoriesCompanion.insert(id: 'sub_12', categoryId: 'cat_2', name: 'Taxi', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_13', categoryId: 'cat_2', name: 'Uber/Didi', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_14', categoryId: 'cat_2', name: 'Bus', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_15', categoryId: 'cat_2', name: 'Metro', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_16', categoryId: 'cat_2', name: 'Gasolina', order: 4, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_17', categoryId: 'cat_2', name: 'Estacionamiento', order: 5, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_18', categoryId: 'cat_2', name: 'Otros', order: 6, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Servicios
      SubcategoriesCompanion.insert(id: 'sub_19', categoryId: 'cat_3', name: 'Luz', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_20', categoryId: 'cat_3', name: 'Agua', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_21', categoryId: 'cat_3', name: 'Internet', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_22', categoryId: 'cat_3', name: 'Teléfono', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_23', categoryId: 'cat_3', name: 'Streaming', order: 4, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_24', categoryId: 'cat_3', name: 'Software', order: 5, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_25', categoryId: 'cat_3', name: 'Otros', order: 6, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Salud
      SubcategoriesCompanion.insert(id: 'sub_26', categoryId: 'cat_4', name: 'Medicinas', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_27', categoryId: 'cat_4', name: 'Doctor', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_28', categoryId: 'cat_4', name: 'Farmacia', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_29', categoryId: 'cat_4', name: 'Seguro', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_30', categoryId: 'cat_4', name: 'Otros', order: 4, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Entretenimiento
      SubcategoriesCompanion.insert(id: 'sub_31', categoryId: 'cat_5', name: 'Cine', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_32', categoryId: 'cat_5', name: 'Música', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_33', categoryId: 'cat_5', name: 'Juegos', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_34', categoryId: 'cat_5', name: 'Deportes', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_35', categoryId: 'cat_5', name: 'Otros', order: 4, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Educación
      SubcategoriesCompanion.insert(id: 'sub_36', categoryId: 'cat_6', name: 'Cursos', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_37', categoryId: 'cat_6', name: 'Libros', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_38', categoryId: 'cat_6', name: 'Materiales', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_39', categoryId: 'cat_6', name: 'Otros', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Familia
      SubcategoriesCompanion.insert(id: 'sub_40', categoryId: 'cat_7', name: 'Regalos', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_41', categoryId: 'cat_7', name: 'Ayuda económica', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_42', categoryId: 'cat_7', name: 'Actividades', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_43', categoryId: 'cat_7', name: 'Otros', order: 3, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      
      // Otros
      SubcategoriesCompanion.insert(id: 'sub_44', categoryId: 'cat_8', name: 'Misceláneos', order: 0, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_45', categoryId: 'cat_8', name: 'Emergencias', order: 1, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
      SubcategoriesCompanion.insert(id: 'sub_46', categoryId: 'cat_8', name: 'Otros', order: 2, createdAt: DateTime.now().millisecondsSinceEpoch, updatedAt: DateTime.now().millisecondsSinceEpoch),
    ];

    for (final subcategory in defaultSubcategories) {
      await into(subcategories).insert(subcategory);
    }
  }

}

LazyDatabase _open() {
  return LazyDatabase(() async {
    configureSqlCipherRuntime();
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'misgastos.sqlite'));
    final key = await SecureDatabaseKeyStore().getOrCreateKey();
    const migrator = SqlCipherMigrator();
    await migrator.prepare(file, key);
    return NativeDatabase.createInBackground(
      file,
      setup: (database) => migrator.configure(database, key),
      isolateSetup: configureSqlCipherRuntime,
    );
  });
}
