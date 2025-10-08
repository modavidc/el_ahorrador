class AINotesGenerator {
  static final Map<String, List<String>> _noteTemplates = {
    'Comida': [
      'Compra de alimentos para la semana',
      'Almuerzo en restaurante local',
      'Snacks para el trabajo',
      'Ingredientes para cocinar',
      'Desayuno rápido',
      'Cena familiar',
      'Productos frescos del mercado',
      'Comida para llevar',
    ],
    'Transporte': [
      'Viaje en taxi al trabajo',
      'Uber para reunión importante',
      'Gasolina para el auto',
      'Pasaje de bus urbano',
      'Estacionamiento en centro comercial',
      'Viaje de emergencia',
      'Transporte público diario',
    ],
    'Servicios': [
      'Pago de servicios básicos',
      'Suscripción mensual',
      'Mantenimiento de servicios',
      'Pago de internet',
      'Servicio de streaming',
      'Software de trabajo',
      'Servicios digitales',
    ],
    'Salud': [
      'Consulta médica de rutina',
      'Medicinas recetadas',
      'Productos de farmacia',
      'Seguro médico',
      'Emergencia médica',
      'Chequeo preventivo',
      'Medicamentos básicos',
    ],
    'Entretenimiento': [
      'Noche de cine',
      'Suscripción de música',
      'Juego nuevo',
      'Actividad deportiva',
      'Evento cultural',
      'Entretenimiento digital',
      'Actividad recreativa',
    ],
    'Educación': [
      'Curso online',
      'Libro de estudio',
      'Material educativo',
      'Clase particular',
      'Recurso de aprendizaje',
      'Herramienta educativa',
      'Capacitación profesional',
    ],
    'Familia': [
      'Regalo familiar',
      'Ayuda económica familiar',
      'Actividad con la familia',
      'Celebración especial',
      'Soporte familiar',
      'Evento familiar',
      'Cuidado familiar',
    ],
    'Otros': [
      'Gasto imprevisto',
      'Compra necesaria',
      'Emergencia personal',
      'Gasto misceláneo',
      'Compra ocasional',
      'Gasto de conveniencia',
      'Compra de última hora',
    ],
  };

  static String generateNote({
    required String category,
    String? subcategory,
    String? vendor,
    String? description,
    double? amount,
  }) {
    // Obtener plantillas para la categoría
    final templates = _noteTemplates[category] ?? _noteTemplates['Otros']!;
    
    // Seleccionar una plantilla aleatoria
    final random = DateTime.now().millisecondsSinceEpoch % templates.length;
    String baseNote = templates[random];
    
    // Personalizar según el contexto
    if (vendor != null && vendor.isNotEmpty) {
      baseNote = '$baseNote en $vendor';
    }
    
    if (subcategory != null && subcategory.isNotEmpty) {
      baseNote = '$baseNote - $subcategory';
    }
    
    // Agregar información del monto si es significativo
    if (amount != null && amount > 50) {
      baseNote = '$baseNote (gasto considerable)';
    }
    
    // Limitar a 10-15 palabras como solicitaste
    final words = baseNote.split(' ');
    if (words.length > 15) {
      return words.take(15).join(' ');
    }
    
    return baseNote;
  }

  static String generateSmartNote({
    required String category,
    String? subcategory,
    String? vendor,
    String? description,
    double? amount,
    String? sourceApp,
  }) {
    // Generar nota estructurada con múltiples opciones
    final noteType = DateTime.now().millisecondsSinceEpoch % 3;
    
    switch (noteType) {
      case 0:
        return _generateStructuredNote(category, subcategory, vendor, amount, sourceApp);
      case 1:
        return _generateBulletNote(category, subcategory, vendor, amount, sourceApp);
      default:
        return _generateSimpleNote(category, subcategory, vendor, amount, sourceApp);
    }
  }

  /// Genera nota con estructura organizada
  static String _generateStructuredNote(String category, String? subcategory, String? vendor, double? amount, String? sourceApp) {
    final lines = <String>[];
    
    // Línea principal
    String mainLine = '• ${_getContextByApp(sourceApp)} - $category';
    if (subcategory != null && subcategory.isNotEmpty && subcategory != 'Otros') {
      mainLine += ' ($subcategory)';
    }
    lines.add(mainLine);
    
    // Línea de detalles
    if (vendor != null && vendor.isNotEmpty) {
      lines.add('  → En $vendor');
    }
    
    // Línea de contexto del monto
    if (amount != null) {
      if (amount > 100) {
        lines.add('  → Gasto considerable');
      } else if (amount < 10) {
        lines.add('  → Gasto menor');
      }
    }
    
    return lines.join('\n');
  }

  /// Genera nota con formato de lista
  static String _generateBulletNote(String category, String? subcategory, String? vendor, double? amount, String? sourceApp) {
    final lines = <String>[];
    
    lines.add('• ${_getContextByApp(sourceApp)}');
    lines.add('• Categoría: $category');
    
    if (subcategory != null && subcategory.isNotEmpty && subcategory != 'Otros') {
      lines.add('• Tipo: $subcategory');
    }
    
    if (vendor != null && vendor.isNotEmpty) {
      lines.add('• Lugar: $vendor');
    }
    
    return lines.join('\n');
  }

  /// Genera nota simple y concisa
  static String _generateSimpleNote(String category, String? subcategory, String? vendor, double? amount, String? sourceApp) {
    String note = _getContextByApp(sourceApp);
    
    if (category.isNotEmpty) {
      note += ' - $category';
    }
    
    if (subcategory != null && subcategory.isNotEmpty && subcategory != 'Otros') {
      note += ' ($subcategory)';
    }
    
    if (vendor != null && vendor.isNotEmpty) {
      note += ' en $vendor';
    }
    
    // Limitar longitud
    final words = note.split(' ');
    if (words.length > 12) {
      return words.take(12).join(' ');
    }
    
    return note;
  }

  /// Obtiene contexto según la app de origen
  static String _getContextByApp(String? sourceApp) {
    switch (sourceApp) {
      case 'Yape':
        return 'Gasto con Yape';
      case 'Binance':
        return 'Transacción crypto';
      case 'Banco':
        return 'Transferencia bancaria';
      default:
        return 'Transacción';
    }
  }
}
