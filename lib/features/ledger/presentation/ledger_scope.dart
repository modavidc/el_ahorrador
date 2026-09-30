import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';

/// Everything the screens read, kept up to date from the database.
final class LedgerData {
  const LedgerData({
    required this.repository,
    required this.movements,
    required this.accounts,
    required this.budgets,
    required this.monthlyBudgetCents,
    required this.loaded,
    this.letters = CategoryLetters.defaults,
  });

  final LedgerRepository repository;
  final List<Movement> movements;

  /// Letter of each category ("C" → Comida).
  final CategoryLetters letters;
  final List<LedgerAccount> accounts;
  final Map<String, int> budgets;
  final int monthlyBudgetCents;
  final bool loaded;
}

/// Subscribes once to the ledger streams and exposes the latest snapshot to
/// every screen below it.
class LedgerProvider extends StatefulWidget {
  const LedgerProvider({
    super.key,
    required this.repository,
    required this.child,
  });

  final LedgerRepository repository;
  final Widget child;

  @override
  State<LedgerProvider> createState() => _LedgerProviderState();
}

class _LedgerProviderState extends State<LedgerProvider> {
  final _subscriptions = <StreamSubscription<Object>>[];
  List<Movement>? _movements;
  List<LedgerAccount>? _accounts;
  Map<String, int>? _budgets;
  int? _monthlyBudget;
  CategoryLetters? _letters;

  @override
  void initState() {
    super.initState();
    final r = widget.repository;
    _subscriptions
      ..add(r.watchMovements().listen((v) => setState(() => _movements = v)))
      ..add(r.watchAccounts().listen((v) => setState(() => _accounts = v)))
      ..add(r.watchBudgets().listen((v) => setState(() => _budgets = v)))
      ..add(
        r.watchCategoryLetters().listen((v) => setState(() => _letters = v)),
      )
      ..add(
        r.watchMonthlyBudget().listen(
          (v) => setState(() => _monthlyBudget = v),
        ),
      );
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LedgerScope(
    data: LedgerData(
      repository: widget.repository,
      movements: _movements ?? const [],
      accounts: _accounts ?? const [],
      budgets: _budgets ?? const {},
      monthlyBudgetCents:
          _monthlyBudget ?? LedgerRepository.defaultMonthlyBudgetCents,
      loaded: _movements != null && _accounts != null && _budgets != null,
      letters: _letters ?? CategoryLetters.defaults,
    ),
    child: widget.child,
  );
}

class LedgerScope extends InheritedWidget {
  const LedgerScope({super.key, required this.data, required super.child});

  final LedgerData data;

  /// The same live data for a pushed route, which sits above the app's
  /// provider in the navigator.
  static Widget forward(BuildContext context, {required Widget child}) =>
      LedgerProvider(repository: of(context).repository, child: child);

  static LedgerData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LedgerScope>()!.data;

  @override
  bool updateShouldNotify(LedgerScope oldWidget) => data != oldWidget.data;
}
