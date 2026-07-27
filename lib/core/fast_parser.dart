import 'capture_validator.dart';
import 'parser.dart';

class FastParser {
  // Parser optimizado para velocidad máxima
  static Future<ParsedExpense> fromOcr(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Detectar tipo de captura de forma más eficiente
    final captureType = CaptureValidator.validateCapture(text);
    
    // Usar switch para mejor rendimiento
    switch (captureType) {
      case CaptureType.yape:
        return _parseYapeFast(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
      case CaptureType.binance:
        return _parseBinanceFast(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
      case CaptureType.banco:
        return _parseBancoFast(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
      default:
        return _parseGenericFast(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
    }
  }
  
  static Future<ParsedExpense> _parseYapeFast(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Parser Yape optimizado - usar parser original por ahora
    return Parser.fromOcr(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
  }
  
  static Future<ParsedExpense> _parseBinanceFast(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Parser Binance optimizado - usar parser original por ahora
    return Parser.fromOcr(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
  }
  
  static Future<ParsedExpense> _parseBancoFast(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Parser Banco optimizado - usar parser original por ahora
    return Parser.fromOcr(text, fallbackDateEpoch: fallbackDateEpoch, ocrConfidence: ocrConfidence);
  }
  
  static Future<ParsedExpense> _parseGenericFast(String text, {int? fallbackDateEpoch, String? ocrConfidence}) async {
    // Parser genérico optimizado
    final money = RegExp(r'(S/|PEN|\$|USD)\s*([0-9]{1,3}(?:[.,][0-9]{3})*(?:[.,][0-9]{1,2})|[0-9]+(?:[.,][0-9]{1,2})?)', caseSensitive: false);
    final date1 = RegExp(r'(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})');
    
    // Buscar monto
    final moneyMatch = money.firstMatch(text);
    if (moneyMatch == null) {
      return ParsedExpense(
        amountCents: 0,
        currency: 'PEN',
        dateEpochMs: fallbackDateEpoch ?? DateTime.now().millisecondsSinceEpoch,
        sourceApp: 'Desconocido',
        ocrConfidence: ocrConfidence,
      );
    }
    
    final currency = moneyMatch.group(1)?.toUpperCase() ?? 'PEN';
    final amountStr = moneyMatch.group(2) ?? '0';
    
    // Convertir a centavos
    final amountCents = _toCents(amountStr);
    
    // Buscar fecha
    final dateMatch = date1.firstMatch(text);
    int dateEpochMs = fallbackDateEpoch ?? DateTime.now().millisecondsSinceEpoch;
    
    if (dateMatch != null) {
      final day = int.tryParse(dateMatch.group(1) ?? '') ?? 1;
      final month = int.tryParse(dateMatch.group(2) ?? '') ?? 1;
      final year = int.tryParse(dateMatch.group(3) ?? '') ?? DateTime.now().year;
      
      // Ajustar año si es de 2 dígitos
      final fullYear = year < 100 ? (year < 50 ? 2000 + year : 1900 + year) : year;
      
      try {
        final date = DateTime(fullYear, month, day);
        dateEpochMs = date.millisecondsSinceEpoch;
      } catch (e) {
        // Usar fecha por defecto si hay error
      }
    }
    
    return ParsedExpense(
      amountCents: amountCents,
      currency: currency,
      dateEpochMs: dateEpochMs,
      sourceApp: 'Desconocido',
      ocrConfidence: ocrConfidence,
    );
  }
  
  static int _toCents(String s) {
    // Normalizar formato de número
    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');
    final separatorIndex = lastDot > lastComma ? lastDot : lastComma;
    final hasBoth = lastDot >= 0 && lastComma >= 0;
    final decimalDigits =
        separatorIndex < 0 ? 0 : s.length - separatorIndex - 1;
    final hasDecimals =
        separatorIndex >= 0 && (hasBoth || decimalDigits <= 2);
    final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
    final norm = hasDecimals
        ? '${digits.substring(0, digits.length - decimalDigits)}.${digits.substring(digits.length - decimalDigits)}'
        : digits;
    final v = double.tryParse(norm) ?? 0;
    return (v * 100).round();
  }
}
