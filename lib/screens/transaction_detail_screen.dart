import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/category_service.dart';
import '../core/file_store.dart';
import '../core/parser.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../models/transaction.dart';
import '../widgets/expense_edit_dialog.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction transaction;
  final AppDatabase db;
  final CategoryService categoryService;

  const TransactionDetailScreen({
    super.key,
    required this.transaction,
    required this.db,
    required this.categoryService,
  });

  String? get _ocrConfidence {
    final match = RegExp(
      r'\[OCR Confianza: ([^%\]]+)%\]',
      caseSensitive: false,
    ).firstMatch(transaction.notes ?? '');
    return match?.group(1)?.trim();
  }

  String get _sourceApp {
    final source = transaction.source?.trim();
    return (source?.isNotEmpty ?? false) ? source! : 'Manual';
  }

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
            onPressed: () => _editTransaction(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteTransaction(context),
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

  Future<void> _editTransaction(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ExpenseEditDialog(
        categoryService: categoryService,
        expense: ParsedExpense(
          amountCents: (transaction.amount.abs() * 100).round(),
          currency: transaction.currency,
          dateEpochMs: transaction.date.millisecondsSinceEpoch,
          category: transaction.category,
          subcategory: transaction.subcategory,
          account: transaction.account,
          vendor: transaction.vendor,
          description: transaction.description,
          notes: transaction.notes,
          sourceApp: 'Manual',
        ),
        onSave: (updated) async {
          await db.updateExpenseFromParser(
            id: transaction.id,
            dateEpochMs: updated.dateEpochMs,
            amountCents: updated.amountCents.abs(),
            currency: updated.currency,
            categoryId: updated.category,
            subcategoryId: updated.subcategory,
            account: updated.account,
            vendor: updated.vendor,
            description: updated.description,
            notes: updated.notes,
          );
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _deleteTransaction(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar transacción'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await db.deleteExpenseWithCapture(
      transaction.id,
      deleteFile: FileStore.securelyDelete,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Widget _buildGridLayout() {
    return DecoratedBox(
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
                    value: '',
                    icon: transaction.icon,
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
                    value: _ocrConfidence == null
                        ? 'N/A'
                        : '${_ocrConfidence!}%',
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
                  child: _buildGridItem(label: 'SourceApp', value: _sourceApp),
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
    IconData? icon,
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
        if (icon != null)
          Icon(icon, size: 24, color: transaction.color)
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
