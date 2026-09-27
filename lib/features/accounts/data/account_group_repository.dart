import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:el_ahorrador/core/database/app_database.dart';

/// 'asset' suma a Assets en la pantalla de Cuentas, 'liability' suma a
/// Liabilities. Cualquier otro valor guardado en la fila se trata como
/// 'asset' (ver AccountGroupRow.type en la UI).
const accountGroupTypeAsset = 'asset';
const accountGroupTypeLiability = 'liability';

class AccountGroupRepository {
  AccountGroupRepository(this._db, {Uuid uuid = const Uuid()}) : _uuid = uuid;

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<AccountGroupRow>> watchAll() => (_db.select(
    _db.accountGroups,
  )..orderBy([(row) => OrderingTerm.asc(row.order)])).watch();

  Future<String> create({
    required String name,
    String type = accountGroupTypeAsset,
  }) async {
    final cleanName = await _validateName(name);
    final maxOrder = _db.accountGroups.order.max();
    final result = await (_db.selectOnly(
      _db.accountGroups,
    )..addColumns([maxOrder])).getSingle();
    final nextOrder = (result.read(maxOrder) ?? -1) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db
        .into(_db.accountGroups)
        .insert(
          AccountGroupsCompanion.insert(
            id: id,
            name: cleanName,
            type: Value(type),
            order: nextOrder,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> rename(String id, String name) async {
    final cleanName = await _validateName(name, excludingId: id);
    await (_db.update(
      _db.accountGroups,
    )..where((row) => row.id.equals(id))).write(
      AccountGroupsCompanion(
        name: Value(cleanName),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> setType(String id, String type) async {
    await (_db.update(
      _db.accountGroups,
    )..where((row) => row.id.equals(id))).write(
      AccountGroupsCompanion(
        type: Value(type),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (var index = 0; index < orderedIds.length; index++) {
        await (_db.update(_db.accountGroups)
              ..where((row) => row.id.equals(orderedIds[index])))
            .write(AccountGroupsCompanion(order: Value(index)));
      }
    });
  }

  /// Lanza si el grupo todavía tiene cuentas asignadas: el usuario debe
  /// reasignarlas primero para no dejar cuentas huérfanas.
  Future<void> delete(String id) async {
    if (id == AppDatabase.defaultAccountGroupId) {
      throw StateError('No se puede borrar el grupo por defecto.');
    }
    final hasAccounts = await (_db.select(
      _db.accounts,
    )..where((row) => row.groupId.equals(id))).get();
    if (hasAccounts.isNotEmpty) {
      throw StateError(
        'Este grupo todavía tiene cuentas. Reasignalas antes de borrarlo.',
      );
    }
    await (_db.delete(
      _db.accountGroups,
    )..where((row) => row.id.equals(id))).go();
  }

  Future<String> _validateName(String name, {String? excludingId}) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw ArgumentError('El nombre del grupo es obligatorio.');
    }
    final duplicate =
        await (_db.select(_db.accountGroups)
              ..where((row) => row.name.lower().equals(clean.toLowerCase())))
            .getSingleOrNull();
    if (duplicate != null && duplicate.id != excludingId) {
      throw ArgumentError('Ya existe un grupo con ese nombre.');
    }
    return clean;
  }
}
