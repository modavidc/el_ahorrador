import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// Puts deleted rows back ("Deshacer").
typedef Restore = Future<void> Function();

/// Port of the ledger: movements, accounts and budgets. The data layer
/// implements it; screens and use cases only see this interface.
abstract interface class LedgerRepository {
  /// Budget used until the user sets one (the prototype's S/ 2,400).
  static const defaultMonthlyBudgetCents = 240000;

  Stream<List<Movement>> watchMovements();
  Stream<List<LedgerAccount>> watchAccounts();

  /// Monthly cap in cents per category name.
  Stream<Map<String, int>> watchBudgets();
  Stream<int> watchMonthlyBudget();

  Future<void> setMonthlyBudget(int cents);

  /// Letter of each category for "C 15" and Yape messages.
  Stream<CategoryLetters> watchCategoryLetters();
  Future<void> setCategoryLetters(CategoryLetters letters);
  Future<void> setBudget(String category, int monthlyCapCents);
  Future<void> clearBudget(String category);

  /// Registers a movement and returns its id. [captureId] links the image
  /// it was read from and [details] keeps what its receipt said.
  Future<String> addEntry({
    required MovementType type,
    required int amountCents,
    required String account,
    String? category,
    String? toAccount,
    String? note,
    DateTime? at,
    String sourceApp = 'Manual',
    String? captureId,
    PaymentDetails details = const PaymentDetails(),
  });

  /// Deletes a movement (both halves of a transfer).
  Future<Restore> delete(Movement m);

  /// Removes a registered income or expense by id.
  Future<void> deleteById(String id);

  Future<void> setCategory(Movement m, String category);

  /// Registers the same movement again today ("Repetir").
  Future<String> repeat(Movement m);
}
