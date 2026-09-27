import 'package:el_ahorrador/features/accounts/domain/account_group.dart';

/// Port to change accounts (Cuentas). Balances are read through
/// `LedgerRepository.watchAccounts`, since they come from the movements.
abstract interface class AccountsRepository {
  /// Creates an account whose balance starts at [openingBalanceCents].
  Future<String> create({
    required String name,
    required AccountGroup group,
    int openingBalanceCents = 0,
  });

  /// Renames the account and makes its current balance [balanceCents]
  /// without touching its movements.
  Future<void> update(
    String id, {
    required String name,
    required int balanceCents,
  });

  /// Hidden accounts do not add to the totals.
  Future<void> setHidden(String id, bool hidden);

  /// Removes the account. One with movements is archived so its history
  /// stays; the main account cannot be removed.
  Future<void> delete(String id);
}
