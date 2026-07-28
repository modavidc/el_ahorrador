import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../data/app_database.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  late final AccountRepository _repository = AccountRepository(widget.db);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración · Cuentas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNameDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva cuenta'),
      ),
      body: StreamBuilder<List<Account>>(
        stream: _repository.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('No pudimos cargar las cuentas.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final active = snapshot.data!
              .where((item) => !item.isArchived)
              .toList();
          final archived = snapshot.data!
              .where((item) => item.isArchived)
              .toList();
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('Mantén presionado y arrastra para ordenar.'),
                ),
              ),
              SliverReorderableList(
                itemCount: active.length,
                onReorderItem: (oldIndex, newIndex) {
                  final reordered = [...active];
                  final item = reordered.removeAt(oldIndex);
                  reordered.insert(newIndex, item);
                  _repository.reorder(reordered.map((row) => row.id).toList());
                },
                itemBuilder: (context, index) {
                  final account = active[index];
                  return ReorderableDragStartListener(
                    key: ValueKey(account.id),
                    index: index,
                    child: _AccountTile(
                      account: account,
                      onEdit: () => _showNameDialog(account: account),
                      onDefault: account.isDefault
                          ? null
                          : () =>
                                _run(() => _repository.setDefault(account.id)),
                      onArchive: account.isDefault
                          ? null
                          : () => _run(
                              () => _repository.setArchived(account.id, true),
                            ),
                    ),
                  );
                },
              ),
              if (archived.isNotEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: Text(
                      'Archivadas',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              SliverList.builder(
                itemCount: archived.length,
                itemBuilder: (context, index) {
                  final account = archived[index];
                  return ListTile(
                    leading: const Icon(Icons.inventory_2_outlined),
                    title: Text(account.name),
                    trailing: TextButton(
                      onPressed: () => _run(
                        () => _repository.setArchived(account.id, false),
                      ),
                      child: const Text('Restaurar'),
                    ),
                  );
                },
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 96)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNameDialog({Account? account}) async {
    final controller = TextEditingController(text: account?.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(account == null ? 'Nueva cuenta' : 'Editar cuenta'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null) return;
    await _run(
      () => account == null
          ? _repository.create(name: name)
          : _repository.rename(account.id, name),
    );
  }

  Future<void> _run(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
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

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    this.onEdit,
    this.onDefault,
    this.onArchive,
  });

  final Account account;
  final VoidCallback? onEdit;
  final VoidCallback? onDefault;
  final VoidCallback? onArchive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.account_balance_wallet_outlined),
      title: Text(account.name),
      subtitle: account.isDefault ? const Text('Predeterminada') : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'edit') onEdit?.call();
          if (value == 'default') onDefault?.call();
          if (value == 'archive') onArchive?.call();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Editar')),
          if (!account.isDefault)
            const PopupMenuItem(
              value: 'default',
              child: Text('Hacer predeterminada'),
            ),
          if (!account.isDefault)
            const PopupMenuItem(value: 'archive', child: Text('Archivar')),
        ],
      ),
    );
  }
}
