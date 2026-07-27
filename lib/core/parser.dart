import 'capture_validator.dart';
import 'yape_parser.dart';
import 'binance_parser.dart';
import 'banco_parser.dart';

class ParsedExpense {
  final int amountCents;
  final String currency;
  final int dateEpochMs;
  final String? category;
  final String? subcategory;
  final String? account;
  final String? vendor;
  final String? description;
  final String? notes;
  final String? sourceApp; // Yape, Binance, Banco, etc.
  final String? source; // De dónde viene el dinero (para ingresos)
  final String? destination; // A dónde va el dinero (para gastos)
  final String? origination; // Origen de la transacción
  final String? ocrConfidence; // Nivel de confianza del OCR
  
  ParsedExpense({
    required this.amountCents, 
    required this.currency, 
    required this.dateEpochMs, 
    this.category,
    this.subcategory,
    this.account,
    this.vendor,
    this.description,
    this.notes,
    this.sourceApp,
    this.source,
    this.destination,
    this.origination,
    this.ocrConfidence,
  });
}

class Parser {
  // PEN, S/ 10.50, $ 4.20, 12,34 etc.
  static final _money = RegExp(
    r'(S/|PEN|\$|USD)\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})|[0-9]+(?:[.,][0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final _date1 = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})'); // dd/mm/yyyy
  
  static int _toCents(String s) {
    // normaliza "10.50", "10,50"
    final norm = s.replaceAll('.', '').replaceAll(',', '.');
    final v = double.tryParse(norm) ?? 0;
    return (v * 100).round();
  }

  static Future<ParsedExpense> fromOcr(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Primero validar el tipo de captura
    final captureType = CaptureValidator.validateCapture(text);
    
    // Si es Yape, usar el parser especializado
    if (captureType == CaptureType.yape) {
      final yapeTransaction = YapeParser.parseYapeTransaction(text);
      if (yapeTransaction != null) {
        final expense = await YapeParser.toExpense(yapeTransaction, ocrConfidence: ocrConfidence);
        return ParsedExpense(
          amountCents: expense.amountCents,
          currency: expense.currency,
          dateEpochMs: expense.dateEpochMs,
          category: expense.category,
          subcategory: expense.subcategory,
          account: expense.account,
          vendor: expense.vendor,
          description: expense.description,
          notes: expense.notes,
          sourceApp: 'Yape',
          source: expense.source,
          destination: expense.destination,
          origination: expense.origination,
          ocrConfidence: ocrConfidence,
        );
      }
    }
    
    // Si es Binance, usar el parser especializado
    if (captureType == CaptureType.binance) {
      final binanceTransaction = BinanceParser.parseBinanceTransaction(text);
      if (binanceTransaction != null) {
        final expense = BinanceParser.toExpense(binanceTransaction);
        return ParsedExpense(
          amountCents: expense.amountCents,
          currency: expense.currency,
          dateEpochMs: expense.dateEpochMs,
          vendor: expense.vendor,
          notes: expense.notes,
          sourceApp: 'Binance',
        );
      }
    }
    
    // Si es Banco, usar el parser especializado
    if (captureType == CaptureType.banco) {
      final bancoTransaction = BancoParser.parseBancoTransaction(text);
      if (bancoTransaction != null) {
        final expense = BancoParser.toExpense(bancoTransaction);
        return ParsedExpense(
          amountCents: expense.amountCents,
          currency: expense.currency,
          dateEpochMs: expense.dateEpochMs,
          vendor: expense.vendor,
          notes: expense.notes,
          sourceApp: 'Banco',
        );
      }
    }
    
    // Si es inválido o desconocido, retornar un gasto vacío
    if (captureType == CaptureType.invalid || captureType == CaptureType.unknown) {
      return ParsedExpense(
        amountCents: 0,
        currency: 'PEN',
        dateEpochMs: fallbackDateEpoch ?? DateTime.now().millisecondsSinceEpoch,
        vendor: null,
        notes: 'Captura no válida',
        sourceApp: captureType == CaptureType.invalid ? 'Invalid' : 'Unknown',
      );
    }

    // Parser genérico para otros casos
    return _parseGenericTransaction(text, fallbackDateEpoch);
  }

  static ParsedExpense _parseGenericTransaction(String text, int? fallbackDateEpoch) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final currencyMatch = _money.firstMatch(text);
    final int amountCents = currencyMatch != null ? _toCents(currencyMatch.group(2)!) : 0;
    final String currency = currencyMatch != null
        ? (currencyMatch.group(1)!.toUpperCase().contains('USD') || currencyMatch.group(1) == '\$' ? 'USD' : 'PEN')
        : 'PEN';

    int dateMs = fallbackDateEpoch ?? now;
    final dm = _date1.firstMatch(text);
    if (dm != null) {
      final d = int.parse(dm.group(1)!);
      final m = int.parse(dm.group(2)!);
      final y = int.parse(dm.group(3)!);
      final yyyy = (y < 100) ? (2000 + y) : y;
      dateMs = DateTime(yyyy, m, d).millisecondsSinceEpoch;
    }

    // vendor: primera línea "fuerte" (heurística simple)
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    String? vendor;
    if (lines.isNotEmpty) {
      final first = lines.first;
      if (!first.toLowerCase().contains('total') && !first.toLowerCase().contains('factura')) {
        vendor = first;
      }
    }

    return ParsedExpense(
      amountCents: amountCents,
      currency: currency,
      dateEpochMs: dateMs,
      vendor: vendor,
      notes: null,
      sourceApp: 'Generic',
    );
  }

}
