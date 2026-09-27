import 'package:drift/drift.dart';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/accounts/data/account_group_repository.dart';
import 'package:el_ahorrador/features/accounts/data/account_repository.dart';
import 'package:el_ahorrador/features/accounts/domain/account_group.dart';
import 'package:el_ahorrador/features/accounts/domain/accounts_repository.dart';

/// [AccountsRepository] on the accounts and account_groups tables.
class DriftAccountsRepository implements AccountsRepository {
  DriftAccountsRepository(this._db)
    : _accounts = AccountRepository(_db),
      _groups = AccountGroupRepository(_db);

  final AppDatabase _db;
  final AccountRepository _accounts;
  final AccountGroupRepository _groups;

  @override
  Future<String> create({
    required String name,
    required AccountGroup group,
    int openingBalanceCents = 0,
  }) => _db.transaction(() async {
    final id = await _accounts.create(
      name: name,
      groupId: await _groupId(group),
    );
    if (openingBalanceCents != 0) {
      await _accounts.setStartingBalance(
        id,
        startingBalanceCents: openingBalanceCents,
      );
    }
    return id;
  });

  @override
  Future<void> update(
    String id, {
    required String name,
    required int balanceCents,
  }) => _db.transaction(() async {
    await _accounts.rename(id, name);
    final current = await _accounts.balance(id);
    final moved = current.balanceCents - current.startingBalanceCents;
    await _accounts.setStartingBalance(
      id,
      startingBalanceCents: balanceCents - moved,
      startingBalanceDate: current.startingBalanceDate,
    );
  });

  @override
  Future<void> setHidden(String id, bool hidden) =>
      (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
        AccountsCompanion(
          isHidden: Value(hidden),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );

  @override
  Future<void> delete(String id) async {
    final used = await (_db.select(
      _db.expenses,
    )..where((e) => e.accountId.equals(id))).get();
    if (used.isNotEmpty) return _accounts.setArchived(id, true);
    final account = await (_db.select(
      _db.accounts,
    )..where((a) => a.id.equals(id))).getSingle();
    if (account.isDefault) {
      throw StateError('La cuenta principal no se puede eliminar.');
    }
    await (_db.delete(_db.accounts)..where((a) => a.id.equals(id))).go();
  }

  /// The group row for a v3 group, created on first use.
  Future<String> _groupId(AccountGroup group) async {
    final existing = await (_db.select(
      _db.accountGroups,
    )..where((g) => g.name.equals(group.label))).getSingleOrNull();
    if (existing != null) return existing.id;
    if (group == AccountGroup.efectivo) {
      final cash =
          await (_db.select(_db.accountGroups)
                ..where((g) => g.id.equals(AppDatabase.defaultAccountGroupId)))
              .getSingleOrNull();
      if (cash != null) return cash.id;
    }
    return _groups.create(
      name: group.label,
      type: group.isLiability ? 'liability' : 'asset',
    );
  }
}
