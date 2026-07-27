import 'ai_notes_generator.dart';
import 'package:flutter/foundation.dart';

void _debugLog(Object? message) {
  if (kDebugMode) debugPrint(message?.toString());
}

class YapeTransaction {
  final double amount;
  final String recipient;
  final DateTime date;
  final String? securityCode;
  final String? operationNumber;
  final String? phoneNumber;
  final String? destination;
  final String? description; // Agregar campo para la descripción del producto/servicio
  
  YapeTransaction({
    required this.amount,
    required this.recipient,
    required this.date,
    this.securityCode,
    this.operationNumber,
    this.phoneNumber,
    this.destination,
    this.description,
  });
}

class YapeParser {
  // Patrones para detectar si es una captura de Yape
  static final _yapeIndicators = [
    RegExp(r'yape', caseSensitive: false),
    RegExp(r'¡yapeaste!', caseSensitive: false),
    RegExp(r'código de seguridad', caseSensitive: false),
    RegExp(r'datos de la transacción', caseSensitive: false),
    RegExp(r'nro\. de operación', caseSensitive: false),
  ];

  // Patrones para extraer datos específicos
  static final _amountPattern = RegExp(r's/\s*([0-9]+(?:\.[0-9]{2})?)', caseSensitive: false);
  static final _datePattern = RegExp(r'(\d{1,2})\s*(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)\.?\s*(\d{4})', caseSensitive: false);
  static final _timePattern = RegExp(r'(\d{1,2}):(\d{2})\s*(a\.?\s*m\.?|p\.?\s*m\.?)', caseSensitive: false);
  static final _securityCodePattern = RegExp(r'código de seguridad[^\d]*(\d{3})', caseSensitive: false);
  static final _operationNumberPattern = RegExp(r'nro\.?\s*de\s*operación[^\d]*(\d+)', caseSensitive: false);
  static final _phonePattern = RegExp(r'nro\.?\s*de\s*celular[^\d]*(\d{3})\s*(\d{3})\s*(\d{3})', caseSensitive: false);
  
  // Patrones adicionales para el formato específico de la captura
  static final _dateTimePattern = RegExp(r'(\d{1,2})\s*(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)\.?\s*(\d{4})\s*\|\s*(\d{1,2}):(\d{2})\s*(a\.?\s*m\.?|p\.?\s*m\.?)', caseSensitive: false);

  static const _monthNames = {
    'ene': 1, 'feb': 2, 'mar': 3, 'abr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'ago': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dic': 12
  };

  /// Verifica si el texto OCR corresponde a una captura de Yape
  static bool isYapeCapture(String ocrText) {
    final text = ocrText.toLowerCase();
    return _yapeIndicators.any((pattern) => pattern.hasMatch(text));
  }

  /// Extrae los datos de una transacción de Yape del texto OCR
  static YapeTransaction? parseYapeTransaction(String ocrText) {
    _debugLog('Parsing Yape transaction: $ocrText');
    _debugLog('Is Yape capture: ${isYapeCapture(ocrText)}');

    if (!isYapeCapture(ocrText)) {
      return null;
    }

    try {
      // Extraer monto
      final amountMatch = _amountPattern.firstMatch(ocrText);
      final amount = amountMatch != null 
          ? double.parse(amountMatch.group(1)!) 
          : 0.0;

      // Extraer destinatario y descripción
      String recipient = 'Desconocido';
      String? description;
      
      // 🐛 DEBUG: Imprimir líneas del OCR para debug
      _debugLog('🔍 DEBUG OCR LINES:');
      final lines = ocrText.split('\n');
      for (int i = 0; i < lines.length; i++) {
        _debugLog('  Line $i: "${lines[i].trim()}"');
      }
      
      // Buscar patrón específico: nombre después del monto
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (_amountPattern.hasMatch(line)) {
          _debugLog('💰 Found amount in line $i: "$line"');
          // Buscar en las siguientes líneas el nombre y descripción
          for (int j = i + 1; j < lines.length && j < i + 5; j++) {
            final nextLine = lines[j].trim();
            _debugLog('  Checking line $j: "$nextLine"');
            if (nextLine.isNotEmpty && 
                !nextLine.contains('yape') && 
                !nextLine.contains('código') &&
                !nextLine.contains('datos') &&
                !nextLine.contains('nro') &&
                !nextLine.contains('destino') &&
                !nextLine.contains('celular') &&
                !nextLine.contains('operación') &&
                !_dateTimePattern.hasMatch(nextLine)) {
              
              // Si es la primera línea válida, es el destinatario
              if (recipient == 'Desconocido') {
                recipient = nextLine;
                _debugLog('  ✅ Set recipient: "$recipient"');
              } 
              // Si empieza con "F" seguido de espacio, es la descripción (Favor/Producto)
              else if (nextLine.startsWith('F ') && nextLine.length > 3) {
                description = nextLine;
                _debugLog('  ✅ Set description: "$description"');
                break;
              }
              // Si es una línea más larga con productos/comida, es la descripción
              else if (nextLine.length > 10 && 
                       (nextLine.contains('kg') || 
                        nextLine.contains('pollo') || 
                        nextLine.contains('huevos') ||
                        nextLine.contains('carne') ||
                        nextLine.contains('verdura') ||
                        nextLine.contains('fruta') ||
                        nextLine.contains('helado') ||
                        nextLine.contains('café'))) {
                description = nextLine;
                _debugLog('  ✅ Set description: "$description"');
                break;
              }
            }
          }
          break;
        }
      }
      
      _debugLog('🔍 EXTRACTED VALUES:');
      _debugLog('  🏪 recipient: "$recipient"');
      _debugLog('  📝 description: "$description"');

      // Extraer fecha y hora usando el patrón combinado
      DateTime date = DateTime.now();
      final dateTimeMatch = _dateTimePattern.firstMatch(ocrText);
      if (dateTimeMatch != null) {
        final day = int.parse(dateTimeMatch.group(1)!);
        final monthName = dateTimeMatch.group(2)!.toLowerCase();
        final year = int.parse(dateTimeMatch.group(3)!);
        final month = _monthNames[monthName] ?? 1;
        
        var hour = int.parse(dateTimeMatch.group(4)!);
        final minute = int.parse(dateTimeMatch.group(5)!);
        final period = dateTimeMatch.group(6)!.toLowerCase();
        
        if (period.contains('p') && hour != 12) {
          hour += 12;
        } else if (period.contains('a') && hour == 12) {
          hour = 0;
        }
        
        date = DateTime(year, month, day, hour, minute);
      } else {
        // Fallback: extraer fecha y hora por separado
        final dateMatch = _datePattern.firstMatch(ocrText);
        if (dateMatch != null) {
          final day = int.parse(dateMatch.group(1)!);
          final monthName = dateMatch.group(2)!.toLowerCase();
          final year = int.parse(dateMatch.group(3)!);
          final month = _monthNames[monthName] ?? 1;
          date = DateTime(year, month, day);
        }

        final timeMatch = _timePattern.firstMatch(ocrText);
        if (timeMatch != null) {
          var hour = int.parse(timeMatch.group(1)!);
          final minute = int.parse(timeMatch.group(2)!);
          final period = timeMatch.group(3)!.toLowerCase();
          
          if (period.contains('p') && hour != 12) {
            hour += 12;
          } else if (period.contains('a') && hour == 12) {
            hour = 0;
          }
          
          date = DateTime(date.year, date.month, date.day, hour, minute);
        }
      }

      // Extraer código de seguridad
      final securityMatch = _securityCodePattern.firstMatch(ocrText);
      final securityCode = securityMatch?.group(1);

      // Extraer número de operación
      final operationMatch = _operationNumberPattern.firstMatch(ocrText);
      final operationNumber = operationMatch?.group(1);

      // Extraer número de teléfono
      final phoneMatch = _phonePattern.firstMatch(ocrText);
      final phoneNumber = phoneMatch != null 
          ? '${phoneMatch.group(1)} ${phoneMatch.group(2)} ${phoneMatch.group(3)}'
          : null;

      return YapeTransaction(
        amount: amount,
        recipient: recipient,
        date: date,
        securityCode: securityCode,
        operationNumber: operationNumber,
        phoneNumber: phoneNumber,
        destination: 'Yape',
        description: description,
      );
    } catch (e) {
      _debugLog('Error parsing Yape transaction: $e');
      return null;
    }
  }

  /// Convierte una transacción de Yape a formato de gasto
  /// HARDCODEADO: Todo lo que viene de Yape son gastos (dinero saliendo de mi cuenta)
  static Future<ParsedExpense> toExpense(YapeTransaction yapeTransaction, {String? ocrConfidence}) async {
    // HARDCODEADO: Todo lo de Yape son gastos
    // Categorización automática basada en el destinatario
    final category = await _categorizeByRecipient(yapeTransaction.recipient);
    final subcategory = await _getSubcategory(category, yapeTransaction.recipient);
    
    // Usar la descripción real de la captura (Nota) o generar una por defecto
    final description = yapeTransaction.description ?? 'Pago a ${yapeTransaction.recipient}';
    
    // Generar notas con IA
    String notes = AINotesGenerator.generateSmartNote(
      category: category,
      subcategory: subcategory,
      vendor: yapeTransaction.recipient,
      description: description,
      amount: yapeTransaction.amount,
      sourceApp: 'Yape',
    );
    
    // Agregar información de confianza OCR si está disponible
    if (ocrConfidence != null) {
      notes += '\n\n[OCR Confianza: ${ocrConfidence}%]';
    }
    
    // 🐛 DEBUG: Imprimir todos los campos mapeados antes de guardar
    _debugLog('🔍 DEBUG YAPE MAPPING:');
    _debugLog('  📅 date: ${yapeTransaction.date}');
    _debugLog('  💰 amountCents: ${(yapeTransaction.amount * 100).round()}');
    _debugLog('  💱 currency: PEN');
    _debugLog('  🏷️ category: $category');
    _debugLog('  📂 subcategory: $subcategory');
    _debugLog('  🏦 account: BCP Soles');
    _debugLog('  🏪 vendor: ${yapeTransaction.recipient}');
    _debugLog('  📝 description: $description');
    _debugLog('  📄 notes: $notes');
    _debugLog('  📱 sourceApp: Yape');
    _debugLog('  🔍 ocrConfidence: $ocrConfidence');
    _debugLog('  🔴 type: GASTO (rojo)');
    
    return ParsedExpense(
      amountCents: (yapeTransaction.amount * 100).round(),
      currency: 'PEN',
      dateEpochMs: yapeTransaction.date.millisecondsSinceEpoch,
      category: category,
      subcategory: subcategory,
      account: 'BCP Soles', // HARDCODEADO: Cuenta BCP Soles
      vendor: yapeTransaction.recipient,
      description: description,
      notes: notes,
      sourceApp: 'Yape',
      source: null, // Para gastos, source es null
      destination: yapeTransaction.recipient, // Para gastos, destination es el receptor
      origination: 'Yape', // Origen de la transacción
    );
  }

  /// Categoriza automáticamente basado en el destinatario
  static Future<String> _categorizeByRecipient(String recipient) async {
    final recipientLower = recipient.toLowerCase();
    
    // Patrones para categorización automática
    if (recipientLower.contains('taxi') || recipientLower.contains('uber') || recipientLower.contains('didi')) {
      return 'Transporte';
    }
    if (recipientLower.contains('restaurante') || recipientLower.contains('comida') || recipientLower.contains('pizza') || 
        recipientLower.contains('hamburguesa') || recipientLower.contains('verduras') || recipientLower.contains('vegetales') ||
        recipientLower.contains('mercado') || recipientLower.contains('supermercado') || recipientLower.contains('bodega')) {
      return 'Comida';
    }
    if (recipientLower.contains('farmacia') || recipientLower.contains('medicina') || recipientLower.contains('doctor')) {
      return 'Salud';
    }
    if (recipientLower.contains('cine') || recipientLower.contains('pelicula') || recipientLower.contains('entretenimiento')) {
      return 'Entretenimiento';
    }
    if (recipientLower.contains('curso') || recipientLower.contains('libro') || recipientLower.contains('educacion')) {
      return 'Educación';
    }
    if (recipientLower.contains('familia') || recipientLower.contains('mama') || recipientLower.contains('papa')) {
      return 'Familia';
    }
    if (recipientLower.contains('luz') || recipientLower.contains('agua') || recipientLower.contains('internet') || recipientLower.contains('servicio')) {
      return 'Servicios';
    }
    
    // Por defecto, categorizar como "Comida" para transacciones de Yape
    // ya que la mayoría de pagos son por comida/compra de alimentos
    return 'Comida';
  }

  /// Obtiene subcategoría basada en la categoría y destinatario
  static Future<String> _getSubcategory(String category, String recipient) async {
    final recipientLower = recipient.toLowerCase();
    
    switch (category) {
      case 'Transporte':
        if (recipientLower.contains('taxi')) return 'Taxi';
        if (recipientLower.contains('uber') || recipientLower.contains('didi')) return 'Uber/Didi';
        return 'Otros';
      case 'Comida':
        if (recipientLower.contains('restaurante')) return 'Comidas fuera';
        if (recipientLower.contains('pizza')) return 'Comidas fuera';
        if (recipientLower.contains('verduras') || recipientLower.contains('vegetales')) return 'Verduras y túbérculos';
        if (recipientLower.contains('mercado') || recipientLower.contains('supermercado') || recipientLower.contains('bodega')) return 'Supermercado';
        return 'Otros';
      case 'Salud':
        if (recipientLower.contains('farmacia')) return 'Farmacia';
        if (recipientLower.contains('doctor')) return 'Doctor';
        return 'Otros';
      case 'Servicios':
        if (recipientLower.contains('luz')) return 'Luz';
        if (recipientLower.contains('agua')) return 'Agua';
        if (recipientLower.contains('internet')) return 'Internet';
        return 'Otros';
      default:
        return 'Otros';
    }
  }
}

// Importar la clase ParsedExpense del parser existente
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
  final String? sourceApp;
  final String? source;
  final String? destination;
  final String? origination;
  
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
  });
}
