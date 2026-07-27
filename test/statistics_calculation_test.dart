import 'package:flutter_test/flutter_test.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/screens/statistics_screen.dart';

void main() {
  Expense expense({
    required String id,
    required int cents,
    String? origin,
    String? category,
    String? vendor,
  }) => Expense(
    id: id,
    date: DateTime(2026, 7, 1).millisecondsSinceEpoch,
    amountCents: cents,
    currency: 'PEN',
    categoryId: category,
    vendor: vendor,
    origination: origin,
    createdAt: 0,
    updatedAt: 0,
  );

  test('separa ingresos, gastos y excluye transferencias', () {
    final rows = [
      expense(id: '1', cents: 1234, origin: 'income'),
      expense(id: '2', cents: -500, origin: 'expense'),
      expense(id: '3', cents: 9999, origin: 'transfer'),
      expense(id: '4', cents: 100, origin: 'Ingreso'),
    ];

    expect(statisticsTotal(rows, StatisticsType.income), 13.34);
    expect(statisticsTotal(rows, StatisticsType.expense), 5);
  });

  test('agrupa por categoría y usa comercio solo como respaldo', () {
    final rows = [
      expense(
        id: '1',
        cents: 1000,
        origin: 'expense',
        category: 'alimentacion',
        vendor: 'Tienda A',
      ),
      expense(
        id: '2',
        cents: 500,
        origin: 'expense',
        category: 'alimentacion',
        vendor: 'Tienda B',
      ),
      expense(id: '3', cents: 500, origin: 'expense', vendor: 'Taxi'),
    ];

    final groups = buildStatisticsGroups(rows, StatisticsType.expense);

    expect(groups.map((group) => group.name), ['Alimentacion', 'Taxi']);
    expect(groups.first.amount, 15);
    expect(groups.first.percentage, .75);
  });
}
