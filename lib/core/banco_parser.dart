class BancoTransaction {
  final double amount;
  final String currency;
  final DateTime date;
  final String? bankName;
  final String? transactionType;
  final String? accountNumber;
  
  BancoTransaction({
    required this.amount,
    required this.currency,
    required this.date,
    this.bankName,
    this.transactionType,
    this.accountNumber,
  });
}

class BancoParser {
  // Patrones para detectar si es una captura bancaria
  static final _bancoIndicators = [
    RegExp(r'bcp|bbva|scotiabank|interbank', caseSensitive: false),
    RegExp(r'transferencia', caseSensitive: false),
    RegExp(r'depósito', caseSensitive: false),
    RegExp(r'retiro', caseSensitive: false),
    RegExp(r'comprobante', caseSensitive: false),
    RegExp(r'operación bancaria', caseSensitive: false),
  ];

  // Patrones para extraer datos específicos
  static final _amountPattern = RegExp(r's/\s*([0-9]+(?:\.[0-9]{2})?)', caseSensitive: false);
  static final _datePattern = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})', caseSensitive: false);
  static final _bankPattern = RegExp(r'(bcp|bbva|scotiabank|interbank)', caseSensitive: false);

  /// Verifica si el texto OCR corresponde a una captura bancaria
  static bool isBancoCapture(String ocrText) {
    final text = ocrText.toLowerCase();
    return _bancoIndicators.any((pattern) => pattern.hasMatch(text));
  }

  /// Extrae los datos de una transacción bancaria del texto OCR
  static BancoTransaction? parseBancoTransaction(String ocrText) {
    if (!isBancoCapture(ocrText)) {
      return null;
    }

    try {
      // Extraer monto
      final amountMatch = _amountPattern.firstMatch(ocrText);
      final amount = amountMatch != null 
          ? double.parse(amountMatch.group(1)!) 
          : 0.0;

      // Extraer fecha
      final dateMatch = _datePattern.firstMatch(ocrText);
      DateTime date = DateTime.now();
      if (dateMatch != null) {
        final day = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final year = int.parse(dateMatch.group(3)!);
        final fullYear = (year < 100) ? (2000 + year) : year;
        date = DateTime(fullYear, month, day);
      }

      // Extraer banco
      final bankMatch = _bankPattern.firstMatch(ocrText);
      final bankName = bankMatch?.group(1)?.toUpperCase();

      return BancoTransaction(
        amount: amount,
        currency: 'PEN',
        date: date,
        bankName: bankName,
        transactionType: 'Bank Transfer',
        accountNumber: null,
      );
    } catch (e) {
      return null;
    }
  }

  /// Convierte una transacción bancaria a formato de gasto
  static ParsedExpense toExpense(BancoTransaction bancoTransaction) {
    return ParsedExpense(
      amountCents: (bancoTransaction.amount * 100).round(),
      currency: bancoTransaction.currency,
      dateEpochMs: bancoTransaction.date.millisecondsSinceEpoch,
      vendor: bancoTransaction.bankName ?? 'Banco',
      notes: 'Transferencia bancaria - ${bancoTransaction.transactionType}',
      sourceApp: 'Banco',
    );
  }
}

// Importar la clase ParsedExpense del parser existente
class ParsedExpense {
  final int amountCents;
  final String currency;
  final int dateEpochMs;
  final String? vendor;
  final String? notes;
  final String? sourceApp;
  
  ParsedExpense({
    required this.amountCents, 
    required this.currency, 
    required this.dateEpochMs, 
    this.vendor, 
    this.notes,
    this.sourceApp
  });
}
