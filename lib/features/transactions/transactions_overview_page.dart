import 'package:flutter/material.dart';
import '../../core/financial_domain.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';

FinancialSummary _summarizeExpenses(Iterable<Expense> expenses) {
  return summarizeFinancialMovements(
    expenses.map(
      (expense) => FinancialMovement(
        amountCents: expense.amountCents,
        type: classifyFinancialMovement(expense.origination),
      ),
    ),
  );
}

class TransactionsOverviewPage extends StatefulWidget {
  const TransactionsOverviewPage({
    super.key,
    required this.database,
    this.onSearch,
    this.onFilter,
    this.onAddTransaction,
  });

  final AppDatabase database;
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;
  final VoidCallback? onAddTransaction;

  @override
  State<TransactionsOverviewPage> createState() =>
      _TransactionsOverviewPageState();
}

class _TransactionsOverviewPageState extends State<TransactionsOverviewPage> {
  late Stream<List<Expense>> _expenses;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _expenses = widget.database.watchExpenses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('El Ahorrador 💸'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: widget.onSearch,
          ),
          IconButton(
            tooltip: 'Filtrar',
            icon: const Icon(Icons.filter_list),
            onPressed: widget.onFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          // Resumen de ingresos y gastos
          _buildSummaryCard(),
          // Lista de transacciones
          Expanded(child: _buildTransactionsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar transacción',
        onPressed: widget.onAddTransaction,
        backgroundColor: Colors.red[600],
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _loadingState() => Center(
    child: Semantics(
      label: 'Cargando transacciones',
      liveRegion: true,
      child: CircularProgressIndicator(),
    ),
  );

  Widget _errorState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('No se pudieron cargar las transacciones.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      ],
    ),
  );
  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: StreamBuilder<List<Expense>>(
        stream: _expenses,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState();
          if (!snapshot.hasData) return _loadingState();

          final summary = _summarizeExpenses(snapshot.data!);
          final totalIncome = summary.income;
          final totalExpenses = summary.expense;
          final balance = summary.balance;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Ingresos', totalIncome, Colors.green),
              _buildSummaryItem('Gastos', totalExpenses, Colors.red),
              _buildSummaryItem(
                'Balance',
                balance,
                balance >= 0 ? Colors.green : Colors.red,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'S/ ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<Expense>>(
      stream: _expenses,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _errorState();
        if (!snapshot.hasData) return _loadingState();

        final expenses = snapshot.data!;
        if (expenses.isEmpty) {
          return const Center(
            child: Text(
              'No hay transacciones registradas\nComparte una captura de Yape para empezar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Agrupar por fecha
        final groupedExpenses = <String, List<Expense>>{};
        for (final expense in expenses) {
          final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
          final dateKey =
              '${date.day} ${_getMonthName(date.month)} ${date.year}';
          groupedExpenses.putIfAbsent(dateKey, () => []).add(expense);
        }

        return ListView.builder(
          itemCount: groupedExpenses.length,
          itemBuilder: (context, index) {
            final dateKey = groupedExpenses.keys.elementAt(index);
            final dayExpenses = groupedExpenses[dateKey]!;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateHeader(dateKey, dayExpenses),
                ...dayExpenses.map(_buildTransactionItem),
                const SizedBox(height: 8),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDateHeader(String dateKey, List<Expense> expenses) {
    final summary = _summarizeExpenses(expenses);
    final dayIncome = summary.income;
    final dayExpenses = summary.expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            dateKey,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                'S/ ${dayIncome.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.green, fontSize: 14),
              ),
              const SizedBox(width: 16),
              Text(
                'S/ ${dayExpenses.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.red, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(Expense expense) {
    final amount = expense.amountCents / 100.0;
    final isIncome = amount > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Icono de categorÃ­a
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isIncome ? Colors.green[700] : Colors.red[700],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Detalles de la transacciÃ³n
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.vendor ?? 'Sin descripción',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (expense.notes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    expense.notes!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  expense.sourceApp ?? 'Manual',
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ],
            ),
          ),
          // Monto
          Text(
            'S/ ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              color: isIncome ? Colors.green : Colors.red,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return months[month - 1];
  }
}
