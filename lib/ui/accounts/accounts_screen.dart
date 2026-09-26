import 'package:flutter/material.dart';

import '../../features/ledger/ledger.dart';
import '../../theme/design_tokens.dart';
import '../format.dart';
import '../ledger_scope.dart';
import '../widgets.dart';

/// Cuentas of the v1 prototype: Activos / Pasivos / Total and one card per
/// account group, with balances computed from the starting balance plus
/// every movement (transfers move money between accounts).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key, this.onEdit, this.onAdd});

  final VoidCallback? onEdit;
  final VoidCallback? onAdd;

  static IconData groupIcon(String name, bool liability) {
    final n = name.toLowerCase();
    if (liability || n.contains('tarjeta') || n.contains('crédito')) {
      return DesignIcons.creditCard;
    }
    if (n.contains('efectivo')) return DesignIcons.payments;
    if (n.contains('ahorro')) return DesignIcons.savings;
    if (n.contains('banc')) return DesignIcons.accountBalance;
    return DesignIcons.accountBalanceWallet;
  }

  @override
  Widget build(BuildContext context) {
    final accounts = LedgerScope.of(context).accounts;
    final groups = <String, List<LedgerAccount>>{};
    for (final a in accounts) {
      groups.putIfAbsent(a.groupId ?? '', () => []).add(a);
    }
    var assets = 0;
    var liabilities = 0;
    for (final list in groups.values) {
      final total = list.fold(0, (t, a) => t + a.balanceCents);
      if (list.first.isLiability) {
        liabilities += total < 0 ? -total : 0;
      } else {
        assets += total;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: DesignColors.surfaceCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Cuentas', style: DesignText.title)),
                    GestureDetector(
                      onTap: onEdit,
                      child: const Sym(
                        DesignIcons.edit,
                        size: 22,
                        color: DesignColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: DesignSpacing.lg),
                    GestureDetector(
                      onTap: onAdd,
                      child: const Sym(DesignIcons.add, size: 24),
                    ),
                  ],
                ),
              ),
              SummaryBar(
                items: [
                  ('Activos', Fmt.money(assets / 100), DesignColors.income),
                  (
                    'Pasivos',
                    Fmt.money(liabilities / 100),
                    DesignColors.expense,
                  ),
                  (
                    'Total',
                    Fmt.signedMoney((assets - liabilities) / 100),
                    DesignColors.textPrimary,
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final (i, list) in groups.values.indexed) ...[
                if (i > 0) const SizedBox(height: DesignSpacing.md),
                _GroupCard(accounts: list),
              ],
              const SizedBox(height: 84),
            ],
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.accounts});

  final List<LedgerAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final first = accounts.first;
    final liability = first.isLiability;
    final total = accounts.fold(0, (t, a) => t + a.balanceCents) / 100;
    final shown = liability ? (total < 0 ? -total : 0.0) : total;
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: DesignColors.inputFill,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                Sym(
                  AccountsScreen.groupIcon(first.groupName, liability),
                  size: 18,
                  color: DesignColors.textTertiary,
                ),
                const SizedBox(width: DesignSpacing.sm),
                Expanded(
                  child: Text(
                    first.groupName,
                    style: DesignText.labelMedium.copyWith(
                      color: DesignColors.textTertiary,
                    ),
                  ),
                ),
                Text(
                  liability ? Fmt.money(shown) : Fmt.signedMoney(shown),
                  style: DesignText.labelStrong.copyWith(
                    color: liability || total < 0
                        ? DesignColors.expense
                        : DesignColors.income,
                  ),
                ),
              ],
            ),
          ),
          for (final account in accounts) _AccountRow(account: account),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.account});

  final LedgerAccount account;

  @override
  Widget build(BuildContext context) {
    final balance = account.balanceCents / 100;
    final liability = account.isLiability;
    final limit = account.creditLimitCents;
    final subtitle = liability
        ? [
            'Por pagar',
            if (limit != null) 'línea ${Fmt.money(limit / 100)}',
          ].join(' · ')
        : account.description;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DesignColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(account.name, style: DesignText.body),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: DesignText.caption.copyWith(
                      color: DesignColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            liability
                ? Fmt.money(balance < 0 ? -balance : 0)
                : Fmt.signedMoney(balance),
            style: DesignText.bodyMedium.copyWith(
              color: liability || balance < 0
                  ? DesignColors.expense
                  : DesignColors.income,
            ),
          ),
        ],
      ),
    );
  }
}
