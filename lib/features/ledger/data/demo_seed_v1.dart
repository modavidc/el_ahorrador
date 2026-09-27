import 'package:drift/drift.dart';

import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/database/daos.dart';

/// Development data equivalent to `genData()` of the v1 prototype
/// (`design/Money Manager IA v2.dc.html`): June to 25 September 2026, same
/// pseudo-random sequence, so the app can be compared screen by screen with
/// the design. Only loaded with `--dart-define=DEMO_DATA=true` in debug
/// builds, or by tests.
abstract final class DemoSeed {
  static const enabled = bool.fromEnvironment('DEMO_DATA');

  /// "Today" in the prototype: Friday 25 September 2026, 22:27.
  static final today = DateTime(2026, 9, 25, 22, 27);

  static Future<void> load(AppDatabase db) async {
    final transactions = generate();
    final accountIds = await _accounts(db);
    final categoryIds = <String, String>{};
    final subcategoryIds = <String, String>{};
    final now = today.millisecondsSinceEpoch;

    Future<String> category(String name) async {
      final existing = categoryIds[name];
      if (existing != null) return existing;
      final id = 'demo_cat_${categoryIds.length + 1}';
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: name,
              icon: '',
              color: '',
              order: 1000 + categoryIds.length,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return categoryIds[name] = id;
    }

    Future<String> subcategory(String categoryName, String name) async {
      final key = '$categoryName/$name';
      final existing = subcategoryIds[key];
      if (existing != null) return existing;
      final id = 'demo_sub_${subcategoryIds.length + 1}';
      await db
          .into(db.subcategories)
          .insert(
            SubcategoriesCompanion.insert(
              id: id,
              categoryId: await category(categoryName),
              name: name,
              order: subcategoryIds.length,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return subcategoryIds[key] = id;
    }

    await db.transaction(() async {
      for (final (name, cap) in budgets) {
        await db
            .into(db.budgets)
            .insert(
              BudgetsCompanion.insert(
                category: name,
                monthlyCapCents: cap * 100,
                updatedAt: now,
              ),
            );
      }
      for (final t in transactions) {
        final at = DateTime(
          2026,
          t.month + 1,
          t.day,
          t.hour,
          t.minute,
        ).millisecondsSinceEpoch;
        final cents = (t.amount * 100).round();
        final categoryId = await category(t.category);
        final subcategoryId = await subcategory(t.category, t.subcategory);
        if (t.type == 'transfer') {
          for (final (suffix, account, signed) in [
            ('out', t.account, -cents),
            ('in', t.toAccount!, cents),
          ]) {
            await db.insertExpenseFromParser(
              id: 'demo_${t.id}_$suffix',
              dateEpochMs: at,
              amountCents: signed,
              currency: 'PEN',
              accountId: accountIds[account],
              categoryId: categoryId,
              subcategoryId: subcategoryId,
              vendor: 'Transferencia',
              description: t.note,
              sourceApp: 'Manual',
              source: t.account,
              destination: t.toAccount,
              origination: 'demo_${t.id}',
            );
          }
          continue;
        }
        String? captureId;
        if (t.ocr != null) {
          captureId = 'demo_capture_${t.id}';
          await db.insertCapture(id: captureId, imagePath: '', hash: captureId);
          await db.setOcrResult(
            id: captureId,
            text: t.note,
            confidence: '${t.ocr}',
          );
        }
        await db.insertExpenseFromParser(
          id: 'demo_${t.id}',
          captureId: captureId,
          dateEpochMs: at,
          amountCents: t.type == 'income' ? cents : -cents,
          currency: 'PEN',
          accountId: accountIds[t.account],
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          description: t.note,
          sourceApp: t.method ?? 'Manual',
        );
      }
    });
  }

  /// The prototype's `BUDGET`.
  static const budgets = [
    ('Comida', 1100),
    ('Hogar', 1300),
    ('Transporte', 380),
    ('Servicios', 280),
    ('Suscripciones', 110),
    ('Ocio', 420),
    ('Compras', 450),
    ('Familia', 300),
    ('Salud', 120),
    ('Educación', 80),
  ];

  static Future<Map<String, String>> _accounts(AppDatabase db) async {
    final now = today.millisecondsSinceEpoch;
    Future<void> group(String id, String name, String type, int order) => db
        .into(db.accountGroups)
        .insertOnConflictUpdate(
          AccountGroupsCompanion.insert(
            id: id,
            name: name,
            type: Value(type),
            order: order,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await group(AppDatabase.defaultAccountGroupId, 'Efectivo', 'asset', 0);
    await group('demo_group_bank', 'Cuentas bancarias', 'asset', 1);
    await group('demo_group_card', 'Tarjetas de crédito', 'liability', 2);
    await group('demo_group_savings', 'Ahorros', 'asset', 3);

    final repository = AccountRepository(db);
    final ids = <String, String>{'Efectivo': AppDatabase.defaultAccountId};
    for (final (name, groupId, description, limit) in [
      ('BCP Soles', 'demo_group_bank', 'Incluye pagos Yape', null),
      ('Interbank Soles', 'demo_group_bank', 'Cuenta sueldo', null),
      ('BCP Visa', 'demo_group_card', null, 600000),
      ('BCP Ahorro', 'demo_group_savings', 'Meta: S/ 12,000', null),
    ]) {
      ids[name] = await repository.create(
        name: name,
        groupId: groupId,
        description: description,
        creditLimitCents: limit,
      );
    }
    await (db.update(db.accounts)
          ..where((a) => a.id.equals(AppDatabase.defaultAccountId)))
        .write(const AccountsCompanion(description: Value('En billetera')));
    for (final (name, start) in [
      ('Efectivo', 180),
      ('BCP Soles', 3400),
      ('Interbank Soles', 1650),
      ('BCP Visa', 0),
      ('BCP Ahorro', 8200),
    ]) {
      await repository.setStartingBalance(
        ids[name]!,
        startingBalanceCents: start * 100,
      );
    }
    return ids;
  }

  /// Direct port of the prototype's `genData()`.
  static List<DemoTransaction> generate() {
    final rng = _Mulberry32(11);
    T pick<T>(List<T> items) => items[(rng.next() * items.length).floor()];
    double amt(num a, num b) => ((a + rng.next() * (b - a)) * 10).round() / 10;
    (int, int) time(int h1, int h2) {
      final hour = h1 + (rng.next() * (h2 - h1)).floor();
      final minute = (rng.next() * 60).floor();
      return (hour, minute);
    }

    final out = <DemoTransaction>[];
    var id = 1;
    void add(
      int m,
      int d,
      String type,
      String cat,
      String sub,
      String note,
      String acc,
      double a, {
      (int, int)? at,
      String? method,
      String? to,
      int? ocr,
    }) {
      final (hour, minute) = at ?? time(8, 22);
      out.add(
        DemoTransaction(
          id: id++,
          month: m,
          day: d,
          hour: hour,
          minute: minute,
          type: type,
          category: cat,
          subcategory: sub,
          note: note,
          account: acc,
          amount: a,
          method: method,
          toAccount: to,
          ocr: ocr,
        ),
      );
    }

    for (final (m, days) in [(5, 30), (6, 31), (7, 31), (8, 25)]) {
      final sep = m == 8;
      add(
        m,
        1,
        'expense',
        'Hogar',
        'Alquiler',
        'Alquiler depa Surco',
        'BCP Soles',
        1200,
        at: (9, 5),
      );
      add(
        m,
        3,
        'expense',
        'Suscripciones',
        'Streaming',
        'Netflix Estándar',
        'BCP Visa',
        44.9,
        at: (6, 0),
      );
      add(
        m,
        5,
        'income',
        'Salario',
        'Quincena',
        'Quincena 1 · Medirec',
        'BCP Soles',
        2482,
        at: (10, 12),
      );
      add(
        m,
        7,
        'expense',
        'Suscripciones',
        'Música',
        'Spotify Premium',
        'BCP Visa',
        21.9,
        at: (6, 0),
      );
      add(
        m,
        8,
        'expense',
        'Servicios',
        'Luz',
        'Luz del Sur',
        'BCP Soles',
        amt(72, 104),
        at: (19, 40),
      );
      add(
        m,
        10,
        'expense',
        'Servicios',
        'Internet',
        'Claro Hogar 200 Mbps',
        'BCP Soles',
        99,
        at: (8, 30),
      );
      add(
        m,
        12,
        'expense',
        'Servicios',
        'Celular',
        'Plan Movistar',
        'BCP Visa',
        59.9,
        at: (7, 15),
      );
      add(
        m,
        14,
        'expense',
        'Suscripciones',
        'Streaming',
        'YouTube Premium',
        'BCP Visa',
        23.9,
        at: (6, 0),
      );
      add(
        m,
        15,
        'expense',
        'Familia',
        'Apoyo',
        'Apoyo mamá',
        'BCP Soles',
        250,
        method: 'Yape',
        at: (12, 30),
      );
      if (m >= 6)
        add(
          m,
          2,
          'expense',
          'Educación',
          'Cursos',
          'Platzi Expert',
          'BCP Visa',
          69,
          at: (6, 0),
        );
      if (m >= 7)
        add(
          m,
          18,
          'expense',
          'Suscripciones',
          'Almacenamiento',
          'iCloud 200 GB',
          'BCP Visa',
          12.9,
          at: (6, 0),
        );
      if (days >= 19)
        add(
          m,
          19,
          'income',
          'Salario',
          'Quincena',
          'Quincena 2 · Medirec',
          'Interbank Soles',
          2489,
          at: (10, 5),
        );
      if (days >= 20)
        add(
          m,
          20,
          'transfer',
          'Transferencia',
          'Ahorro',
          'BCP Soles → BCP Ahorro',
          'BCP Soles',
          500,
          to: 'BCP Ahorro',
          at: (11, 0),
        );
      if (days >= 24)
        add(
          m,
          24,
          'transfer',
          'Transferencia',
          'Pago tarjeta',
          'Pago BCP Visa',
          'Interbank Soles',
          1900,
          to: 'BCP Visa',
          at: (9, 20),
        );
      add(
        m,
        4,
        'transfer',
        'Transferencia',
        'Retiro',
        'Retiro cajero BCP',
        'BCP Soles',
        200,
        to: 'Efectivo',
        at: (18, 10),
      );
      if (days >= 18)
        add(
          m,
          18,
          'transfer',
          'Transferencia',
          'Retiro',
          'Retiro cajero BCP',
          'BCP Soles',
          150,
          to: 'Efectivo',
          at: (19, 30),
        );
      if (m == 5 || m == 7)
        add(
          m,
          28,
          'income',
          'Inversiones',
          'Fondos',
          'Rendimiento fondo mutuo',
          'BCP Ahorro',
          amt(80, 140),
          at: (8, 0),
        );
      if (m == 6)
        add(
          m,
          22,
          'income',
          'Freelance',
          'Diseño',
          'Logo para cafetería',
          'Interbank Soles',
          650,
          at: (17, 45),
        );
      if (sep)
        add(
          m,
          11,
          'income',
          'Freelance',
          'Diseño',
          'Landing para dentista',
          'Interbank Soles',
          480,
          at: (18, 20),
        );
      if (sep)
        add(
          m,
          13,
          'expense',
          'Compras',
          'Ropa',
          'Zapatillas Nike Pegasus',
          'BCP Visa',
          389,
          at: (16, 40),
        );
      if (m == 7)
        add(
          m,
          23,
          'expense',
          'Salud',
          'Consulta',
          'Consulta dermatólogo',
          'BCP Visa',
          150,
          at: (10, 30),
        );
      for (var d = 1; d <= days; d++) {
        final w = DateTime(2026, m + 1, d).weekday % 7; // 0 = Sunday
        final weekday = w > 0 && w < 6;
        if (weekday && rng.next() < 0.72) {
          final ocr = rng.next() < 0.3;
          final note =
              'Menú ${pick(['trucha', 'ají de gallina', 'lomo saltado', 'pollo a la plancha', 'seco con frejoles', 'arroz chaufa'])}';
          final account = rng.next() < 0.6 ? 'BCP Soles' : 'Efectivo';
          final a = amt(12, 19);
          final method = rng.next() < 0.6 ? 'Yape' : null;
          final at = time(12, 15);
          final confidence = ocr ? (82 + rng.next() * 15).round() : null;
          add(
            m,
            d,
            'expense',
            'Comida',
            'Almuerzo',
            note,
            account,
            a,
            method: method,
            at: at,
            ocr: confidence,
          );
        }
        if (weekday && rng.next() < 0.45) {
          final note = pick(['Uber a oficina', 'Taxi Beat', 'InDrive a casa']);
          final a = amt(8, 22);
          add(
            m,
            d,
            'expense',
            'Transporte',
            'Taxi',
            note,
            'BCP Visa',
            a,
            at: time(7, 9),
          );
        }
        if (rng.next() < 0.22) {
          final note = pick(['Café Tostado', 'Starbucks latte', 'Juan Valdez']);
          final a = amt(9, 17);
          add(
            m,
            d,
            'expense',
            'Comida',
            'Café',
            note,
            'BCP Soles',
            a,
            method: 'Yape',
            at: time(9, 17),
          );
        }
        if (rng.next() < (sep ? 0.5 : 0.16)) {
          final note =
              'Rappi · ${pick(['pizza', 'sushi', 'hamburguesa', 'pollo a la brasa', 'chifa'])}';
          final a = amt(29, 58);
          add(
            m,
            d,
            'expense',
            'Comida',
            'Delivery',
            note,
            'BCP Visa',
            a,
            at: time(19, 22),
          );
        }
        if (w == 6) {
          final note = pick(['Plaza Vea', 'Tottus', 'Wong']);
          final a = amt(120, 230);
          final at = time(10, 13);
          final confidence = rng.next() < 0.5
              ? (88 + rng.next() * 10).round()
              : null;
          add(
            m,
            d,
            'expense',
            'Comida',
            'Supermercado',
            note,
            'BCP Visa',
            a,
            at: at,
            ocr: confidence,
          );
        }
        if ((w == 5 || w == 6) && rng.next() < 0.55) {
          final sub = pick(['Cine', 'Salidas', 'Bar']);
          final note = pick([
            'Cineplanet',
            'Salida con amigos',
            'Cervezas en Barranco',
            'Concierto',
          ]);
          final a = amt(30, 110);
          add(
            m,
            d,
            'expense',
            'Ocio',
            sub,
            note,
            'BCP Visa',
            a,
            at: time(19, 23),
          );
        }
        if (w == 0 && rng.next() < 0.5) {
          final a = amt(3, 6);
          add(
            m,
            d,
            'expense',
            'Transporte',
            'Movilidad',
            'Metropolitano',
            'Efectivo',
            a,
            at: time(10, 18),
          );
        }
        if (rng.next() < 0.04) {
          final a = amt(18, 60);
          add(
            m,
            d,
            'expense',
            'Salud',
            'Farmacia',
            'Inkafarma',
            'BCP Soles',
            a,
            method: 'Yape',
          );
        }
        if (rng.next() < 0.035) {
          final sub = pick(['Ropa', 'Hogar']);
          final note = pick(['Saga Falabella', 'Mercado Libre', 'Promart']);
          final a = amt(60, 180);
          add(m, d, 'expense', 'Compras', sub, note, 'BCP Visa', a);
        }
      }
    }
    return out;
  }
}

final class DemoTransaction {
  const DemoTransaction({
    required this.id,
    required this.month,
    required this.day,
    required this.hour,
    required this.minute,
    required this.type,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.account,
    required this.amount,
    this.method,
    this.toAccount,
    this.ocr,
  });

  final int id;

  /// 0-based, as in the prototype (8 = September).
  final int month;
  final int day;
  final int hour;
  final int minute;
  final String type;
  final String category;
  final String subcategory;
  final String note;
  final String account;
  final double amount;
  final String? method;
  final String? toAccount;
  final int? ocr;
}

/// mulberry32, identical to the prototype's generator (32-bit arithmetic).
final class _Mulberry32 {
  _Mulberry32(this._seed);

  int _seed;

  static int _i32(int x) => x.toSigned(32);
  static int _u32(int x) => x & 0xFFFFFFFF;
  static int _imul(int a, int b) => _i32(a * b);

  double next() {
    _seed = _i32(_i32(_seed) + 0x6D2B79F5);
    var t = _imul(_seed ^ (_u32(_seed) >> 15), 1 | _seed);
    t = _i32(t + _imul(t ^ (_u32(t) >> 7), 61 | t)) ^ t;
    return _u32(t ^ (_u32(t) >> 14)) / 4294967296;
  }
}
