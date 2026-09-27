import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/database/daos.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/data/drift_ledger_repository.dart';

/// The v3 prototype's data (`design/capture-core.js` → `SEED`), for visual
/// checks and demos: `--dart-define=DEMO_DATA=true`. The tester build starts
/// empty.
abstract final class DemoSeedV3 {
  /// The prototype's clock: Sunday 27 September 2026, 21:40.
  static final today = DateTime(2026, 9, 27, 21, 40);

  /// `[day, note, amount, category, account, income?, origin]`.
  static const rows = <(int, String, double, String, String, bool, String?)>[
    (1, 'Sueldo Setiembre', 3200, 'Sueldo', 'BCP', true, null),
    (1, 'Alquiler', 850, 'Casa', 'Yape', false, null),
    (2, 'Plaza Vea', 146.3, 'Mercado', 'BBVA Visa', false, null),
    (3, 'Menú', 14, 'Comida', 'Efectivo', false, null),
    (5, 'Luz del Sur', 92.4, 'Servicios', 'BCP', false, null),
    (6, 'Cine', 38, 'Ocio', 'Yape', false, 'shared'),
    (8, 'Metropolitano', 20, 'Transporte', 'BCP', false, null),
    (9, 'Tottus', 118.7, 'Mercado', 'BBVA Visa', false, 'screenshot'),
    (11, 'Farmacia', 46.5, 'Salud', 'Yape', false, 'shared'),
    (12, 'Cena con amigos', 72, 'Comida', 'Yape', false, 'shared'),
    (14, 'Zapatillas', 189.9, 'Compras', 'BBVA Visa', false, null),
    (15, 'Internet', 99, 'Servicios', 'BCP', false, null),
    (16, 'Taxi', 16.5, 'Transporte', 'Yape', false, 'screenshot'),
    (18, 'Plaza Vea', 132.1, 'Mercado', 'BBVA Visa', false, null),
    (19, 'Café', 11, 'Comida', 'Yape', false, 'shared'),
    (20, 'Netflix', 44.9, 'Ocio', 'BBVA Visa', false, null),
    (21, 'Menú', 15, 'Comida', 'Efectivo', false, null),
    (23, 'Uber', 21.4, 'Transporte', 'BBVA Visa', false, 'screenshot'),
    (24, 'Mercado Surquillo', 64, 'Mercado', 'Efectivo', false, null),
    (25, 'Pollo a la brasa', 58, 'Comida', 'Yape', false, 'shared'),
    (25, 'Te yapearon · Freelance', 450, 'Extra', 'Yape', true, 'shared'),
    (26, 'Bodega', 23.6, 'Mercado', 'Yape', false, 'shared'),
    (26, 'Tambo', 9.5, 'Comida', 'Yape', false, 'screenshot'),
    (27, 'Café', 9, 'Comida', 'Yape', false, 'shared'),
    (27, 'Menú', 16, 'Comida', 'Efectivo', false, null),
  ];

  /// Balances shown by the prototype's Cuentas screen.
  static const balances = {
    'Efectivo': 145.0,
    'BCP': 2310.75,
    'Yape': 482.4,
    'BBVA Visa': -612.3,
  };

  static Future<void> load(AppDatabase db) async {
    final repository = DriftLedgerRepository(db);
    await db.transaction(() async {
      final ids = await _accounts(db);
      for (final (i, r) in rows.indexed) {
        final (day, note, amount, category, account, income, origin) = r;
        // Later rows of a day are newer, so the list shows them first.
        final at = DateTime(2026, 9, day, 8, 0).add(Duration(minutes: 10 * i));
        final id = await repository.addEntry(
          type: income ? MovementType.income : MovementType.expense,
          amountCents: (amount * 100).round(),
          account: account,
          category: category,
          note: note,
          at: at,
          sourceApp: origin == null ? 'Manual' : 'Yape',
        );
        if (origin != null) {
          final captureId = 'demo_capture_$i';
          await db.insertCapture(
            id: captureId,
            imagePath: '',
            hash: captureId,
            sourceApp: 'Yape',
          );
          await (db.update(
            db.captures,
          )..where((c) => c.id.equals(captureId))).write(
            CapturesCompanion(metaJson: Value(jsonEncode({'origin': origin}))),
          );
          await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(
            ExpensesCompanion(captureId: Value(captureId)),
          );
        }
      }
      // Starting balances so each account ends where the prototype shows it.
      final accountRepository = AccountRepository(db);
      for (final MapEntry(key: name, value: balance) in balances.entries) {
        var moved = 0.0;
        for (final r in rows.where((r) => r.$5 == name)) {
          moved += r.$6 ? r.$3 : -r.$3;
        }
        await accountRepository.setStartingBalance(
          ids[name]!,
          startingBalanceCents: ((balance - moved) * 100).round(),
        );
      }
    });
  }

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
    await group('demo_group_bank', 'Bancos', 'asset', 1);
    await group('demo_group_wallet', 'Billeteras', 'asset', 2);
    await group('demo_group_card', 'Tarjetas', 'liability', 3);

    final repository = AccountRepository(db);
    final ids = <String, String>{'Efectivo': AppDatabase.defaultAccountId};
    for (final (name, groupId) in [
      ('BCP', 'demo_group_bank'),
      ('Yape', 'demo_group_wallet'),
      ('BBVA Visa', 'demo_group_card'),
    ]) {
      ids[name] = await repository.create(name: name, groupId: groupId);
    }
    return ids;
  }
}
