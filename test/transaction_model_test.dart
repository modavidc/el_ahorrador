import 'package:el_ahorrador/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Transaction transaction({
    String category = 'otro',
    String currency = 'PEN',
    double amount = 0,
  }) {
    return Transaction.fromDatabase(
      id: 'tx-1',
      date: DateTime.utc(2026, 7, 25),
      type: TransactionType.expense,
      category: category,
      subcategory: 'General',
      description: 'Compra',
      account: 'Principal',
      amount: amount,
      currency: currency,
      notes: 'nota',
      vendor: 'Comercio',
      source: 'Yape',
      destination: 'Ahorros',
      icon: Icons.shopping_cart,
      color: Colors.blue,
    );
  }

  group('Transaction.fromDatabase', () {
    test('preserves persisted fields without changing financial meaning', () {
      final date = DateTime.utc(2026, 7, 25, 14, 30);
      final value = Transaction.fromDatabase(
        id: 'transfer-42',
        date: date,
        type: TransactionType.transfer,
        category: 'transferencia',
        subcategory: 'Entre cuentas',
        description: 'Movimiento interno',
        account: 'Efectivo',
        amount: 125.5,
        currency: 'USD',
        notes: 'Conciliado',
        vendor: 'Banco',
        source: 'Cuenta corriente',
        destination: 'Ahorros',
        icon: Icons.swap_horiz,
        color: Colors.green,
      );

      expect(value.id, 'transfer-42');
      expect(value.date, date);
      expect(value.type, TransactionType.transfer);
      expect(value.amount, 125.5);
      expect(value.currency, 'USD');
      expect(value.notes, 'Conciliado');
      expect(value.source, 'Cuenta corriente');
      expect(value.destination, 'Ahorros');
    });
  });

  group('transaction presentation contract', () {
    test('formats supported currencies with exactly two decimals', () {
      expect(
        transaction(amount: 12, currency: 'PEN').formattedAmount,
        'S/. 12.00',
      );
      expect(
        transaction(amount: 12.345, currency: 'USD').formattedAmount,
        r'$ 12.35',
      );
      expect(
        transaction(amount: -0.5, currency: 'PEN').formattedAmount,
        'S/. -0.50',
      );
    });

    test('normalizes aliases and case for category labels', () {
      expect(
        transaction(category: 'TRANSPORTE').categoryDisplayName,
        'Transporte',
      );
      expect(
        transaction(category: 'alimentacion').categoryDisplayName,
        'Alimentación',
      );
      expect(
        transaction(category: 'comida').categoryDisplayName,
        'Alimentación',
      );
      expect(
        transaction(category: 'transferencia').categoryDisplayName,
        'Transferencia',
      );
    });

    test('uses a safe label for unknown and empty persisted categories', () {
      expect(
        transaction(category: 'categoria-eliminada').categoryDisplayName,
        'Otro',
      );
      expect(transaction(category: '').categoryDisplayName, 'Otro');
    });
  });
}
