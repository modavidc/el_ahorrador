import 'package:flutter/material.dart';

import '../core/category_service.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../models/transaction.dart';
import '../widgets/transaction_item.dart';
import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'more_screen.dart';
import 'statistics_screen.dart';
import 'transaction_detail_screen.dart';
import 'transaction_views.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;
  final CategoryService categoryService;

  const HomeScreen({
    super.key,
    required this.db,
    required this.categoryService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFFF0523C);
  static const _background = Color(0xFFF4F4F6);
  late final TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  bool _fabOpen = false;
  int _currentSection = 0;
  late final List<Widget> _sections;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTransactionViewChanged);
    _sections = [
      _buildTransactionsSection(),
      StatisticsScreen(db: widget.db),
      AccountsScreen(db: widget.db),
      const MoreScreen(),
    ];
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTransactionViewChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: _currentSection == 0 ? _buildAppBar() : null,
      body: IndexedStack(index: _currentSection, children: _sections),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _currentSection == 0 ? _buildFloatingMenu() : null,
    );
  }

  Widget _buildTransactionsSection() {
    return Stack(
      children: [
        Column(
          children: [
            _buildTabBar(),
            _buildFinancialSummary(),
            Expanded(
              child: TransactionViewBody(
                db: widget.db,
                month: _selectedDate,
                view: TransactionView.values[_tabController.index],
                onExpenseTap: (expense) =>
                    _showTransactionDetails(_transactionFromExpense(expense)),
              ),
            ),
          ],
        ),
        if (_fabOpen)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeFab,
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
            ),
          ),
      ],
    );
  }

  void _onTransactionViewChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      toolbarHeight: 58,
      titleSpacing: 8,
      title: Row(
        children: [
          _headerButton(
            Icons.chevron_left_rounded,
            _previousMonth,
            label: 'Mes anterior',
          ),
          Text(
            _formatMonthYear(_selectedDate),
            style: const TextStyle(
              color: Color(0xFF222222),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          _headerButton(
            Icons.chevron_right_rounded,
            _nextMonth,
            label: 'Mes siguiente',
          ),
          const Spacer(),
          _headerButton(Icons.star_border_rounded, () {}, label: 'Favoritos'),
          _headerButton(Icons.search_rounded, () {}, label: 'Buscar'),
          _headerButton(Icons.tune_rounded, () {}, label: 'Filtros'),
        ],
      ),
    );
  }

  Widget _headerButton(
    IconData icon,
    VoidCallback onPressed, {
    required String label,
  }) {
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: EdgeInsets.zero,
      icon: Icon(icon, color: const Color(0xFF444444), size: 23),
    );
  }

  Widget _buildTabBar() {
    return ColoredBox(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        indicatorColor: _accent,
        indicatorWeight: 3,
        dividerColor: Colors.transparent,
        labelColor: _accent,
        unselectedLabelColor: const Color(0xFF999999),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Diario'),
          Tab(text: 'Calend.'),
          Tab(text: 'Mensual'),
          Tab(text: 'Total'),
          Tab(text: 'Nota'),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SizedBox(
            height: 96,
            child: Center(
              child: Semantics(
                liveRegion: true,
                child: Text('No se pudo cargar el resumen financiero.'),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator(color: _accent)),
          );
        }
        final monthRows = snapshot.data!.where((row) {
          final date = DateTime.fromMillisecondsSinceEpoch(row.date);
          return date.year == _selectedDate.year &&
              date.month == _selectedDate.month;
        }).toList();
        final (income, expense, balance) = _calculateTotals(monthRows);
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _summaryItem(
                  'Ingresos',
                  income,
                  const Color(0xFF2F80ED),
                ),
              ),
              const SizedBox(
                height: 42,
                child: VerticalDivider(color: Color(0xFFF0F0F0)),
              ),
              Expanded(child: _summaryItem('Gastos', expense, _accent)),
              const SizedBox(
                height: 42,
                child: VerticalDivider(color: Color(0xFFF0F0F0)),
              ),
              Expanded(
                child: _summaryItem(
                  'Balance',
                  balance,
                  balance < 0 ? _accent : const Color(0xFF2F80ED),
                  signed: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryItem(
    String label,
    double amount,
    Color color, {
    bool signed = false,
  }) {
    final prefix = signed && amount < 0 ? '-' : '';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8A8A8A)),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$prefix S/. ${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // Conservado temporalmente durante la migración visual para comparar el
  // render diario anterior con las nuevas vistas reactivas.
  // ignore: unused_element
  Widget _buildTransactionList() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('No se pudieron cargar las transacciones.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _accent));
        }
        final expenses = snapshot.data!;
        if (expenses.isEmpty) return _emptyState();
        final groups = _groupTransactionsByDate(expenses);
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final entry = groups.entries.elementAt(index);
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 8),
                  child: Row(
                    children: [
                      Text(
                        _formatDate(entry.key),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF222222),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatSignedAmount(_calculateDayTotal(entry.value)),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _calculateDayTotal(entry.value) < 0
                              ? _accent
                              : const Color(0xFF2F80ED),
                        ),
                      ),
                    ],
                  ),
                ),
                ...entry.value.map(_buildTransactionCard),
              ],
            );
          },
        );
      },
    );
  }

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_rounded, size: 58, color: Color(0xFFB5B5B5)),
          SizedBox(height: 14),
          Text(
            'No hay transacciones aún',
            style: TextStyle(fontSize: 17, color: Color(0xFF777777)),
          ),
          SizedBox(height: 6),
          Text(
            'Comparte una captura para empezar',
            style: TextStyle(color: Color(0xFF999999)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Expense expense) {
    final transaction = _transactionFromExpense(expense);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: TransactionItem(
        transaction: transaction,
        onTap: () => _showTransactionDetails(transaction),
      ),
    );
  }

  Transaction _transactionFromExpense(Expense expense) {
    return Transaction.fromDatabase(
      id: expense.id,
      date: DateTime.fromMillisecondsSinceEpoch(expense.date),
      type: switch (classifyOrigination(expense.origination)) {
        LedgerEntryKind.income => TransactionType.income,
        LedgerEntryKind.transfer => TransactionType.transfer,
        LedgerEntryKind.expense => TransactionType.expense,
      },
      category: expense.categoryId ?? 'Otros',
      subcategory: expense.subcategoryId ?? 'Otros',
      description:
          expense.description ??
          expense.vendor ??
          'Transacción sin descripción',
      account: expense.account ?? '',
      amount: expense.amountCents.abs() / 100,
      currency: expense.currency,
      notes: expense.notes,
      vendor: expense.vendor,
      source: expense.source,
      destination: expense.destination,
      icon: Icons.shopping_cart_rounded,
      color: _accent,
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      elevation: 12,
      type: BottomNavigationBarType.fixed,
      currentIndex: _currentSection,
      selectedItemColor: _accent,
      unselectedItemColor: const Color(0xFF999999),
      selectedLabelStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(fontSize: 11),
      onTap: (index) {
        _closeFab();
        setState(() => _currentSection = index);
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.book_rounded),
          label: 'Trans.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Estad.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_rounded),
          label: 'Cuentas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz_rounded),
          label: 'Más',
        ),
      ],
    );
  }

  Widget _buildFloatingMenu() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, .15),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: _fabOpen
              ? Column(
                  key: const ValueKey('fab-options'),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _fabAction(
                      'Añadir manual',
                      Icons.edit_rounded,
                      const Color(0xFF2F80ED),
                      _openAddTransaction,
                    ),
                    _fabAction(
                      'Añadir por OCR',
                      Icons.document_scanner_rounded,
                      const Color(0xFF27AE60),
                      _showOcrInstructions,
                    ),
                    _fabAction(
                      'Añadir supertransacción',
                      Icons.bolt_rounded,
                      const Color(0xFFFF9F1C),
                      () => _showComingSoon('Supertransacción'),
                    ),
                    _fabAction(
                      'Preguntar a la IA',
                      Icons.auto_awesome_rounded,
                      const Color(0xFF9B51E0),
                      () => _showComingSoon('Asistente IA'),
                    ),
                    const SizedBox(height: 4),
                  ],
                )
              : const SizedBox.shrink(key: ValueKey('fab-closed')),
        ),
        FloatingActionButton(
          tooltip: _fabOpen
              ? 'Cerrar menú de transacciones'
              : 'Añadir transacción',
          heroTag: 'home-main-fab',
          onPressed: () => setState(() => _fabOpen = !_fabOpen),
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          elevation: 8,
          shape: const CircleBorder(),
          child: AnimatedRotation(
            turns: _fabOpen ? .125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add_rounded, size: 32),
          ),
        ),
      ],
    );
  }

  Widget _fabAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white,
            elevation: 3,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          FloatingActionButton.small(
            heroTag: label,
            onPressed: onPressed,
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 5,
            child: Icon(icon, size: 20),
          ),
        ],
      ),
    );
  }

  void _closeFab() {
    if (_fabOpen) setState(() => _fabOpen = false);
  }

  void _showOcrInstructions() {
    _closeFab();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Para añadir por OCR, comparte una captura de Yape o de tu banco con El Ahorrador.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showComingSoon(String feature) {
    _closeFab();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature estará disponible próximamente.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showTransactionDetails(Transaction transaction) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionDetailScreen(
          transaction: transaction,
          db: widget.db,
          categoryService: widget.categoryService,
        ),
      ),
    );
  }

  Future<void> _openAddTransaction() async {
    _closeFab();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: AddTransactionScreen(db: widget.db),
          ),
        );
      },
    );
  }

  String _formatMonthYear(DateTime date) {
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
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const days = ['dom', 'lun', 'mar', 'mié', 'jue', 'vie', 'sáb'];
    return '${date.day} ${days[date.weekday % 7]} ${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _formatSignedAmount(double amount) {
    final sign = amount < 0 ? '-' : '';
    return '$sign S/. ${amount.abs().toStringAsFixed(2)}';
  }

  void _previousMonth() => setState(() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
  });

  void _nextMonth() => setState(() {
    _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
  });

  (double, double, double) _calculateTotals(List<Expense> expenses) {
    var income = 0.0;
    var expense = 0.0;
    for (final item in expenses) {
      final amount = item.amountCents.abs() / 100;
      final kind = classifyOrigination(item.origination);
      if (kind == LedgerEntryKind.income) {
        income += amount;
      } else if (kind != LedgerEntryKind.transfer) {
        expense += amount;
      }
    }
    return (income, expense, income - expense);
  }

  Map<DateTime, List<Expense>> _groupTransactionsByDate(
    List<Expense> expenses,
  ) {
    final groups = <DateTime, List<Expense>>{};
    for (final expense in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
      groups
          .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
          .add(expense);
    }
    final entries = groups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return Map.fromEntries(entries);
  }

  double _calculateDayTotal(List<Expense> transactions) {
    return transactions.fold(0, (sum, item) {
      final amount = item.amountCents.abs() / 100;
      final kind = classifyOrigination(item.origination);
      if (kind == LedgerEntryKind.income) return sum + amount;
      if (kind == LedgerEntryKind.transfer) return sum;
      return sum - amount;
    });
  }
}
