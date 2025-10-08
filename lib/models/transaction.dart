import 'package:flutter/material.dart';

enum TransactionType {
  income,
  expense,
  transfer,
}

enum TransactionCategory {
  // Gastos
  transporte,
  alimentacion,
  compras,
  salud,
  entretenimiento,
  servicios,
  hogar,
  deportes,
  mantenimiento,
  cocina,
  accesorios,
  otro,
  
  // Ingresos
  ingresos,
  modificacionSaldo,
  
  // Transferencias
  transferencia,
}

class Transaction {
  final String id;
  final DateTime date;
  final TransactionType type;
  final String category;
  final String subcategory;
  final String description;
  final String account;
  final double amount;
  final String currency;
  final String? notes;
  final String? vendor;
  final String? source;
  final String? destination;
  final IconData icon;
  final Color color;

  const Transaction({
    required this.id,
    required this.date,
    required this.type,
    required this.category,
    required this.subcategory,
    required this.description,
    required this.account,
    required this.amount,
    required this.currency,
    this.notes,
    this.vendor,
    this.source,
    this.destination,
    required this.icon,
    required this.color,
  });

  // Factory para crear desde datos de la base de datos
  factory Transaction.fromDatabase({
    required String id,
    required DateTime date, // Fecha completa
    required TransactionType type, // Gasto, Ingreso, Transferencia
    required String category, // La categoria de la transaccion
    required String subcategory, // La subcategoria de la transaccion
    required String description, // La descripcion de la transaccion
    required String account, // La cuenta de la transaccion
    required double amount, // El monto de la transaccion
    required String currency, // La moneda de la transaccion
    String? notes, // Las notas de la transaccion
    String? vendor, // El vendor de la transaccion
    String? source, // La fuente de la transaccion
    String? destination, // El destino de la transaccion
    required IconData icon, // El icono de la transaccion
    required Color color, // El color de la transaccion
  }) {
    return Transaction(
      id: id,
      date: date,
      type: type,
      category: category,
      subcategory: subcategory,
      description: description,
      account: account,
      amount: amount,
      currency: currency,
      notes: notes,
      vendor: vendor,
      source: source,
      destination: destination,
      icon: icon,
      color: color,
    );
  }



  String get formattedAmount {
    final symbol = currency == 'USD' ? '\$' : 'S/.';
    return '$symbol ${amount.toStringAsFixed(2)}';
  }

  String get categoryDisplayName {
    switch (category.toLowerCase()) {
      case 'transporte':
        return 'Transporte';
      case 'alimentación':
      case 'alimentacion':
      case 'comida':
        return 'Alimentación';
      case 'compras':
        return 'Compras';
      case 'salud':
        return 'Salud';
      case 'entretenimiento':
        return 'Entretenimiento';
      case 'servicios':
        return 'Servicios';
      case 'hogar':
        return 'Hogar';
      case 'deportes':
        return 'Deportes';
      case 'mantenimiento':
        return 'Mantenimiento';
      case 'cocina':
        return 'Cocina';
      case 'accesorios':
        return 'Accesorios';
      case 'ingresos':
        return 'Ingresos';
      case 'transferencia':
        return 'Transferencia';
      default:
        return 'Otro';
    }
  }
}
