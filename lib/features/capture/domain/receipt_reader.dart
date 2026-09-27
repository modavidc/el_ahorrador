/// Reads the OCR text of a payment receipt (Yape, Plin, bank apps): whether
/// money went out or came in, the amount, who it was with, when, and the
/// operation number used to spot duplicates.
library;

enum ReceiptDirection { sent, received, unknown }

/// App or bank the receipt comes from, as the capture rules name it.
enum ReceiptSource {
  yape('Yape'),
  plin('Plin'),
  bcp('BCP'),
  bbva('BBVA'),
  interbank('Interbank'),
  scotiabank('Scotiabank'),
  other('Comercio');

  const ReceiptSource(this.label);

  final String label;
}

final class ReceiptReading {
  const ReceiptReading({
    required this.isReceipt,
    required this.direction,
    required this.source,
    required this.at,
    this.amountCents,
    this.counterpart,
    this.operation,
    this.text = '',
  });

  /// False when the image is not a payment receipt at all.
  final bool isReceipt;
  final ReceiptDirection direction;
  final ReceiptSource source;
  final DateTime at;

  /// Null when the amount could not be read.
  final int? amountCents;

  /// Merchant or person on the other side ("Bodega Don Lucho").
  final String? counterpart;
  final String? operation;

  /// Lowercased OCR text, for rules.
  final String text;

  /// Row note as the prototype writes it: "Yapeaste a Bodega Don Lucho",
  /// "Te yapearon · Freelance", "Plin a Carlos Ruiz", "Consumo BCP · Metro".
  String get note {
    final who = counterpart;
    final received = direction == ReceiptDirection.received;
    return switch (source) {
      ReceiptSource.yape when received =>
        who == null ? 'Te yapearon' : 'Te yapearon · $who',
      ReceiptSource.yape => who == null ? 'Yapeaste' : 'Yapeaste a $who',
      ReceiptSource.plin when received =>
        who == null ? 'Te plinearon' : 'Plin de $who',
      ReceiptSource.plin => who == null ? 'Plin' : 'Plin a $who',
      ReceiptSource.other => who ?? 'Pago',
      _ when received =>
        who == null ? 'Transferencia ${source.label}' : 'Transferencia de $who',
      _ =>
        who == null
            ? 'Consumo ${source.label}'
            : 'Consumo ${source.label} · $who',
    };
  }
}

abstract final class ReceiptReader {
  static const _months = {
    'ene': 1,
    'feb': 2,
    'mar': 3,
    'abr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'ago': 8,
    'set': 9,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dic': 12,
  };

  static final _received = RegExp(
    r'te\s*yapearon|te\s*yape[oó]|recibiste|te\s*plinearon|te\s*envi[oó]|te\s*transfiri|abono|dep[oó]sito\s*recibido',
  );
  static final _sent = RegExp(
    r'yapeaste|plineaste|enviaste|pagaste|transferiste|consumo|compra\s*aprobada|pago\s*exitoso|operaci[oó]n\s*exitosa',
  );
  static final _money = RegExp(
    r'(?:s\s*/\.?|pen)\s*([0-9]{1,3}(?:[,\s][0-9]{3})*(?:\.[0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)',
    caseSensitive: false,
  );
  static final _textDate = RegExp(
    r'(\d{1,2})\s*(ene|feb|mar|abr|may|jun|jul|ago|set|sep|oct|nov|dic)[a-z]*\.?\s*(?:de\s*)?(\d{4})'
    r'(?:\s*[|,-]?\s*(\d{1,2}):(\d{2})\s*(a\.?\s*m\.?|p\.?\s*m\.?)?)?',
    caseSensitive: false,
  );
  static final _numericDate = RegExp(
    r'(\d{1,2})/(\d{1,2})/(\d{2,4})(?:\s+(\d{1,2}):(\d{2}))?',
  );
  static final _operation = RegExp(
    r'(?:n(?:ro|°|º)?\.?\s*de\s*operaci[oó]n|c[oó]digo\s*de\s*operaci[oó]n|operaci[oó]n)\D{0,12}(\d{5,})',
    caseSensitive: false,
  );

  /// Notifications name the sender: "Juan Pérez te yapeó S/ 50".
  static final _sender = RegExp(
    r'^([^\n]+?)\s+te\s+(?:yape[oó]|envi[oó]|plin[eo][oó]?|transfiri[oó])',
    caseSensitive: false,
    multiLine: true,
  );

  /// Lines that are labels, never the counterpart.
  static final _label = RegExp(
    r'yape|plin|c[oó]digo|datos|nro|n°|destino|celular|operaci[oó]n|fecha|hora|'
    r'compartir|inicio|monto|s\s*/|total|comprobante|constancia|exitos|'
    r'enviaste|pagaste|recibiste|transferencia|cuenta|tarjeta|^\d',
    caseSensitive: false,
  );

  static ReceiptReading read(String ocrText, {required DateTime now}) {
    final text = ocrText.toLowerCase();
    final source = _source(text);
    final direction = _received.hasMatch(text)
        ? ReceiptDirection.received
        : _sent.hasMatch(text)
        ? ReceiptDirection.sent
        : ReceiptDirection.unknown;
    final lines = [
      for (final l in ocrText.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    // The counterpart follows the amount; without one, it follows the
    // receipt title ("¡Yapeaste!").
    var amountLine = lines.indexWhere(_money.hasMatch);
    if (amountLine < 0) {
      amountLine = lines.indexWhere(
        (l) =>
            _sent.hasMatch(l.toLowerCase()) ||
            _received.hasMatch(l.toLowerCase()),
      );
    }
    final amount = _amount(ocrText);
    final isReceipt =
        source != ReceiptSource.other || direction != ReceiptDirection.unknown;
    return ReceiptReading(
      isReceipt: isReceipt,
      direction: direction,
      source: source,
      at: _date(ocrText, now) ?? now,
      amountCents: amount,
      counterpart:
          _sender.firstMatch(ocrText)?.group(1)?.trim() ??
          _counterpart(lines, amountLine),
      operation: _operation.firstMatch(ocrText)?.group(1),
      text: text,
    );
  }

  static ReceiptSource _source(String text) {
    if (text.contains('yape')) return ReceiptSource.yape;
    if (text.contains('plin')) return ReceiptSource.plin;
    if (text.contains('bbva')) return ReceiptSource.bbva;
    if (text.contains('interbank')) return ReceiptSource.interbank;
    if (text.contains('scotiabank')) return ReceiptSource.scotiabank;
    if (RegExp(r'\bbcp\b').hasMatch(text)) return ReceiptSource.bcp;
    return ReceiptSource.other;
  }

  static int? _amount(String text) {
    for (final m in _money.allMatches(text)) {
      var raw = m.group(1)!.replaceAll(' ', '');
      // "1,234.50" → thousands separator; "12,50" → decimal comma.
      if (RegExp(r',\d{1,2}$').hasMatch(raw) && !raw.contains('.')) {
        raw = raw.replaceAll(',', '.');
      } else {
        raw = raw.replaceAll(',', '');
      }
      final value = double.tryParse(raw);
      if (value != null && value > 0) return (value * 100).round();
    }
    return null;
  }

  static DateTime? _date(String text, DateTime now) {
    final t = _textDate.firstMatch(text);
    if (t != null) {
      final month = _months[t.group(2)!.toLowerCase()];
      if (month != null) {
        return _at(
          int.parse(t.group(3)!),
          month,
          int.parse(t.group(1)!),
          t.group(4),
          t.group(5),
          t.group(6),
        );
      }
    }
    final n = _numericDate.firstMatch(text);
    if (n != null) {
      var year = int.parse(n.group(3)!);
      if (year < 100) year += 2000;
      return _at(
        year,
        int.parse(n.group(2)!),
        int.parse(n.group(1)!),
        n.group(4),
        n.group(5),
        null,
      );
    }
    return null;
  }

  static DateTime? _at(
    int year,
    int month,
    int day,
    String? hour,
    String? minute,
    String? period,
  ) {
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    var h = int.tryParse(hour ?? '') ?? 12;
    final m = int.tryParse(minute ?? '') ?? 0;
    final p = (period ?? '').toLowerCase();
    if (p.startsWith('p') && h != 12) h += 12;
    if (p.startsWith('a') && h == 12) h = 0;
    return DateTime(year, month, day, h, m);
  }

  /// First line after the amount that is not a label, date or number.
  static String? _counterpart(List<String> lines, int amountLine) {
    if (amountLine < 0) return null;
    for (var i = amountLine + 1; i < lines.length && i <= amountLine + 4; i++) {
      final line = lines[i];
      if (_label.hasMatch(line) ||
          _textDate.hasMatch(line) ||
          _numericDate.hasMatch(line) ||
          line.length < 3) {
        continue;
      }
      return line;
    }
    return null;
  }
}
