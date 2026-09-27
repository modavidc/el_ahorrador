import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../data/app_database.dart';
import '../../data/daos.dart';

enum MovementType { income, expense, transfer }

/// How a movement entered the app; every origin but [manual] shows its label
/// next to the row ("Compartido", "Captura", "Boleta", "Voz").
enum MovementOrigin {
  manual(null),
  shared('Compartido'),
  screenshot('Captura'),
  receipt('Boleta'),
  voice('Voz');

  const MovementOrigin(this.label);

  final String? label;

  /// Value stored in `captures.meta_json` → `origin`.
  String get key => name;

  static MovementOrigin fromKey(String? key) =>
      values.where((o) => o.key == key).firstOrNull ?? shared;
}

/// One row of the ledger as the v1 screens show it: a transaction of the
/// prototype's data model
/// `{date, type, category, subcategory, note, account, toAccount?, amount,
/// time, method?, ocrConfidence?}`.
final class Movement {
  const Movement({
    required this.id,
    required this.at,
    required this.type,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.account,
    required this.amountCents,
    this.toAccount,
    this.method,
    this.ocrPercent,
    this.origin = MovementOrigin.manual,
  });

  final String id;
  final DateTime at;
  final MovementType type;
  final String category;
  final String subcategory;
  final String note;
  final String account;
  final String? toAccount;

  /// Always positive; [type] carries the direction.
  final int amountCents;

  /// Payment app shown as a chip ("Yape").
  final String? method;

  /// OCR confidence of the capture that created the movement.
  final int? ocrPercent;

  final MovementOrigin origin;

  double get amount => amountCents / 100;

  DateTime get day => DateTime(at.year, at.month, at.day);
}

/// Account with its group and computed balance (starting balance plus every
/// movement, transfers included).
final class LedgerAccount {
  const LedgerAccount({
    required this.id,
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.isLiability,
    required this.balanceCents,
    required this.order,
    this.description,
    this.creditLimitCents,
  });

  final String id;
  final String name;
  final String? groupId;
  final String groupName;
  final bool isLiability;
  final int balanceCents;
  final int order;
  final String? description;
  final int? creditLimitCents;
}

/// Reads the database in the shape the v1 screens need.
class LedgerRepository {
  LedgerRepository(this._db);

  final AppDatabase _db;

  static const _paymentApps = {'yape': 'Yape', 'plin': 'Plin'};

  /// `app_settings` key of the monthly budget (onboarding step 2 and
  /// Presupuestos).
  static const monthlyBudgetKey = 'monthly_budget_cents';

  /// Budget used until the user sets one (the prototype's S/ 2,400).
  static const defaultMonthlyBudgetCents = 240000;

  Stream<int> watchMonthlyBudget() =>
      (_db.select(
        _db.appSettings,
      )..where((s) => s.key.equals(monthlyBudgetKey))).watchSingleOrNull().map(
        (row) => int.tryParse(row?.value ?? '') ?? defaultMonthlyBudgetCents,
      );

  Future<void> setMonthlyBudget(int cents) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: monthlyBudgetKey, value: '$cents'),
      );

  Stream<List<Movement>> watchMovements() {
    final db = _db;
    final query = db.select(db.expenses).join([
      leftOuterJoin(
        db.categories,
        db.categories.id.equalsExp(db.expenses.categoryId),
      ),
      leftOuterJoin(
        db.subcategories,
        db.subcategories.id.equalsExp(db.expenses.subcategoryId),
      ),
      leftOuterJoin(
        db.accounts,
        db.accounts.id.equalsExp(db.expenses.accountId),
      ),
      leftOuterJoin(
        db.captures,
        db.captures.id.equalsExp(db.expenses.captureId),
      ),
    ])..orderBy([OrderingTerm.desc(db.expenses.date)]);

    return query.watch().map((rows) {
      final movements = <Movement>[];
      final transferHalves = <String, List<_Row>>{};
      for (final row in rows) {
        final r = _Row(
          expense: row.readTable(db.expenses),
          category: row.readTableOrNull(db.categories)?.name,
          subcategory: row.readTableOrNull(db.subcategories)?.name,
          accountName: row.readTableOrNull(db.accounts)?.name,
          ocrConfidence: row.readTableOrNull(db.captures)?.ocrConfidence,
          captureMeta: row.readTableOrNull(db.captures)?.metaJson,
        );
        final transferId = r.expense.origination;
        if (transferId != null && r.expense.vendor == 'Transferencia') {
          transferHalves.putIfAbsent(transferId, () => []).add(r);
        } else {
          movements.add(_fromRow(r));
        }
      }
      for (final entry in transferHalves.entries) {
        movements.add(_fromTransfer(entry.key, entry.value));
      }
      movements.sort((a, b) => b.at.compareTo(a.at));
      return movements;
    });
  }

  Stream<List<LedgerAccount>> watchAccounts() {
    return _db
        .customSelect(
          'SELECT a.id, a.name, a.group_id, a."order" AS ord, '
          'a.description, a.credit_limit_cents, '
          'g.name AS group_name, g.type AS group_type, '
          'a.starting_balance_cents + COALESCE(SUM(e.amount_cents), 0) '
          'AS balance_cents '
          'FROM accounts a '
          'LEFT JOIN account_groups g ON g.id = a.group_id '
          'LEFT JOIN expenses e ON e.account_id = a.id AND '
          '(a.starting_balance_date IS NULL OR e.date >= a.starting_balance_date) '
          'WHERE a.is_archived = 0 '
          'GROUP BY a.id ORDER BY g."order" ASC, a."order" ASC',
          readsFrom: {_db.accounts, _db.accountGroups, _db.expenses},
        )
        .watch()
        .map(
          (rows) => [
            for (final row in rows)
              LedgerAccount(
                id: row.read<String>('id'),
                name: row.read<String>('name'),
                groupId: row.readNullable<String>('group_id'),
                groupName: row.readNullable<String>('group_name') ?? 'Cuentas',
                isLiability:
                    row.readNullable<String>('group_type') == 'liability',
                balanceCents: row.read<int>('balance_cents'),
                order: row.read<int>('ord'),
                description: row.readNullable<String>('description'),
                creditLimitCents: row.readNullable<int>('credit_limit_cents'),
              ),
          ],
        );
  }

  /// Monthly cap in cents per category name.
  Stream<Map<String, int>> watchBudgets() => _db
      .select(_db.budgets)
      .watch()
      .map((rows) => {for (final b in rows) b.category: b.monthlyCapCents});

  Future<void> setBudget(String category, int monthlyCapCents) => _db
      .into(_db.budgets)
      .insertOnConflictUpdate(
        BudgetsCompanion.insert(
          category: category,
          monthlyCapCents: monthlyCapCents,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  Future<void> clearBudget(String category) =>
      (_db.delete(_db.budgets)..where((b) => b.category.equals(category))).go();

  /// Registers a movement from the manual entry sheet (or voice) and
  /// returns its id. Categories are matched by name and created when the
  /// database does not have them yet (older installs use another taxonomy).
  Future<String> addEntry({
    required MovementType type,
    required int amountCents,
    required String account,
    String? category,
    String? toAccount,
    String? note,
    DateTime? at,
    String sourceApp = 'Manual',
    String? captureId,
  }) async {
    final db = _db;
    final id = const Uuid().v4();
    final when = (at ?? DateTime.now()).millisecondsSinceEpoch;
    final text = _nonEmpty(note);
    await db.transaction(() async {
      final from = await _accountId(account);
      if (type == MovementType.transfer) {
        final to = await _accountId(toAccount);
        if (from == null || to == null) {
          throw ArgumentError('Elige dos cuentas distintas.');
        }
        await db.insertTransfer(
          id: id,
          dateEpochMs: when,
          amountCents: amountCents,
          currency: 'PEN',
          sourceAccountId: from,
          destinationAccountId: to,
          sourceAccount: account,
          destinationAccount: toAccount,
          description: text,
        );
        return;
      }
      await db.insertExpenseFromParser(
        id: id,
        captureId: captureId,
        dateEpochMs: when,
        amountCents: type == MovementType.income ? amountCents : -amountCents,
        currency: 'PEN',
        categoryId: category == null ? null : await _categoryId(category),
        accountId: from,
        account: account,
        description: text,
        sourceApp: sourceApp,
      );
    });
    return id;
  }

  /// Deletes a movement (both halves of a transfer) and returns the rows so
  /// "Deshacer" can put them back with [restore].
  Future<List<Expense>> delete(Movement m) async {
    final db = _db;
    final where = m.type == MovementType.transfer
        ? (($ExpensesTable e) => e.origination.equals(m.id))
        : (($ExpensesTable e) => e.id.equals(m.id));
    return db.transaction(() async {
      final rows = await (db.select(db.expenses)..where(where)).get();
      await (db.delete(db.expenses)..where(where)).go();
      return rows;
    });
  }

  /// Removes a registered income or expense by id ("Deshacer" of a
  /// capture).
  Future<void> deleteById(String id) =>
      (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();

  Future<void> restore(List<Expense> rows) => _db.batch(
    (b) => b.insertAll(_db.expenses, rows, mode: InsertMode.insertOrReplace),
  );

  /// Changes the category of an income or expense (detail sheet chips).
  Future<void> setCategory(Movement m, String category) async {
    final id = await _categoryId(category);
    await (_db.update(_db.expenses)..where((e) => e.id.equals(m.id))).write(
      ExpensesCompanion(
        categoryId: Value(id),
        subcategoryId: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  /// Registers the same movement again today ("Repetir").
  Future<String> repeat(Movement m) => addEntry(
    type: m.type,
    amountCents: m.amountCents,
    account: m.account,
    category: m.type == MovementType.transfer ? null : m.category,
    toAccount: m.toAccount,
    note: m.note,
  );

  Future<String?> _accountId(String? name) async {
    if (name == null) return null;
    final row = await (_db.select(
      _db.accounts,
    )..where((a) => a.name.equals(name))).getSingleOrNull();
    return row?.id;
  }

  Future<String> _categoryId(String name) async {
    final db = _db;
    final existing = await (db.select(
      db.categories,
    )..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) return existing.id;
    final count = await db.categories.count().getSingle();
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = const Uuid().v4();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            icon: '',
            color: '',
            order: count,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Movement _fromRow(_Row r) {
    final e = r.expense;
    final type = e.amountCents >= 0
        ? MovementType.income
        : MovementType.expense;
    // Manual entries store the chosen category name in `vendor`; captures
    // store the merchant there and resolve the category through its id.
    final isManual = (e.sourceApp ?? '').toLowerCase() == 'manual';
    final isVoice = (e.sourceApp ?? '').toLowerCase() == 'voz';
    final category =
        r.category ?? (isManual ? _nonEmpty(e.vendor) : null) ?? 'Otros';
    final note =
        _nonEmpty(e.description) ??
        (isManual ? null : _nonEmpty(e.vendor)) ??
        category;
    return Movement(
      id: e.id,
      at: DateTime.fromMillisecondsSinceEpoch(e.date),
      type: type,
      category: category,
      subcategory: r.subcategory ?? '',
      note: note,
      account: r.accountName ?? _nonEmpty(e.account) ?? 'Efectivo',
      amountCents: e.amountCents.abs(),
      method: _paymentApps[(e.sourceApp ?? '').toLowerCase()],
      ocrPercent: e.captureId == null
          ? null
          : int.tryParse(r.ocrConfidence ?? ''),
      origin: e.captureId == null
          ? (isVoice ? MovementOrigin.voice : MovementOrigin.manual)
          : MovementOrigin.fromKey(_metaOrigin(r.captureMeta)),
    );
  }

  Movement _fromTransfer(String id, List<_Row> halves) {
    final out =
        halves.where((h) => h.expense.amountCents < 0).firstOrNull ??
        halves.first;
    final into = halves.where((h) => h.expense.amountCents > 0).firstOrNull;
    final from = out.accountName ?? _nonEmpty(out.expense.source) ?? '';
    final to = into?.accountName ?? _nonEmpty(out.expense.destination) ?? '';
    return Movement(
      id: id,
      at: DateTime.fromMillisecondsSinceEpoch(out.expense.date),
      type: MovementType.transfer,
      category: 'Transferencia',
      subcategory: out.subcategory ?? '',
      note: _nonEmpty(out.expense.description) ?? '$from → $to',
      account: from,
      toAccount: to,
      amountCents: out.expense.amountCents.abs(),
    );
  }

  static String? _metaOrigin(String? metaJson) {
    if (metaJson == null) return null;
    try {
      final meta = jsonDecode(metaJson);
      return meta is Map ? meta['origin'] as String? : null;
    } on FormatException {
      return null;
    }
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

final class _Row {
  const _Row({
    required this.expense,
    required this.category,
    required this.subcategory,
    required this.accountName,
    required this.ocrConfidence,
    this.captureMeta,
  });

  final Expense expense;
  final String? category;
  final String? subcategory;
  final String? accountName;
  final String? ocrConfidence;
  final String? captureMeta;
}
