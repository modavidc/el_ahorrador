import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/entry_interpreter.dart';

void main() {
  const letters = CategoryLetters.defaults;

  group('CategoryLetters', () {
    test('"C 15" is S/ 15 in Comida, with an optional note', () {
      final e = letters.parse('C 15')!;
      expect(e.category, Category.comida);
      expect(e.amountCents, 1500);
      expect(e.note, isNull);

      final t = letters.parse('t12,50 pasaje bus')!;
      expect(t.category, Category.transporte);
      expect(t.amountCents, 1250);
      expect(t.note, 'pasaje bus');
    });

    test('a letter without a category or amount is not an entry', () {
      expect(letters.parse('Z 15'), isNull);
      expect(letters.parse('C'), isNull);
      expect(letters.parse('C 0'), isNull);
      expect(letters.parse('almuerzo 15'), isNull);
    });

    test('a Yape message that starts with a lone letter', () {
      expect(letters.fromMessage('C'), Category.comida);
      expect(letters.fromMessage(' t '), Category.transporte);
      expect(letters.fromMessage('T pasaje bus'), Category.transporte);
      expect(letters.fromMessage('M - bodega'), Category.mercado);
      expect(letters.fromMessage('Carla evento'), isNull);
      expect(letters.fromMessage('a mi mamá'), isNull);
      expect(letters.fromMessage('S/ 20'), isNull);
      expect(letters.fromMessage(null), isNull);
    });

    test('a letter belongs to one category', () {
      final moved = letters.assign(Category.casa, 'C');
      expect(moved['C'], Category.casa);
      expect(moved.letterOf(Category.comida), isNull);
      expect(moved.letterOf(Category.casa), 'C');

      final cleared = letters.assign(Category.comida, null);
      expect(cleared['C'], isNull);
      expect(cleared.letterOf(Category.mercado), 'M');
    });

    test('survives being stored', () {
      final custom = letters.assign(Category.otros, 'x');
      final back = CategoryLetters.decode(custom.encode());
      expect(back.byLetter, custom.byLetter);
      expect(back['x'], Category.otros);
      expect(CategoryLetters.decode(null).byLetter, letters.byLetter);
      expect(CategoryLetters.decode('').byLetter, isEmpty);
    });
  });

  test('Dictar and writing understand "C 15"', () {
    const accounts = [
      LedgerAccount(
        id: 'y',
        name: 'Yape',
        groupId: 'g',
        groupName: 'Cuentas',
        isLiability: false,
        balanceCents: 0,
        order: 0,
      ),
    ];
    final e = interpretEntry(
      'c 15 menú del día',
      accounts: accounts,
      letters: letters,
    );
    expect(e.type, MovementType.expense);
    expect(e.category, Category.comida);
    expect(e.amount, '15');
    expect(e.note, 'Menú del día');
    expect(e.account, 'Yape');

    // Without letters, the same words go by keywords.
    expect(interpretEntry('c 15', accounts: accounts).category, Category.otros);
  });

  test('a known whole word names the category', () {
    expect(keywordCategory('pasaje bus'), Category.transporte);
    expect(keywordCategory('Prueba comida'), Category.comida);
    expect(keywordCategory('Pago Bustamante'), isNull);
    expect(keywordCategory('Moises evento'), isNull);
  });
}
