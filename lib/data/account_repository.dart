import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

class AccountBalance {
  const AccountBalance({
    required this.accountId,
    required this.startingBalanceCents,
    required this.balanceCents,
    this.startingBalanceDate,
  });

  final String accountId;
  final int startingBalanceCents;
  final int balanceCents;
  final int? startingBalanceDate;
}

class AccountRepository {
  AccountRepository(this._db, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<Account>> watchActive() =>
      (_db.select(_db.accounts)
            ..where((row) => row.isArchived.equals(false))
            ..orderBy([(row) => OrderingTerm.asc(row.order)]))
          .watch();

  Stream<List<Account>> watchAll() =>
      (_db.select(_db.accounts)..orderBy([
            (row) => OrderingTerm.asc(row.isArchived),
            (row) => OrderingTerm.asc(row.order),
          ]))
          .watch();

  Future<AccountBalance> balance(String accountId) async {
    final rows = await _balanceQuery(accountId: accountId).get();
    if (rows.isEmpty) throw StateError('La cuenta no existe.');
    return _readBalance(rows.single);
  }

  Stream<AccountBalance> watchBalance(String accountId) =>
      _balanceQuery(accountId: accountId).watch().map((rows) {
        if (rows.isEmpty) throw StateError('La cuenta no existe.');
        return _readBalance(rows.single);
      });

  Future<List<AccountBalance>> balances() async => _balanceQuery().get().then(
    (rows) => rows.map<AccountBalance>(_readBalance).toList(),
  );

  Stream<List<AccountBalance>> watchBalances() => _balanceQuery().watch().map(
    (rows) => rows.map<AccountBalance>(_readBalance).toList(),
  );

  Future<void> setStartingBalance(
    String accountId, {
    required int startingBalanceCents,
    int? startingBalanceDate,
  }) async {
    final changed = await _db.customUpdate(
      'UPDATE accounts SET starting_balance_cents = ?, '
      'starting_balance_date = ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable.withInt(startingBalanceCents),
        startingBalanceDate == null
            ? const Variable<Object>(null)
            : Variable.withInt(startingBalanceDate),
        Variable.withInt(DateTime.now().millisecondsSinceEpoch),
        Variable.withString(accountId),
      ],
      updates: {_db.accounts},
    );
    if (changed == 0) throw StateError('La cuenta no existe.');
  }

  Selectable<QueryRow> _balanceQuery({String? accountId}) {
    final where = accountId == null ? '' : ' WHERE a.id = ?';
    return _db.customSelect(
      'SELECT a.id AS account_id, a.starting_balance_cents, '
      'a.starting_balance_date, COALESCE(SUM(e.amount_cents), 0) AS movement_cents '
      'FROM accounts a LEFT JOIN expenses e ON e.account_id = a.id '
      'AND (a.starting_balance_date IS NULL OR e.date >= a.starting_balance_date)'
      '$where '
      'GROUP BY a.id, a.starting_balance_cents, a.starting_balance_date '
      'ORDER BY a.is_archived ASC, a."order" ASC',
      variables: accountId == null
          ? const []
          : [Variable.withString(accountId)],
      readsFrom: {_db.accounts, _db.expenses},
    );
  }

  AccountBalance _readBalance(QueryRow row) {
    final starting = row.read<int>('starting_balance_cents') ?? 0;
    return AccountBalance(
      accountId: row.read<String>('account_id')!,
      startingBalanceCents: starting,
      balanceCents: starting + (row.read<int>('movement_cents') ?? 0),
      startingBalanceDate: row.readNullable<int>('starting_balance_date'),
    );
  }

  Future<Account> defaultAccount() async {
    final account = await (_db.select(
      _db.accounts,
    )..where((row) => row.isDefault.equals(true))).getSingleOrNull();
    if (account != null) return account;

    final first =
        await (_db.select(_db.accounts)
              ..where((row) => row.isArchived.equals(false))
              ..orderBy([(row) => OrderingTerm.asc(row.order)])
              ..limit(1))
            .getSingleOrNull();
    if (first == null) {
      throw StateError('Debe existir al menos una cuenta activa.');
    }
    await setDefault(first.id);
    return first.copyWith(isDefault: true);
  }

  Future<String> create({
    required String name,
    required String groupId,
    String currency = 'PEN',
    String? description,
    int? creditLimitCents,
  }) async {
    final cleanName = await _validateName(name);
    final maxOrder = _db.accounts.order.max();
    final result = await (_db.selectOnly(
      _db.accounts,
    )..addColumns([maxOrder])).getSingle();
    final nextOrder = (result.read(maxOrder) ?? -1) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.accounts)
        .insert(
          AccountsCompanion.insert(
            id: id,
            name: cleanName,
            currency: Value(currency),
            groupId: Value(groupId),
            order: nextOrder,
            createdAt: now,
            updatedAt: now,
            description: Value(description),
            creditLimitCents: Value(creditLimitCents),
          ),
        );
    return id;
  }

  Future<void> setGroup(String id, String groupId) async {
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
      AccountsCompanion(
        groupId: Value(groupId),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> rename(String id, String name) async {
    final cleanName = await _validateName(name, excludingId: id);
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
      AccountsCompanion(
        name: Value(cleanName),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setDefault(String id) async {
    await _db.transaction(() async {
      final target = await (_db.select(
        _db.accounts,
      )..where((row) => row.id.equals(id))).getSingle();
      await _db
          .update(_db.accounts)
          .write(const AccountsCompanion(isDefault: Value(false)));
      await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
        AccountsCompanion(
          isDefault: const Value(true),
          isArchived: const Value(false),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
      if (target.isArchived) await _normalizeOrder();
    });
  }

  Future<void> setArchived(String id, bool archived) async {
    final account = await (_db.select(
      _db.accounts,
    )..where((row) => row.id.equals(id))).getSingle();
    if (archived && account.isDefault) {
      throw StateError('La cuenta predeterminada no se puede archivar.');
    }
    await (_db.update(_db.accounts)..where((row) => row.id.equals(id))).write(
      AccountsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
    await _normalizeOrder();
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await (_db.update(_db.accounts)
              ..where((row) => row.id.equals(orderedIds[index])))
            .write(AccountsCompanion(order: Value(index)));
      }
    });
  }

  Future<String> _validateName(String name, {String? excludingId}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ArgumentError('El nombre de la cuenta es obligatorio.');
    }
    final duplicate =
        await (_db.select(_db.accounts)
              ..where((row) => row.name.lower().equals(clean.toLowerCase())))
            .getSingleOrNull();
    if (duplicate != null && duplicate.id != excludingId) {
      throw ArgumentError('Ya existe una cuenta con ese nombre.');
    }
    return clean;
  }

  Future<void> _normalizeOrder() async {
    final rows = await (_db.select(
      _db.accounts,
    )..orderBy([(row) => OrderingTerm.asc(row.order)])).get();
    await reorder(rows.map((row) => row.id).toList());
  }
}
