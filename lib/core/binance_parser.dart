class BinanceTransaction {
  final double amount;
  final String currency;
  final DateTime date;
  final String? transactionType;
  final String? status;
  
  BinanceTransaction({
    required this.amount,
    required this.currency,
    required this.date,
    this.transactionType,
    this.status,
  });
}

class BinanceParser {
  // Patrones para detectar si es una captura de Binance
  static final _binanceIndicators = [
    RegExp(r'binance', caseSensitive: false),
    RegExp(r'crypto', caseSensitive: false),
    RegExp(r'bitcoin|btc', caseSensitive: false),
    RegExp(r'ethereum|eth', caseSensitive: false),
    RegExp(r'wallet', caseSensitive: false),
  ];

  // Patrones para extraer datos específicos
  static final _amountPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(btc|eth|usdt|bnb)', caseSensitive: false);
  static final _datePattern = RegExp(r'(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})', caseSensitive: false);

  /// Verifica si el texto OCR corresponde a una captura de Binance
  static bool isBinanceCapture(String ocrText) {
    final text = ocrText.toLowerCase();
    return _binanceIndicators.any((pattern) => pattern.hasMatch(text));
  }

  /// Extrae los datos de una transacción de Binance del texto OCR
  static BinanceTransaction? parseBinanceTransaction(String ocrText) {
    if (!isBinanceCapture(ocrText)) {
      return null;
    }

    try {
      // Extraer monto y moneda
      final amountMatch = _amountPattern.firstMatch(ocrText);
      final amount = amountMatch != null 
          ? double.parse(amountMatch.group(1)!) 
          : 0.0;
      final currency = amountMatch?.group(2)?.toUpperCase() ?? 'BTC';

      // Extraer fecha
      final dateMatch = _datePattern.firstMatch(ocrText);
      DateTime date = DateTime.now();
      if (dateMatch != null) {
        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        final hour = int.parse(dateMatch.group(4)!);
        final minute = int.parse(dateMatch.group(5)!);
        final second = int.parse(dateMatch.group(6)!);
        date = DateTime(year, month, day, hour, minute, second);
      }

      return BinanceTransaction(
        amount: amount,
        currency: currency,
        date: date,
        transactionType: 'Crypto',
        status: 'Completed',
      );
    } catch (e) {
      print('Error parsing Binance transaction: $e');
      return null;
    }
  }

  /// Convierte una transacción de Binance a formato de gasto
  static ParsedExpense toExpense(BinanceTransaction binanceTransaction) {
    return ParsedExpense(
      amountCents: (binanceTransaction.amount * 100).round(),
      currency: binanceTransaction.currency,
      dateEpochMs: binanceTransaction.date.millisecondsSinceEpoch,
      vendor: 'Binance',
      notes: 'Crypto - ${binanceTransaction.transactionType}',
      sourceApp: 'Binance',
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
