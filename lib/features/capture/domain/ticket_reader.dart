import 'package:el_ahorrador/features/capture/domain/receipt_reader.dart';

/// Reads the photo of a store ticket or boleta (Escanear boleta): the
/// merchant on top, the TOTAL line and the date. The result is a
/// [ReceiptReading] so capture rules and category guessing apply as to a
/// shared receipt.
abstract final class TicketReader {
  static final _total = RegExp(
    r'(importe\s+total|total\s+a\s+pagar|total\s+venta|\btotal\b)',
    caseSensitive: false,
  );
  static final _notTotal = RegExp(
    r'sub\s*-?\s*total|op\.?\s*gravada|igv|descuento|vuelto|cambio|items?\b',
    caseSensitive: false,
  );
  static final _number = RegExp(
    r'([0-9]{1,3}(?:,[0-9]{3})+\.[0-9]{2}|[0-9]+[.,][0-9]{2})(?![0-9])',
  );
  static final _notMerchant = RegExp(
    r'ruc|boleta|factura|electr[oó]nica|ticket|av\.|jr\.|calle|direcci|telf|'
    r'tel[eé]fono|www\.|@|^\W*$|^[\d\s\-/:.]+$',
    caseSensitive: false,
  );

  static ReceiptReading read(String ocrText, {required DateTime now}) {
    final lines = [
      for (final l in ocrText.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];
    final merchant = lines
        .take(4)
        .where((l) => !_notMerchant.hasMatch(l) && l.length >= 3)
        .firstOrNull;
    final amount = _totalIn(lines);
    return ReceiptReading(
      isReceipt: amount != null,
      direction: ReceiptDirection.sent,
      source: ReceiptSource.other,
      at: ReceiptReader.dateIn(ocrText, now) ?? now,
      amountCents: amount,
      counterpart: merchant == null ? null : _title(merchant),
      text: ocrText.toLowerCase(),
    );
  }

  /// Amount of the last TOTAL line (the one after taxes), or of the line
  /// below it when the figure was read apart.
  static int? _totalIn(List<String> lines) {
    int? found;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!_total.hasMatch(line) || _notTotal.hasMatch(line)) continue;
      final here = _cents(line);
      final next = i + 1 < lines.length ? _cents(lines[i + 1]) : null;
      found = here ?? next ?? found;
    }
    return found;
  }

  static int? _cents(String line) {
    final matches = _number.allMatches(line).toList();
    if (matches.isEmpty) return null;
    var raw = matches.last.group(1)!;
    raw = RegExp(r',\d{2}$').hasMatch(raw) && !raw.contains('.')
        ? raw.replaceAll(',', '.')
        : raw.replaceAll(',', '');
    final value = double.tryParse(raw);
    return value == null || value <= 0 ? null : (value * 100).round();
  }

  /// "PLAZA VEA SAN ISIDRO" → "Plaza Vea San Isidro".
  static String _title(String line) {
    if (line != line.toUpperCase()) return line;
    return line
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }
}
