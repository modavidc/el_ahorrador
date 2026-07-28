import 'package:flutter/material.dart';
import '../core/parser.dart';
import '../models/transaction.dart';
import '../widgets/expense_edit_dialog.dart';
import 'package:intl/intl.dart';

class TransactionDetailScreen extends StatefulWidget {
  final Transaction transaction;
  final Future<Transaction> Function(ParsedExpense expense) onEdit;
  final Future<int> Function() onDelete;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Transaction transaction = widget.transaction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalle de Operación',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            tooltip: 'Editar transacción',
            onPressed: _editTransaction,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Eliminar transacción',
            onPressed: _deleteTransaction,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildGridLayout(),
        ),
      ),
    );
  }

  Future<void> _editTransaction() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ExpenseEditDialog(
        expense: ParsedExpense(
          amountCents: (transaction.amount * 100).round(),
          currency: transaction.currency,
          dateEpochMs: transaction.date.millisecondsSinceEpoch,
          category: transaction.category,
          subcategory: transaction.subcategory.isEmpty
              ? null
              : transaction.subcategory,
          account: transaction.account,
          vendor: transaction.vendor,
          description: transaction.description,
          notes: transaction.notes,
          sourceApp: 'Manual',
        ),
        onSave: (updated) async {
          final saved = await widget.onEdit(updated);
          if (mounted) setState(() => transaction = saved);
        },
      ),
    );
  }

  Future<void> _deleteTransaction() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar transacción'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final deleted = await widget.onDelete();
    if (mounted && deleted == 1) Navigator.pop(context);
  }

  Widget _buildGridLayout() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Primera fila: EMOJI, CATEGORIA, Categoría, Description, Amount with Currency
            Row(
              children: [
                // EMOJI
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'EMOJI',
                    value: transaction.icon.toString(),
                    isEmoji: true,
                  ),
                ),
                const SizedBox(width: 16),
                // CATEGORIA
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'CATEGORIA',
                    value: transaction.categoryDisplayName,
                  ),
                ),
                const SizedBox(width: 16),
                // Categoría
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Categoría',
                    value: transaction.categoryDisplayName,
                  ),
                ),
                const SizedBox(width: 16),
                // Description
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Description',
                    value: transaction.description,
                  ),
                ),
                const SizedBox(width: 16),
                // Amount with Currency
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Amount with Currency',
                    value: transaction.formattedAmount,
                    isAmount: true,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Segunda fila: Subcategoría, Cuenta, Hour, % OCR
            Row(
              children: [
                // Subcategoría
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Subcategoría',
                    value: transaction.subcategory,
                  ),
                ),
                const SizedBox(width: 16),
                // Cuenta
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Cuenta',
                    value: transaction.account,
                  ),
                ),
                const SizedBox(width: 16),
                // Hour
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Hour',
                    value: DateFormat('HH:mm').format(transaction.date),
                  ),
                ),
                const SizedBox(width: 16),
                // % OCR
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: '% OCR',
                    value: '95%', // TODO: Obtener del transaction
                  ),
                ),
                const SizedBox(width: 16),
                // Espacio vacío para alineación
                const Expanded(flex: 1, child: SizedBox()),
              ],
            ),

            const SizedBox(height: 20),

            // Tercera fila: Vendor, SourceApp, LINKS
            Row(
              children: [
                // Vendor
                Expanded(
                  flex: 1,
                  child: _buildGridItem(
                    label: 'Vendor',
                    value: transaction.destination,
                  ),
                ),
                const SizedBox(width: 16),
                // SourceApp
                Expanded(
                  flex: 1,
                  child: _buildGridItem(label: 'SourceApp', value: 'Yape'),
                ),
                const SizedBox(width: 16),
                // LINKS
                Expanded(
                  flex: 1,
                  child: _buildGridItem(label: 'LINKS', value: 'N/A'),
                ),
                const SizedBox(width: 16),
                // Espacios vacíos para alineación
                const Expanded(flex: 2, child: SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridItem({
    required String label,
    required String? value,
    bool isEmoji = false,
    bool isAmount = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        if (isEmoji)
          Text(
            '🍽️', // TODO: Usar el emoji real de la categoría
            style: const TextStyle(fontSize: 24),
          )
        else if (isAmount)
          Text(
            value ?? '',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          )
        else
          Text(
            value ?? '',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
      ],
    );
  }
}
