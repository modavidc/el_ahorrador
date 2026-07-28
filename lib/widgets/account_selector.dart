import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../data/app_database.dart';

class AccountSelector extends StatelessWidget {
  const AccountSelector({
    super.key,
    required this.db,
    required this.selectedId,
    required this.onSelected,
  });

  final AppDatabase db;
  final String? selectedId;
  final ValueChanged<Account> onSelected;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Account>>(
      stream: AccountRepository(db).watchActive(),
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? const <Account>[];
        if (accounts.isNotEmpty &&
            !accounts.any((account) => account.id == selectedId)) {
          final preferred = accounts.firstWhere(
            (account) => account.isDefault,
            orElse: () => accounts.first,
          );
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onSelected(preferred),
          );
        }
        return DropdownButtonFormField<String>(
          key: ValueKey(selectedId),
          initialValue: accounts.any((account) => account.id == selectedId)
              ? selectedId
              : null,
          decoration: const InputDecoration(labelText: 'Cuenta'),
          hint: const Text('Selecciona una cuenta'),
          items: accounts
              .map(
                (account) => DropdownMenuItem(
                  value: account.id,
                  child: Text(
                    account.isDefault
                        ? '${account.name} (predeterminada)'
                        : account.name,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) return;
            onSelected(accounts.firstWhere((account) => account.id == id));
          },
        );
      },
    );
  }
}
