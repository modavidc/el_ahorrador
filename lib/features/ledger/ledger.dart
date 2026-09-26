import 'package:drift/drift.dart';

import '../../data/app_database.dart';

enum MovementType { income, expense, transfer }

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

  Movement _fromRow(_Row r) {
    final e = r.expense;
    final type = e.amountCents >= 0
        ? MovementType.income
        : MovementType.expense;
    // Manual entries store the chosen category name in `vendor`; captures
    // store the merchant there and resolve the category through its id.
    final isManual = (e.sourceApp ?? '').toLowerCase() == 'manual';
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
  });

  final Expense expense;
  final String? category;
  final String? subcategory;
  final String? accountName;
  final String? ocrConfidence;
}
