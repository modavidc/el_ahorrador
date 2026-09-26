import 'package:drift/native.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/data/daos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parser category names are resolved to database IDs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertExpenseFromParser(
      id: 'expense-from-yape',
      dateEpochMs: 1785278760000,
      amountCents: 900,
      currency: 'PEN',
      categoryId: 'Comida',
      subcategoryId: 'Otros',
      sourceApp: 'Yape',
    );

    final expense = await db.select(db.expenses).getSingle();
    expect(expense.categoryId, 'mm_cat_2');
    expect(expense.subcategoryId, 'mm_sub_2_14');
  });

  test('existing database IDs remain supported', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await db.insertExpenseFromParser(
      id: 'expense-with-ids',
      dateEpochMs: 1785278760000,
      amountCents: 900,
      currency: 'PEN',
      categoryId: 'mm_cat_2',
      subcategoryId: 'mm_sub_2_14',
    );

    final expense = await db.select(db.expenses).getSingle();
    expect(expense.categoryId, 'mm_cat_2');
    expect(expense.subcategoryId, 'mm_sub_2_14');
  });
}
