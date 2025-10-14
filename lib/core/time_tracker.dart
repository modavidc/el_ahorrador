class TimeTracker {
  static DateTime? _shareStartTime;
  static DateTime? _processingStartTime;
  static DateTime? _processingEndTime;

  /// Inicia el tracking cuando se recibe el compartir
  static void startShareTracking() {
    _shareStartTime = DateTime.now();
  }

  /// Marca el inicio del procesamiento (OCR, parsing, etc.)
  static void startProcessing() {
    _processingStartTime = DateTime.now();
  }

  /// Marca el final del procesamiento
  static void endProcessing() {
    _processingEndTime = DateTime.now();
  }

  /// Obtiene el tiempo total de procesamiento
  static Duration? getTotalProcessingTime() {
    if (_shareStartTime == null || _processingEndTime == null) {
      return null;
    }
    return _processingEndTime!.difference(_shareStartTime!);
  }

  /// Obtiene el tiempo de procesamiento (sin incluir el tiempo de recepción)
  static Duration? getProcessingTime() {
    if (_processingStartTime == null || _processingEndTime == null) {
      return null;
    }
    return _processingEndTime!.difference(_processingStartTime!);
  }

  /// Calcula el tiempo que se habría tardado en registro manual
  static Duration getManualRegistrationTime() {
    // Estimación basada en estudios de UX:
    // - Abrir app: 5-10 segundos
    // - Navegar a "Agregar gasto": 5-10 segundos
    // - Llenar formulario: 30-60 segundos
    // - Verificar datos: 10-15 segundos
    // - Guardar: 5 segundos
    // Total: 55-100 segundos (promedio: ~75 segundos)
    return const Duration(seconds: 75);
  }

  /// Calcula el tiempo que se habría tardado en registro tardío (2-3 días después)
  static Duration getDelayedRegistrationTime() {
    // Estimación para registro tardío:
    // - Recordar el gasto: 30-60 segundos
    // - Buscar en conversaciones/notas: 60-120 segundos
    // - Intentar recordar detalles: 30-60 segundos
    // - Abrir app: 5-10 segundos
    // - Navegar y llenar formulario: 60-90 segundos
    // - Verificar datos: 15-30 segundos
    // - Guardar: 5 segundos
    // Total: 205-375 segundos (promedio: ~290 segundos)
    return const Duration(seconds: 290);
  }

  /// Calcula el tiempo ahorrado vs registro manual
  static Duration? getTimeSavedVsManual() {
    final totalTime = getTotalProcessingTime();
    if (totalTime == null) return null;
    
    final manualTime = getManualRegistrationTime();
    return manualTime - totalTime;
  }

  /// Calcula el tiempo ahorrado vs registro tardío
  static Duration? getTimeSavedVsDelayed() {
    final totalTime = getTotalProcessingTime();
    if (totalTime == null) return null;
    
    final delayedTime = getDelayedRegistrationTime();
    return delayedTime - totalTime;
  }

  /// Formatea la duración en un texto legible
  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    } else if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      if (seconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${seconds}s';
    } else {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      if (minutes == 0) {
        return '${hours}h';
      }
      return '${hours}h ${minutes}m';
    }
  }

  /// Genera un mensaje de tiempo ahorrado
  static String generateTimeSavedMessage() {
    final totalTime = getTotalProcessingTime();
    final manualSaved = getTimeSavedVsManual();
    final delayedSaved = getTimeSavedVsDelayed();
    
    if (totalTime == null || manualSaved == null || delayedSaved == null) {
      return 'Tiempo de procesamiento: N/A';
    }

    final totalTimeStr = formatDuration(totalTime);
    final manualSavedStr = formatDuration(manualSaved);
    final delayedSavedStr = formatDuration(delayedSaved);

    return 'Procesado en $totalTimeStr\n'
           'Ahorraste $manualSavedStr vs registro manual\n'
           'Ahorraste $delayedSavedStr vs registro tardío';
  }

  /// Genera un mensaje corto de tiempo ahorrado
  static String generateShortTimeSavedMessage() {
    final manualSaved = getTimeSavedVsManual();
    final delayedSaved = getTimeSavedVsDelayed();
    
    if (manualSaved == null || delayedSaved == null) {
      return 'Tiempo ahorrado: N/A';
    }

    final manualSavedStr = formatDuration(manualSaved);
    final delayedSavedStr = formatDuration(delayedSaved);

    return 'Ahorraste $manualSavedStr vs manual\n'
           'Ahorraste $delayedSavedStr vs tardío';
  }

  /// Resetea el tracking
  static void reset() {
    _shareStartTime = null;
    _processingStartTime = null;
    _processingEndTime = null;
  }

  /// Obtiene estadísticas completas
  static Map<String, dynamic> getStats() {
    final totalTime = getTotalProcessingTime();
    final processingTime = getProcessingTime();
    final manualSaved = getTimeSavedVsManual();
    final delayedSaved = getTimeSavedVsDelayed();

    return {
      'totalTime': totalTime?.inMilliseconds,
      'processingTime': processingTime?.inMilliseconds,
      'manualRegistrationTime': getManualRegistrationTime().inMilliseconds,
      'delayedRegistrationTime': getDelayedRegistrationTime().inMilliseconds,
      'timeSavedVsManual': manualSaved?.inMilliseconds,
      'timeSavedVsDelayed': delayedSaved?.inMilliseconds,
      'totalTimeFormatted': totalTime != null ? formatDuration(totalTime) : null,
      'processingTimeFormatted': processingTime != null ? formatDuration(processingTime) : null,
      'manualSavedFormatted': manualSaved != null ? formatDuration(manualSaved) : null,
      'delayedSavedFormatted': delayedSaved != null ? formatDuration(delayedSaved) : null,
    };
  }
}
