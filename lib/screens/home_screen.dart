import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../data/daos.dart';
import '../core/parser.dart';
import '../core/category_service.dart';
import '../models/transaction.dart';
import 'transaction_detail_screen.dart';
import 'add_transaction_screen.dart';
import 'account_settings_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  final AppDatabase db;

  const HomeScreen({super.key, required this.db});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _bottomNavigationIndex = 0;
  DateTime _selectedDate = DateTime.now();
  int _renderedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    CategoryService().initialize(widget.db);
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfffaf9fd),
      appBar: _buildAppBar(),
      body: _buildSelectedDestination(),
      bottomNavigationBar: _buildBottomNavigation(),
      floatingActionButton: _bottomNavigationIndex == 0
          ? Transform.translate(
              offset: const Offset(0, 14),
              child: FloatingActionButton(
                onPressed: _showAddTransactionDialog,
                backgroundColor: const Color(0xfff45b55),
                elevation: 4,
                shape: const CircleBorder(),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            )
          : null,
    );
  }

  Widget _buildSelectedDestination() {
    if (_bottomNavigationIndex != 0) {
      const destinations = [
        ('', Icons.book),
        ('Estadísticas', Icons.bar_chart),
        ('Cuentas', Icons.account_balance_wallet),
        ('Más', Icons.more_horiz),
      ];
      final destination = destinations[_bottomNavigationIndex];
      return _buildComingSoon(destination.$1, destination.$2);
    }

    return Column(
      children: [
        _buildTabBar(),
        Expanded(child: _buildSelectedTab()),
      ],
    );
  }

  Widget _buildSelectedTab() {
    return switch (_tabController.index) {
      0 => Column(
        children: [
          _buildFinancialSummary(),
          Expanded(child: _buildTransactionList()),
        ],
      ),
      1 => Column(
        children: [
          _buildFinancialSummary(),
          Expanded(child: _buildCalendarView()),
        ],
      ),
      2 => Column(
        children: [
          _buildFinancialSummary(yearly: true),
          Expanded(child: _buildMonthlyView()),
        ],
      ),
      3 => Column(
        children: [
          _buildFinancialSummary(),
          Expanded(child: _buildTotalView()),
        ],
      ),
      _ => _buildComingSoon('Notas', Icons.note_alt_outlined),
    };
  }

  Widget _buildComingSoon(String title, IconData icon) {
    return Center(
      key: ValueKey('coming-soon-$title'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Próximamente'),
        ],
      ),
    );
  }

  void _handleTabSelection() {
    if (mounted && _renderedTabIndex != _tabController.index) {
      setState(() => _renderedTabIndex = _tabController.index);
    }
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      toolbarHeight: 46,
      titleSpacing: 0,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Navegación de fecha
          Transform.translate(
            offset: const Offset(-8, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.black,
                    size: 24,
                  ),
                  tooltip: 'Mes anterior',
                ),
                Text(
                  _formatMonthYear(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    color: Colors.black,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.black,
                    size: 24,
                  ),
                  tooltip: 'Mes siguiente',
                ),
              ],
            ),
          ),

          // Iconos de acción
          Row(
            children: [
              IconButton(
                onPressed: null,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.star_border_rounded,
                  color: Colors.black,
                  size: 25,
                ),
                tooltip: 'Favoritos (próximamente)',
              ),
              IconButton(
                onPressed: null,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.search, color: Colors.black, size: 26),
                tooltip: 'Buscar (próximamente)',
              ),
              IconButton(
                onPressed: null,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 44,
                ),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.tune, color: Colors.black, size: 24),
                tooltip: 'Filtrar (próximamente)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return SizedBox(
      height: 38,
      child: TabBar(
        controller: _tabController,
        indicatorColor: const Color(0xffef625d),
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.black,
        unselectedLabelColor: const Color(0xff9b9b9b),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelPadding: EdgeInsets.zero,
        tabs: const [
          Tab(text: 'Daily'),
          Tab(text: 'Calendar'),
          Tab(text: 'Monthly'),
          Tab(text: 'Total'),
          Tab(text: 'Note'),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary({bool yearly = false}) {
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xffdedede))),
      ),
      child: StreamBuilder<List<Expense>>(
        stream: widget.db.watchExpenses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = yearly
              ? snapshot.data!.where((expense) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    expense.date,
                  );
                  return date.year == _selectedDate.year;
                }).toList()
              : _expensesInSelectedMonth(snapshot.data!);
          final (income, expense, balance) = _calculateTotals(expenses);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Income', income, const Color(0xff3d9bc6)),
              _buildSummaryItem('Expenses', expense, const Color(0xffd9796c)),
              _buildSummaryItem('Total', balance, const Color(0xff4d4d4d)),
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
          style: const TextStyle(fontSize: 12, color: Color(0xff4d4d4d)),
        ),
        const SizedBox(height: 2),
        Text(
          _formatAmount(amount, currency: 'PEN', showPenSymbol: false),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showTransactionDetails(Transaction transaction, Expense expense) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionDetailScreen(
          transaction: transaction,
          onEdit: (updated) => _updateTransaction(expense, updated),
          onDelete: () => widget.db.deleteExpense(expense.id),
        ),
      ),
    );
  }

  Future<Transaction> _updateTransaction(
    Expense expense,
    ParsedExpense updated,
  ) async {
    final isManual = expense.sourceApp == 'Manual';
    await widget.db.updateExpenseFromParser(
      id: expense.id,
      dateEpochMs: updated.dateEpochMs,
      amountCents: updated.amountCents,
      currency: updated.currency,
      categoryId: isManual ? expense.categoryId : updated.category,
      subcategoryId: isManual ? expense.subcategoryId : updated.subcategory,
      account: updated.account,
      vendor: isManual ? updated.category : updated.vendor,
      description: updated.description,
      notes: updated.notes,
    );

    return Transaction.fromDatabase(
      id: expense.id,
      date: DateTime.fromMillisecondsSinceEpoch(updated.dateEpochMs),
      type: TransactionType.expense,
      category: updated.category ?? updated.vendor ?? 'otro',
      subcategory: updated.subcategory ?? '',
      description: updated.description ?? 'Sin descripcion',
      account: updated.account ?? '',
      amount: updated.amountCents / 100.0,
      currency: updated.currency,
      notes: updated.notes,
      vendor: isManual ? updated.category : updated.vendor,
      source: expense.source,
      destination: expense.destination,
      icon: Icons.shopping_cart,
      color: Colors.red,
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<List<ExpenseWithLabels>>(
      stream: widget.db.watchExpensesWithLabels(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No pudimos cargar tus transacciones.'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Semantics(
              label: 'Cargando transacciones',
              liveRegion: true,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final labeledExpenses = snapshot.data!
            .where((row) => _isInSelectedMonth(row.expense))
            .toList();
        final expenses = labeledExpenses.map((row) => row.expense).toList();
        if (expenses.isEmpty) {
          return const Align(
            alignment: Alignment(0, -0.43),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_toy_outlined,
                  size: 48,
                  color: Color(0xffd2d2d6),
                ),
                SizedBox(height: 12),
                Text(
                  'No data available.',
                  style: TextStyle(fontSize: 15, color: Color(0xffd2d2d6)),
                ),
              ],
            ),
          );
        }

        // Agrupar por fecha
        final groupedTransactions = _groupTransactionsByDate(expenses);
        final labelsByExpenseId = {
          for (final row in labeledExpenses) row.expense.id: row,
        };

        final rows =
            <({DateTime? date, List<Expense>? day, Expense? expense})>[];
        for (final entry in groupedTransactions.entries) {
          rows.add((date: entry.key, day: entry.value, expense: null));
          for (final expense in entry.value) {
            rows.add((date: null, day: null, expense: expense));
          }
        }

        return ColoredBox(
          color: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 76),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              if (row.date != null) {
                return _buildDayHeader(row.date!, row.day!);
              }

              final expense = row.expense!;
              final labels = labelsByExpenseId[expense.id]!;
              final isIncome = expense.amountCents >= 0;
              final transaction = Transaction.fromDatabase(
                id: expense.id,
                date: DateTime.fromMillisecondsSinceEpoch(expense.date),
                type: isIncome
                    ? TransactionType.income
                    : TransactionType.expense,
                category:
                    labels.categoryName ??
                    expense.vendor ??
                    expense.categoryId ??
                    'otro',
                subcategory: labels.subcategoryName ?? '',
                description: expense.description ?? 'Sin descripcion',
                account: expense.account ?? '',
                amount: expense.amountCents.abs() / 100.0,
                currency: expense.currency,
                notes: expense.notes,
                vendor: expense.vendor,
                source: expense.source,
                destination: expense.destination,
                icon: isIncome ? Icons.attach_money : Icons.shopping_cart,
                color: isIncome ? Colors.green : Colors.red,
              );
              return _buildDailyTransactionItem(
                transaction: transaction,
                onTap: () => _showTransactionDetails(transaction, expense),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final byDay = _groupTransactionsByDate(snapshot.data!);
        final first = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final gridStart = first.subtract(Duration(days: first.weekday % 7));
        const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

        return ColoredBox(
          key: const ValueKey('calendar-view'),
          color: Colors.white,
          child: Column(
            children: [
              SizedBox(
                height: 24,
                child: Row(
                  children: List.generate(7, (index) {
                    final color = index == 0
                        ? const Color(0xffd9796c)
                        : index == 6
                        ? const Color(0xff579dbb)
                        : const Color(0xff777777);
                    return Expanded(
                      child: Center(
                        child: Text(
                          weekdays[index],
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.67,
                  ),
                  itemCount: 42,
                  itemBuilder: (context, index) {
                    final date = gridStart.add(Duration(days: index));
                    return _buildCalendarCell(date, byDay[date] ?? const []);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarCell(DateTime date, List<Expense> transactions) {
    final inMonth = date.month == _selectedDate.month;
    final (income, expense, balance) = _calculateTotals(transactions);
    final isToday = DateUtils.isSameDay(date, DateTime.now());
    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      child: Container(
        decoration: BoxDecoration(
          color: inMonth ? Colors.white : const Color(0xfff7f7f9),
          border: const Border(
            top: BorderSide(color: Color(0xffdddddd), width: .5),
            right: BorderSide(color: Color(0xffdddddd), width: .5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 20,
              padding: const EdgeInsets.only(left: 3, top: 2),
              color: isToday ? const Color(0xff444b78) : Colors.transparent,
              child: Text(
                date.day == 1 && !inMonth ? '${date.month}.1' : '${date.day}',
                style: TextStyle(
                  fontSize: 10,
                  color: isToday
                      ? Colors.white
                      : inMonth
                      ? const Color(0xff666666)
                      : const Color(0xff999999),
                ),
              ),
            ),
            const Spacer(),
            if (income > 0) _calendarAmount(income, const Color(0xff3294c0)),
            if (expense > 0) _calendarAmount(expense, const Color(0xffd9796c)),
            if (transactions.isNotEmpty)
              _calendarAmount(balance, const Color(0xff555555)),
            const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }

  Widget _calendarAmount(double amount, Color color) => Padding(
    padding: const EdgeInsets.only(right: 3, top: 2),
    child: Text(
      amount.toStringAsFixed(2),
      maxLines: 1,
      overflow: TextOverflow.clip,
      textAlign: TextAlign.right,
      style: TextStyle(fontSize: 9, color: color),
    ),
  );

  Widget _buildMonthlyView() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final expenses = snapshot.data!;
        final current = DateTime.now();
        final maxMonth = _selectedDate.year == current.year
            ? current.month
            : 12;
        return ColoredBox(
          key: const ValueKey('monthly-view'),
          color: Colors.white,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 76),
            itemCount: maxMonth,
            itemBuilder: (context, index) {
              final month = maxMonth - index;
              final monthExpenses = expenses.where((expense) {
                final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
                return date.year == _selectedDate.year && date.month == month;
              }).toList();
              return Column(
                children: [
                  _buildMonthSummary(month, monthExpenses),
                  if (month == _selectedDate.month)
                    ..._buildWeekRows(month, monthExpenses),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMonthSummary(int month, List<Expense> expenses) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final (income, expense, balance) = _calculateTotals(expenses);
    final lastDay = DateTime(_selectedDate.year, month + 1, 0).day;
    return InkWell(
      onTap: () => setState(
        () => _selectedDate = DateTime(_selectedDate.year, month, 1),
      ),
      child: Container(
        height: 55,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xffdddddd))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    months[month - 1],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$month.1 ~ $month.$lastDay',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xff8d8d8d),
                    ),
                  ),
                ],
              ),
            ),
            _monthlyAmounts(income, expense, balance),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWeekRows(int month, List<Expense> expenses) {
    final first = DateTime(_selectedDate.year, month, 1);
    var start = first.subtract(Duration(days: first.weekday % 7));
    final last = DateTime(_selectedDate.year, month + 1, 0);
    final rows = <Widget>[];
    while (!start.isAfter(last)) {
      final end = start.add(const Duration(days: 6));
      final weekExpenses = expenses.where((expense) {
        final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
        return !date.isBefore(start) &&
            date.isBefore(end.add(const Duration(days: 1)));
      }).toList();
      final (income, expense, balance) = _calculateTotals(weekExpenses);
      rows.add(
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(
            color: Color(0xfffafafd),
            border: Border(bottom: BorderSide(color: Color(0xffdddddd))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Text(
                    '${start.month.toString().padLeft(2, '0')}.${start.day.toString().padLeft(2, '0')}  ~  ${end.month.toString().padLeft(2, '0')}.${end.day.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xff666666),
                    ),
                  ),
                ),
              ),
              _monthlyAmounts(income, expense, balance),
            ],
          ),
        ),
      );
      start = start.add(const Duration(days: 7));
    }
    return rows;
  }

  Widget _monthlyAmounts(
    double income,
    double expense,
    double balance,
  ) => SizedBox(
    width: 178,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _formatAmount(income, currency: 'PEN'),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: Color(0xff3294c0)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formatAmount(expense, currency: 'PEN'),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 13, color: Color(0xffd96e60)),
              ),
            ),
          ],
        ),
        Text(
          _formatAmount(balance, currency: 'PEN'),
          style: const TextStyle(fontSize: 10, color: Color(0xff777777)),
        ),
      ],
    ),
  );

  Widget _buildTotalView() {
    return StreamBuilder<List<Expense>>(
      stream: widget.db.watchExpenses(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final all = snapshot.data!;
        final current = _expensesInSelectedMonth(all);
        final previousDate = DateTime(
          _selectedDate.year,
          _selectedDate.month - 1,
        );
        final previous = all.where((expense) {
          final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
          return date.year == previousDate.year &&
              date.month == previousDate.month;
        }).toList();
        final currentExpense = _calculateTotals(current).$2;
        final previousExpense = _calculateTotals(previous).$2;
        final comparison = previousExpense == 0
            ? 0
            : (currentExpense / previousExpense * 100).round();
        final cardExpense = current
            .where((expense) {
              final account = (expense.account ?? '').toLowerCase();
              return expense.amountCents < 0 &&
                  (account.contains('card') || account.contains('tarjeta'));
            })
            .fold<double>(
              0,
              (sum, expense) => sum + expense.amountCents.abs() / 100,
            );
        final accountExpense = currentExpense - cardExpense;
        final lastDay = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
        ).day;

        return ColoredBox(
          key: const ValueKey('total-view'),
          color: const Color(0xfffaf9fd),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 80),
            children: [
              _totalSection(
                icon: Icons.request_quote_outlined,
                title: 'Budget',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  color: const Color(0xfff7f7f7),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Budget Setting',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xff777777),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Color(0xff888888),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              _totalSection(
                icon: Icons.monetization_on_outlined,
                title: 'Accounts',
                trailing: Text(
                  '${_selectedDate.month}.1.${_selectedDate.year.toString().substring(2)}  ~  ${_selectedDate.month}.$lastDay.${_selectedDate.year.toString().substring(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xff777777),
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xffd4d4d4)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  children: [
                    _totalMetric(
                      'Compared Expenses (Last month)',
                      '$comparison%',
                    ),
                    _totalMetric(
                      'Expenses (Efectivo, Cuentas)',
                      _formatAmount(accountExpense, currency: 'PEN'),
                    ),
                    _totalMetric(
                      'Expenses (Card)',
                      _formatAmount(cardExpense, currency: 'PEN'),
                    ),
                    _totalMetric(
                      'Transfer  (Efectivo, Cuentas→ )',
                      _formatAmount(0, currency: 'PEN'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'La exportación a Excel estará disponible próximamente.',
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: const Color(0xff333333),
                    side: const BorderSide(color: Color(0xffd4d4d4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  icon: const Icon(
                    Icons.grid_on,
                    color: Color(0xff47b884),
                    size: 22,
                  ),
                  label: const Text(
                    'Export data to Excel',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _totalSection({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) => Container(
    height: 62,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    color: Colors.white,
    child: Row(
      children: [
        Icon(icon, size: 22, color: Colors.black),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, color: Color(0xff222222)),
        ),
        const Spacer(),
        trailing,
      ],
    ),
  );

  Widget _totalMetric(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xff888888)),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xff333333)),
        ),
      ],
    ),
  );

  Widget _buildBottomNavigation() {
    return AppBottomNavigation(
      currentIndex: _bottomNavigationIndex,
      onTap: _onBottomDestinationSelected,
    );
  }

  void _onBottomDestinationSelected(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StatsScreen(db: widget.db)),
      );
    } else if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AccountSettingsScreen(db: widget.db)),
      );
    } else if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsScreen(db: widget.db)),
      );
    } else {
      setState(() => _bottomNavigationIndex = index);
    }
  }

  Widget _buildDayHeader(DateTime date, List<Expense> transactions) {
    final (income, expense, _) = _calculateTotals(transactions);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xffe3e3e3)),
          bottom: BorderSide(color: Color(0xffe3e3e3)),
        ),
      ),
      child: Row(
        children: [
          Text(
            '${date.day}',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xff909090),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              weekdays[date.weekday - 1],
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${date.month.toString().padLeft(2, '0')}.${date.year}',
            style: const TextStyle(fontSize: 10, color: Color(0xff858585)),
          ),
          const Spacer(),
          SizedBox(
            width: 88,
            child: Text(
              _formatAmount(income, currency: 'PEN'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xff3294c0)),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              _formatAmount(expense, currency: 'PEN'),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, color: Color(0xffd96e60)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyTransactionItem({
    required Transaction transaction,
    required VoidCallback onTap,
  }) {
    final isIncome = transaction.type == TransactionType.income;
    final category = _dailyCategory(transaction);
    final subcategory = transaction.subcategory.startsWith('sub_')
        ? ''
        : transaction.subcategory;
    return Semantics(
      button: true,
      label: '${transaction.description}, ${transaction.formattedAmount}',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 3, 14, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 70,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _dailyCategoryEmoji(category),
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xff8a8a8a),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (subcategory.isNotEmpty)
                        Text(
                          subcategory,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xff999999),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xff4e4e4e),
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        transaction.account,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xff929292),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 84,
                  child: Text(
                    _formatAmount(
                      transaction.amount,
                      currency: transaction.currency,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      color: isIncome
                          ? const Color(0xff3294c0)
                          : const Color(0xffd96e60),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dailyCategory(Transaction transaction) {
    final raw = transaction.category.toLowerCase();
    if (transaction.description.toLowerCase().contains('difference') ||
        raw.contains('modific')) {
      return 'Modified Bal.';
    }
    if (raw.contains('comida') || raw.contains('aliment') || raw == 'cat_1') {
      return 'Comida';
    }
    if (raw.contains('transport') || raw == 'cat_2') return 'Transporte';
    return transaction.categoryDisplayName == 'Otro'
        ? 'Otros'
        : transaction.categoryDisplayName;
  }

  String _dailyCategoryEmoji(String category) {
    if (category == 'Comida') return '🍜';
    if (category == 'Transporte') return '🚗';
    if (category == 'Modified Bal.') return '';
    return '🔠';
  }

  String _formatAmount(
    double amount, {
    required String currency,
    bool showPenSymbol = true,
  }) {
    final upperCurrency = currency.toUpperCase();
    if (upperCurrency == 'USD') {
      return '\$ ${amount.toStringAsFixed(2)}';
    }
    if (upperCurrency != 'PEN') {
      return '${amount.toStringAsFixed(2)} $upperCurrency';
    }
    return '${showPenSymbol ? 'S/. ' : ''}${amount.toStringAsFixed(2)}';
  }

  List<Expense> _expensesInSelectedMonth(List<Expense> expenses) =>
      expenses.where(_isInSelectedMonth).toList();

  bool _isInSelectedMonth(Expense expense) {
    final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
    return date.year == _selectedDate.year && date.month == _selectedDate.month;
  }

  // Métodos auxiliares
  String _formatMonthYear(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.year}';
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
      if (amount >= 0) {
        income += amount;
      } else {
        expense += amount.abs();
      }
    }

    return (income, expense, income - expense);
  }

  Map<DateTime, List<Expense>> _groupTransactionsByDate(
    List<Expense> expenses,
  ) {
    final Map<DateTime, List<Expense>> grouped = {};

    for (final expense in expenses) {
      final date = DateTime.fromMillisecondsSinceEpoch(expense.date);
      final dateOnly = DateTime(date.year, date.month, date.day);

      grouped.putIfAbsent(dateOnly, () => []).add(expense);
    }

    for (final transactions in grouped.values) {
      transactions.sort((a, b) {
        final byTransactionTime = b.date.compareTo(a.date);
        return byTransactionTime != 0
            ? byTransactionTime
            : b.createdAt.compareTo(a.createdAt);
      });
    }

    // Ordenar por fecha (más reciente primero)
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Map.fromEntries(sortedEntries);
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
