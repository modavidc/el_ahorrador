import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/database/daos.dart';
import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';

/// [LedgerRepository] on the drift database.
class DriftLedgerRepository implements LedgerRepository {
  DriftLedgerRepository(this._db);

  final AppDatabase _db;

  static const _paymentApps = {'yape': 'Yape', 'plin': 'Plin'};

  /// `app_settings` key of the monthly budget (onboarding step 2 and
  /// Presupuestos).
  static const monthlyBudgetKey = 'monthly_budget_cents';

  @override
  Stream<int> watchMonthlyBudget() =>
      (_db.select(
        _db.appSettings,
      )..where((s) => s.key.equals(monthlyBudgetKey))).watchSingleOrNull().map(
        (row) =>
            int.tryParse(row?.value ?? '') ??
            LedgerRepository.defaultMonthlyBudgetCents,
      );

  @override
  Future<void> setMonthlyBudget(int cents) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: monthlyBudgetKey, value: '$cents'),
      );

  static const categoryLettersKey = 'category_letters';

  @override
  Stream<CategoryLetters> watchCategoryLetters() =>
      (_db.select(_db.appSettings)
            ..where((s) => s.key.equals(categoryLettersKey)))
          .watchSingleOrNull()
          .map((row) => CategoryLetters.decode(row?.value));

  @override
  Future<void> setCategoryLetters(CategoryLetters letters) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: categoryLettersKey,
          value: letters.encode(),
        ),
      );

  @override
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

  @override
  Stream<List<LedgerAccount>> watchAccounts() {
    return _db
        .customSelect(
          'SELECT a.id, a.name, a.group_id, a."order" AS ord, '
          'a.description, a.credit_limit_cents, a.is_default, a.is_hidden, '
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
                isDefault: row.read<bool>('is_default'),
                isHidden: row.read<bool>('is_hidden'),
              ),
          ],
        );
  }

  /// Monthly cap in cents per category name.
  @override
  Stream<Map<String, int>> watchBudgets() => _db
      .select(_db.budgets)
      .watch()
      .map((rows) => {for (final b in rows) b.category: b.monthlyCapCents});

  @override
  Future<void> setBudget(String category, int monthlyCapCents) => _db
      .into(_db.budgets)
      .insertOnConflictUpdate(
        BudgetsCompanion.insert(
          category: category,
          monthlyCapCents: monthlyCapCents,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

  @override
  Future<void> clearBudget(String category) =>
      (_db.delete(_db.budgets)..where((b) => b.category.equals(category))).go();

  /// Registers a movement from the manual entry sheet (or voice) and
  /// returns its id. Categories are matched by name and created when the
  /// database does not have them yet (older installs use another taxonomy).
  @override
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
    PaymentDetails details = const PaymentDetails(),
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
        vendor: details.counterpart,
        description: text,
        sourceApp: sourceApp,
        message: details.message,
        counterpartPhone: details.counterpartPhone,
        operation: details.operation,
      );
    });
    return id;
  }

  @override
  Future<Restore> delete(Movement m) async {
    final db = _db;
    final where = m.type == MovementType.transfer
        ? (($ExpensesTable e) => e.origination.equals(m.id))
        : (($ExpensesTable e) => e.id.equals(m.id));
    final rows = await db.transaction(() async {
      final rows = await (db.select(db.expenses)..where(where)).get();
      await (db.delete(db.expenses)..where(where)).go();
      return rows;
    });
    return () => db.batch(
      (b) => b.insertAll(db.expenses, rows, mode: InsertMode.insertOrReplace),
    );
  }

  /// Removes a registered income or expense by id ("Deshacer" of a
  /// capture).
  @override
  Future<void> deleteById(String id) =>
      (_db.delete(_db.expenses)..where((e) => e.id.equals(id))).go();

  /// Changes the category of an income or expense (detail sheet chips).
  @override
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
  @override
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
      details: PaymentDetails(
        counterpart: isManual ? null : _nonEmpty(e.vendor),
        counterpartPhone: e.counterpartPhone,
        message: e.message,
        operation: e.operation,
      ),
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
