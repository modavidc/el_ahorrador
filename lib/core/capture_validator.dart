enum CaptureType {
  yape,
  binance,
  banco,
  invalid,
  unknown
}

class CaptureValidator {
  // Patrones para detectar Yape
  static final _yapePatterns = [
    RegExp(r'yape', caseSensitive: false),
    RegExp(r'¡yapeaste!', caseSensitive: false),
    RegExp(r'código de seguridad', caseSensitive: false),
    RegExp(r'datos de la transacción', caseSensitive: false),
  ];

  // Patrones para detectar Binance
  static final _binancePatterns = [
    RegExp(r'binance', caseSensitive: false),
    RegExp(r'crypto', caseSensitive: false),
    RegExp(r'bitcoin|btc', caseSensitive: false),
    RegExp(r'ethereum|eth', caseSensitive: false),
    RegExp(r'wallet', caseSensitive: false),
  ];

  // Patrones para detectar Banco
  static final _bancoPatterns = [
    RegExp(r'bcp|bbva|scotiabank|interbank', caseSensitive: false),
    RegExp(r'transferencia', caseSensitive: false),
    RegExp(r'depósito', caseSensitive: false),
    RegExp(r'retiro', caseSensitive: false),
    RegExp(r'comprobante', caseSensitive: false),
    RegExp(r'operación bancaria', caseSensitive: false),
  ];

  // Patrones para detectar contenido inapropiado
  static final _inappropriatePatterns = [
    RegExp(r'pene|penis|dick|cock', caseSensitive: false),
    RegExp(r'porn|xxx|adult', caseSensitive: false),
    RegExp(r'sex|sexual', caseSensitive: false),
    RegExp(r'nude|desnudo', caseSensitive: false),
  ];

  /// Valida el tipo de captura basado en el texto OCR
  static CaptureType validateCapture(String ocrText) {
    final text = ocrText.toLowerCase();
    
    // Primero verificar si es contenido inapropiado
    if (_inappropriatePatterns.any((pattern) => pattern.hasMatch(text))) {
      return CaptureType.invalid;
    }

    // Verificar si es Yape
    if (_yapePatterns.any((pattern) => pattern.hasMatch(text))) {
      return CaptureType.yape;
    }

    // Verificar si es Binance
    if (_binancePatterns.any((pattern) => pattern.hasMatch(text))) {
      return CaptureType.binance;
    }

    // Verificar si es Banco
    if (_bancoPatterns.any((pattern) => pattern.hasMatch(text))) {
      return CaptureType.banco;
    }

    // Si no coincide con ningún patrón conocido
    return CaptureType.unknown;
  }

  /// Obtiene un mensaje descriptivo para el tipo de captura
  static String getValidationMessage(CaptureType type) {
    switch (type) {
      case CaptureType.yape:
        return '¡Captura de Yape detectada! Procesando transacción...';
      case CaptureType.binance:
        return '¡Captura de Binance detectada! Procesando transacción...';
      case CaptureType.banco:
        return '¡Captura bancaria detectada! Procesando transacción...';
      case CaptureType.invalid:
        return '❌ Esta imagen no es válida para el procesamiento de gastos.';
      case CaptureType.unknown:
        return '⚠️ No se pudo identificar el tipo de captura. Intenta con una captura de Yape, Binance o banco.';
    }
  }

  /// Verifica si la captura es procesable
  static bool isProcessable(CaptureType type) {
    return type == CaptureType.yape || 
           type == CaptureType.binance || 
           type == CaptureType.banco;
  }
}
