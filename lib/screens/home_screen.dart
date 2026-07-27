import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'debug_ocr_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  
  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Tabs de navegación
          _buildTabBar(),
          
          // Resumen financiero
          _buildFinancialSummary(),
          
          // Lista de transacciones
          Expanded(
            child: _buildTransactionList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTransactionDialog,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Navegación de fecha
          Row(
            children: [
              IconButton(
                onPressed: _previousMonth,
                icon: const Icon(Icons.chevron_left, color: Colors.black),
              ),
              Text(
                _formatMonthYear(_selectedDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              IconButton(
                onPressed: _nextMonth,
                icon: const Icon(Icons.chevron_right, color: Colors.black),
              ),
            ],
          ),
          
          // Iconos de acción
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DebugOcrScreen(db: widget.db),
                    ),
                  );
                },
                icon: const Icon(Icons.bug_report, color: Colors.black),
                tooltip: 'Debug OCR',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.star_border, color: Colors.black),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search, color: Colors.black),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.filter_list, color: Colors.black),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.red,
        labelColor: Colors.red,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(text: 'Diario'),
          Tab(text: 'Calendario'),
          Tab(text: 'Mensual'),
          Tab(text: 'Total'),
          Tab(text: 'Nota'),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
      child: StreamBuilder<List<Expense>>(
        stream: widget.db.watchExpenses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final expenses = snapshot.data!;
          final (income, expense, balance) = _calculateTotals(expenses);
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Ingresos', income, Colors.blue),
              _buildSummaryItem('Gastos', expense, Colors.red),
              _buildSummaryItem('Balance', balance, balance >= 0 ? Colors.green : Colors.red),
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
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'S/. ${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showTransactionDetails(Transaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          transaction: transaction,
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Semantics(liveRegion: true, child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('No pudimos cargar tus transacciones.'),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: () => setState(() {}), icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ])));
        }
        
        if (!snapshot.hasData) {
          return Center(child: Semantics(label: 'Cargando transacciones', liveRegion: true, child: const CircularProgressIndicator()));
        }
        
        final expenses = snapshot.data!;
        if (expenses.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No hay transacciones aún',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Comparte una captura para empezar',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        // Agrupar por fecha
        final groupedTransactions = _groupTransactionsByDate(expenses);
        
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: groupedTransactions.length,
          itemBuilder: (context, index) {
            final entry = groupedTransactions.entries.elementAt(index);
            final date = entry.key;
            final transactions = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de fecha
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'S/. ${_calculateDayTotal(transactions).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lista de transacciones del día
                ...transactions.map((expense) {
                  final transaction = Transaction.fromDatabase(
                    id: expense.id,
                    date: DateTime.fromMillisecondsSinceEpoch(expense.date),
                    type: TransactionType.expense,
                    category: expense.categoryId!,
                    subcategory: expense.subcategoryId!,
                    description: expense.description!,
                    account: expense.account ?? '',
                    amount: expense.amountCents / 100.0,
                    currency: expense.currency,
                    notes: expense.notes,
                    vendor: expense.vendor,
                    source: expense.source,
                    destination: expense.destination,
                    icon: Icons.shopping_cart,
                    color: Colors.red,
                  );

                  return TransactionItem(
                    transaction: transaction,
                    onTap: () => _showTransactionDetails(transaction),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.red,
      unselectedItemColor: Colors.grey,
      currentIndex: 0,
      onTap: (index) {
        // TODO: Implementar navegación
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Trans.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart),
          label: 'Estad.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet),
          label: 'Cuentas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: 'Más',
        ),
      ],
    );
  }

  // Métodos auxiliares
  String _formatMonthYear(DateTime date) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    return '${date.day} ${days[date.weekday % 7]} ${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
    });
  }

  (double, double, double) _calculateTotals(List<Expense> expenses) {
    double income = 0;
    double expense = 0;
    
    for (final exp in expenses) {
      final amount = exp.amountCents / 100.0;
      // Por ahora, asumimos que todos son gastos
      // TODO: Mejorar lógica de detección de ingresos
      expense += amount;
    }
    
    return (income, expense, income - expense);
  }

  Map<DateTime, List<Expense>> _groupTransactionsByDate(List<Expense> expenses) {
    final Map<DateTime, List<Expense>> grouped = {};
    
    for (final expense in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      grouped.putIfAbsent(dateOnly, () => []).add(expense);
    }
    
    // Ordenar por fecha (más reciente primero)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    
    return Map.fromEntries(sortedEntries);
  }

  double _calculateDayTotal(List<Expense> transactions) {
    return transactions.fold(0.0, (sum, exp) => sum + (exp.amountCents / 100.0));
  }

  void _showAddTransactionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddTransactionScreen(db: widget.db),
      ),
    );
  }
}
