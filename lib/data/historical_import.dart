// Import masivo, único, de las transacciones históricas extraídas de
// Z:\personal\finanzas\finanzas.html (vía extraer-finanzas.js) hacia la BD local.
// Idempotente: si ya existe un Expense con el mismo sourceApp+fecha+monto+descripción,
// la fila se omite en vez de duplicarse (así se puede correr el botón más de una vez).

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'daos.dart';
import 'category_repository.dart';
import '../models/category_model.dart';
import 'money_manager_taxonomy.dart';

const String kHistoricalImportSourceApp = 'finanzas-html-import';
const String _assetPath = 'assets/import/importar.csv';

class _CatMap {
  final String category;
  final String subcategory;
  const _CatMap(this.category, this.subcategory);
}

// Categorías nuevas que no existen por default en El Ahorrador — se crean
// (idempotente) antes de importar. Ver Z:\el_ahorrador\IMPORT_MASIVO_SPEC.md sección 3.
const Map<String, List<String>> _newCategories = {
  'Vivienda': ['Renta', 'Mantenimiento', 'Gas', 'Otros'],
  'Cuidado Personal': ['Peluquería', 'Productos higiénicos', 'Otros'],
  'Comisiones': ['Bancos', 'Ligo', 'PayPal', 'Otros'],
  'Préstamos': ['Dados', 'Otros'],
  'Electrónica': ['Audífonos', 'Baterías', 'Otros'],
  'Ropa': ['Moda', 'Otros'],
  'Hogar': ['Baños', 'Lavandería', 'Limpieza', 'Otros'],
};

const Map<String, String> _newCategoryIcons = {
  'Vivienda': '🏠',
  'Cuidado Personal': '🧴',
  'Comisiones': '💳',
  'Préstamos': '🤝',
  'Electrónica': '🔌',
  'Ropa': '👕',
  'Hogar': '🧹',
};

const Map<String, String> _newCategoryColors = {
  'Vivienda': 'brown',
  'Cuidado Personal': 'pink',
  'Comisiones': 'grey',
  'Préstamos': 'amber',
  'Electrónica': 'indigo',
  'Ropa': 'cyan',
  'Hogar': 'lime',
};

// Mapeo category>subcategory del CSV (taxonomía de MoneyManager) -> El Ahorrador.
// Key = "<category> > <subcategory>" tal cual vienen en el CSV (subcategory puede ser '').
// ignore: unused_element
final Map<String, _CatMap> _categoryMapping = {
  'Comida > Bebidas': const _CatMap('Comida', 'Bebidas'),
  'Comida > Agua': const _CatMap('Comida', 'Bebidas'),
  'Comida > Comidas fuera': const _CatMap('Comida', 'Comidas fuera'),
  'Comida > Frutas': const _CatMap('Comida', 'Frutas'),
  'Comida > Snacks': const _CatMap('Comida', 'Snacks'),
  'Comida > Abarrotes': const _CatMap('Comida', 'Supermercado'),
  'Comida > Carnes, aves y pescado': const _CatMap('Comida', 'Carnes y pollo'),
  'Comida > Postres': const _CatMap('Comida', 'Postres'),
  'Transporte > Taxi': const _CatMap('Transporte', 'Taxi'),
  'Transporte > Autobús': const _CatMap('Transporte', 'Bus'),
  'Salud > Medicina': const _CatMap('Salud', 'Medicinas'),
  'Educación > Inglés': const _CatMap('Educación', 'Cursos'),
  'Educación > Material escolar': const _CatMap('Educación', 'Materiales'),
  'Deportes > Fútbol': const _CatMap('Entretenimiento', 'Deportes'),
  'Entretenimiento > Baile': const _CatMap('Entretenimiento', 'Otros'),
  'Familia > Mamá': const _CatMap('Familia', 'Ayuda económica'),
  'Familia > Papá': const _CatMap('Familia', 'Ayuda económica'),
  'Servicios > Netflix': const _CatMap('Servicios', 'Streaming'),
  'Servicios > Google One': const _CatMap('Servicios', 'Software'),
  'Servicios > ChatGPT': const _CatMap('Servicios', 'Software'),
  'Servicios > Fitia': const _CatMap('Servicios', 'Software'),
  'Servicios > Upwork': const _CatMap('Servicios', 'Software'),
  'Servicios > Telefonía': const _CatMap('Servicios', 'Teléfono'),
  'Servicios > YouTube Premium': const _CatMap('Servicios', 'Streaming'),
  'Servicios > Otros': const _CatMap('Servicios', 'Otros'),
  'Vivienda > Luz': const _CatMap('Servicios', 'Luz'),
  'Vivienda > Internet': const _CatMap('Servicios', 'Internet'),
  'Vivienda > Gas': const _CatMap('Vivienda', 'Gas'),
  'Vivienda > Renta': const _CatMap('Vivienda', 'Renta'),
  'Vivienda > Mantenimiento': const _CatMap('Vivienda', 'Mantenimiento'),
  'Vivienda > ': const _CatMap('Vivienda', 'Otros'),
  'Otros > ': const _CatMap('Otros', 'Misceláneos'),
  'Cuidado Personal > Peluquería': const _CatMap(
    'Cuidado Personal',
    'Peluquería',
  ),
  'Cuidado Personal > Productos higiénicos': const _CatMap(
    'Cuidado Personal',
    'Productos higiénicos',
  ),
  'Comisiones > Bancos': const _CatMap('Comisiones', 'Bancos'),
  'Comisiones > Ligo': const _CatMap('Comisiones', 'Ligo'),
  'Comisiones > PayPal': const _CatMap('Comisiones', 'PayPal'),
  'Préstamos Dados > Marcos': const _CatMap('Préstamos', 'Dados'),
  'Préstamos Dados > Ramón': const _CatMap('Préstamos', 'Dados'),
  'Préstamos Dados > Valentina': const _CatMap('Préstamos', 'Dados'),
  'Electrónica > Audífonos': const _CatMap('Electrónica', 'Audífonos'),
  'Electrónica > Baterías': const _CatMap('Electrónica', 'Baterías'),
  'Ropa > Moda': const _CatMap('Ropa', 'Moda'),
  'Mantenimiento del hogar > Baños': const _CatMap('Hogar', 'Baños'),
  'Mantenimiento del hogar > Lavandería': const _CatMap('Hogar', 'Lavandería'),
  'Mantenimiento del hogar > Limpieza': const _CatMap('Hogar', 'Limpieza'),
  'Oficina > Impresiones': const _CatMap('Otros', 'Misceláneos'),
  'Seguros > Tarjeta de Crédito': const _CatMap('Otros', 'Misceláneos'),
  'Ayuda Social > Donaciones': const _CatMap('Otros', 'Misceláneos'),
};

Future<void> runHistoricalImport(
  AppDatabase db,
  void Function(String) log,
) async {
  log('Validando el catálogo exacto de Money Manager...');

  log('Cargando CSV desde $_assetPath...');
  final csvText = await rootBundle.loadString(_assetPath);
  final rows = _parseCsv(csvText);
  log('Filas totales en CSV: ${rows.length}');

  final transactionRows = rows
      .where((row) => row['type'] == 'expense' || row['type'] == 'income')
      .toList();
  log('Transacciones a procesar: ${transactionRows.length}');

  var imported = 0;
  var skippedDup = 0;
  var errors = 0;
  var unmapped = 0;
  var repairedSigns = 0;

  for (final row in transactionRows) {
    final date = row['date'] ?? '';
    final type = row['type'] ?? '';
    final content = row['content'] ?? '';
    final amountStr = row['amount'] ?? '';
    final account = row['account'] ?? '';
    final category = row['category'] ?? '';
    final subcategory = row['subcategory'] ?? '';

    if (date.isEmpty || amountStr.isEmpty) {
      log('SKIP (sin fecha/monto): $content');
      errors++;
      continue;
    }

    final amount = double.tryParse(amountStr);
    if (amount == null) {
      log('SKIP (monto inválido "$amountStr"): $content');
      errors++;
      continue;
    }
    final magnitudeCents = (amount.abs() * 100).round();
    final amountCents = type == 'income' ? magnitudeCents : -magnitudeCents;

    final categoryIndex = moneyManagerCategorySeeds.indexWhere(
      (seed) => seed.name == category,
    );
    if (categoryIndex < 0) {
      log('ERROR: categoría de Money Manager no existe: "$category"');
      errors++;
      continue;
    }
    final seed = moneyManagerCategorySeeds[categoryIndex];
    final subcategoryIndex = subcategory.isEmpty
        ? -1
        : seed.subcategories.indexOf(subcategory);
    if (subcategory.isNotEmpty && subcategoryIndex < 0) {
      log('ERROR: subcategoría no existe en "$category": "$subcategory"');
      errors++;
      continue;
    }
    final targetCategory = category;
    final targetSubcategory = subcategory.isEmpty ? null : subcategory;

    final int dateEpochMs;
    try {
      dateEpochMs = DateTime.parse(date).millisecondsSinceEpoch;
    } catch (_) {
      log('SKIP (fecha inválida "$date"): $content');
      errors++;
      continue;
    }
    final currency = _inferCurrency(account);

    final existingRows =
        await (db.select(db.expenses)..where(
              (e) =>
                  e.date.equals(dateEpochMs) &
                  e.description.equals(content) &
                  e.sourceApp.equals(kHistoricalImportSourceApp),
            ))
            .get();
    final existing = existingRows.cast<Expense?>().firstWhere(
      (expense) => expense!.amountCents.abs() == magnitudeCents,
      orElse: () => null,
    );
    if (existing != null) {
      await (db.update(
        db.expenses,
      )..where((e) => e.id.equals(existing.id))).write(
        ExpensesCompanion(
          amountCents: Value(amountCents),
          categoryId: Value('mm_cat_${categoryIndex + 1}'),
          subcategoryId: Value(
            subcategoryIndex < 0
                ? null
                : 'mm_sub_${categoryIndex + 1}_${subcategoryIndex + 1}',
          ),
          vendor: const Value(null),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      if (existing.amountCents != amountCents) repairedSigns++;
      skippedDup++;
      continue;
    }

    try {
      await db.insertExpenseFromParser(
        id: const Uuid().v4(),
        dateEpochMs: dateEpochMs,
        amountCents: amountCents,
        currency: currency,
        categoryId: targetCategory,
        subcategoryId: targetSubcategory,
        account: account.isEmpty ? null : account,
        vendor: null,
        description: content,
        sourceApp: kHistoricalImportSourceApp,
      );
      imported++;
    } catch (e) {
      log('ERROR insertando "$content": $e');
      errors++;
    }
  }

  log('');
  log('=== RESUMEN ===');
  log('Importados: $imported');
  log('Ya existían (omitidos): $skippedDup');
  log('Signos históricos reparados: $repairedSigns');
  log('Sin mapeo de categoría (fueron a Otros > Misceláneos): $unmapped');
  log('Errores/filas sin datos: $errors');
}

// ignore: unused_element
Future<void> _ensureCategories(
  CategoryRepository repo,
  void Function(String) log,
) async {
  final now = DateTime.now();

  for (final entry in _newCategories.entries) {
    final name = entry.key;
    final existing = await repo.getCategoryByName(name);
    if (existing != null) {
      for (final subName in entry.value) {
        final subExisting = await repo.getSubcategoryByName(name, subName);
        if (subExisting == null) {
          await repo.addSubcategory(
            existing.id,
            SubcategoryModel(
              id: 'tmp',
              name: subName,
              order: existing.subcategories.length,
              createdAt: now,
              updatedAt: now,
            ),
          );
          log('  + subcategoría "$subName" creada en "$name"');
        }
      }
      continue;
    }

    final model = CategoryModel(
      id: 'tmp',
      name: name,
      icon: _newCategoryIcons[name] ?? '📦',
      color: _newCategoryColors[name] ?? 'grey',
      order: 100,
      createdAt: now,
      updatedAt: now,
      subcategories: [
        for (var i = 0; i < entry.value.length; i++)
          SubcategoryModel(
            id: 'tmp$i',
            name: entry.value[i],
            order: i,
            createdAt: now,
            updatedAt: now,
          ),
      ],
    );
    final created = await repo.addCategory(model);
    log('Categoría nueva "$name" creada (id=${created?.id})');
  }

  // "Postres" es una subcategoría nueva dentro de la categoría "Comida" ya existente.
  final comida = await repo.getCategoryByName('Comida');
  if (comida != null) {
    final postres = await repo.getSubcategoryByName('Comida', 'Postres');
    if (postres == null) {
      await repo.addSubcategory(
        comida.id,
        SubcategoryModel(
          id: 'tmp',
          name: 'Postres',
          order: comida.subcategories.length,
          createdAt: now,
          updatedAt: now,
        ),
      );
      log('Subcategoría "Postres" creada dentro de "Comida"');
    }
  }
}

String _inferCurrency(String account) {
  final a = account.toLowerCase();
  if (a.contains('usdt')) return 'USDT';
  if (a.contains('dólar') || a.contains('dolar') || a.contains('usd')) {
    return 'USD';
  }
  return 'PEN';
}

List<Map<String, String>> _parseCsv(String text) {
  final lines = text.trim().split(RegExp(r'\r?\n'));
  if (lines.isEmpty) return [];
  final header = _splitCsvLine(lines.first);
  final rows = <Map<String, String>>[];
  for (final line in lines.skip(1)) {
    if (line.trim().isEmpty) continue;
    final cols = _splitCsvLine(line);
    final row = <String, String>{};
    for (var i = 0; i < header.length; i++) {
      row[header[i]] = i < cols.length ? cols[i] : '';
    }
    rows.add(row);
  }
  return rows;
}

// Split respetando comillas (RFC4180 básico) — mismo criterio que
// Z:\personal\finanzas\moneymanager\importar-csv.js, porque content/subcategory
// pueden traer comas dentro (ej. "Carnes, aves y pescado").
List<String> _splitCsvLine(String line) {
  final cols = <String>[];
  var cur = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (c == ',' && !inQuotes) {
      cols.add(cur.toString());
      cur = StringBuffer();
    } else {
      cur.write(c);
    }
  }
  cols.add(cur.toString());
  return cols;
}
