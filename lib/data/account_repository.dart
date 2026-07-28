import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';

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

  Future<String> create({required String name, String currency = 'PEN'}) async {
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
            order: nextOrder,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
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
