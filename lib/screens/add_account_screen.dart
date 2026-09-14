import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/account_group_repository.dart';
import '../data/account_repository.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../theme/app_styles.dart';
import 'account_group_picker_screen.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final AccountRepository _repository = AccountRepository(widget.db);
  late final AccountGroupRepository _groupRepository = AccountGroupRepository(
    widget.db,
  );

  static const _currencies = [('PEN', 'S/.'), ('USD', '\$'), ('BOB', 'Bs.S')];

  String? _groupId;
  String? _groupName;
  String _currency = 'PEN';
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final symbol = _currencies.firstWhere((c) => c.$1 == _currency).$2;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Add Account'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _FormRow(
            label: 'Group',
            child: GestureDetector(
              onTap: _pickGroup,
              child: _underline(
                Text(
                  _groupName ?? '',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          _FormRow(
            label: 'Name',
            child: _underline(
              TextField(
                controller: _nameController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          _FormRow(
            label: 'Amount',
            child: _underline(
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  prefixText: '$symbol ',
                ),
              ),
            ),
          ),
          _FormRow(
            label: 'Currency',
            child: Wrap(
              spacing: 8,
              children: [
                for (final entry in _currencies)
                  _CurrencyChip(
                    label: entry.$2,
                    selected: _currency == entry.$1,
                    onTap: () => setState(() => _currency = entry.$1),
                  ),
                _CurrencyChip(
                  label: '+',
                  selected: false,
                  onTap: _showComingSoon,
                ),
              ],
            ),
          ),
          _FormRow(
            label: 'Description',
            child: _underline(
              TextField(
                controller: _descriptionController,
                style: const TextStyle(fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _underline(Widget child) => Container(
    padding: const EdgeInsets.only(bottom: 4),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: child,
  );

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(comingSoonSnackBar);
  }

  Future<void> _pickGroup() async {
    final groupId = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountGroupPickerScreen(db: widget.db),
      ),
    );
    if (groupId == null || !mounted) return;
    final groups = await _groupRepository.watchAll().first;
    final match = groups.where((g) => g.id == groupId).toList();
    if (match.isEmpty) return;
    setState(() {
      _groupId = match.first.id;
      _groupName = match.first.name;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (_groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un grupo para la cuenta.')),
      );
      return;
    }
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ponele un nombre a la cuenta.')),
      );
      return;
    }
    final amountValue =
        double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final amountCents = (amountValue * 100).round();

    var recordAsIncome = false;
    if (amountCents != 0 && mounted) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: const Text(
            'La diferencia se registra en el detalle de tu cuenta. '
            '¿Querés registrarla también como un ingreso?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('NO'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.accent),
              child: const Text('SÍ'),
            ),
          ],
        ),
      );
      recordAsIncome = choice ?? false;
    }

    setState(() => _saving = true);
    try {
      final id = await _repository.create(
        name: name,
        groupId: _groupId!,
        currency: _currency,
      );
      if (recordAsIncome) {
        // El monto ya queda reflejado por el movimiento en sí — si
        // también lo pusiéramos como saldo inicial, el balance quedaría
        // duplicado (saldo inicial + movimiento).
        final description = _descriptionController.text.trim();
        await widget.db.insertExpenseFromParser(
          id: const Uuid().v4(),
          dateEpochMs: DateTime.now().millisecondsSinceEpoch,
          amountCents: amountCents,
          currency: _currency,
          accountId: id,
          vendor: 'Saldo inicial',
          description: description.isEmpty ? null : description,
          sourceApp: 'Manual',
        );
      } else if (amountCents != 0) {
        await _repository.setStartingBalance(
          id,
          startingBalanceCents: amountCents,
        );
      }
      if (mounted) Navigator.pop(context);
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _FormRow extends StatelessWidget {
  const _FormRow({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textCaption,
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? AppColors.accent : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: selected ? AppColors.accent : AppColors.textPrimary,
        ),
      ),
    ),
  );
}
