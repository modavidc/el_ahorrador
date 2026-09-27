import 'package:flutter/material.dart';

import 'package:el_ahorrador/features/accounts/data/account_group_repository.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/accounts/presentation/legacy/app_styles.dart';

class AccountGroupSettingsScreen extends StatefulWidget {
  const AccountGroupSettingsScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<AccountGroupSettingsScreen> createState() =>
      _AccountGroupSettingsScreenState();
}

class _AccountGroupSettingsScreenState
    extends State<AccountGroupSettingsScreen> {
  late final AccountGroupRepository _repository = AccountGroupRepository(
    widget.db,
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Grupos de cuentas'),
      actions: [
        IconButton(
          tooltip: 'Nuevo grupo',
          icon: const Icon(Icons.add),
          onPressed: () => _showGroupDialog(),
        ),
      ],
    ),
    body: StreamBuilder<List<AccountGroup>>(
      stream: _repository.watchAll(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final groups = snapshot.data!;
        if (groups.isEmpty) {
          return const Center(child: Text('Todavía no hay grupos.'));
        }
        return ReorderableListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: groups.length,
          onReorder: (oldIndex, newIndex) {
            final ids = groups.map((g) => g.id).toList();
            if (newIndex > oldIndex) newIndex -= 1;
            final id = ids.removeAt(oldIndex);
            ids.insert(newIndex, id);
            _repository.reorder(ids);
          },
          itemBuilder: (context, index) {
            final group = groups[index];
            return ListTile(
              key: ValueKey(group.id),
              leading: Icon(
                group.type == accountGroupTypeLiability
                    ? Icons.credit_card
                    : Icons.account_balance_wallet_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                group.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                group.type == accountGroupTypeLiability
                    ? 'Tarjeta de crédito'
                    : 'Cuenta normal',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Editar',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed: () => _showGroupDialog(group: group),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.drag_handle,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );

  Future<void> _showGroupDialog({AccountGroup? group}) async {
    final controller = TextEditingController(text: group?.name);
    String type = group?.type ?? accountGroupTypeAsset;
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(group == null ? 'Nuevo grupo' : 'Editar grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cuenta normal'),
                value: accountGroupTypeAsset,
                groupValue: type,
                onChanged: (value) =>
                    setDialogState(() => type = value ?? accountGroupTypeAsset),
              ),
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarjeta de crédito'),
                value: accountGroupTypeLiability,
                groupValue: type,
                onChanged: (value) => setDialogState(
                  () => type = value ?? accountGroupTypeLiability,
                ),
              ),
            ],
          ),
          actions: [
            if (group != null)
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, 'delete'),
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                child: const Text('Borrar'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'save'),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == 'delete' && group != null) {
      await _run(() => _repository.delete(group.id));
      return;
    }
    if (result != 'save') return;
    await _run(() async {
      if (group == null) {
        await _repository.create(name: controller.text, type: type);
      } else {
        await _repository.rename(group.id, controller.text);
        await _repository.setType(group.id, type);
      }
    });
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    }
  }
}
