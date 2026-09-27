import 'package:flutter/material.dart';

import 'package:el_ahorrador/features/accounts/data/account_group_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/app_styles.dart';

/// Pantalla "Account Group" de la referencia: lista los grupos reales
/// del usuario (no la taxonomía fija de Money Manager) y al tocar uno
/// devuelve su id con Navigator.pop.
class AccountGroupPickerScreen extends StatelessWidget {
  const AccountGroupPickerScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final repository = AccountGroupRepository(db);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Account Group'),
      ),
      body: StreamBuilder<List<AccountGroup>>(
        stream: repository.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snapshot.data!;
          if (groups.isEmpty) {
            return const Center(
              child: Text(
                'Todavía no hay grupos de cuentas.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.separated(
            itemCount: groups.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(
                  group.name,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () => Navigator.pop(context, group.id),
              );
            },
          );
        },
      ),
    );
  }
}
