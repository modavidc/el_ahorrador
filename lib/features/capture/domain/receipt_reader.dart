/// Reads the OCR text of a payment receipt (Yape, Plin, bank apps): whether
/// money went out or came in, the amount, who it was with, when, the
/// message written with the payment, and the operation number used to spot
/// duplicates.
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
    this.counterpartPhone,
    this.message,
    this.operation,
    this.via,
    this.text = '',
  });

  /// False when the image is not a payment receipt at all.
  final bool isReceipt;
  final ReceiptDirection direction;
  final ReceiptSource source;
  final DateTime at;

  /// Null when the amount could not be read.
  final int? amountCents;

  /// Merchant or person on the other side ("Bodega Don Lucho"), without
  /// the asterisk Yape puts after a shortened name.
  final String? counterpart;

  /// Last 3 digits of the other side's phone ("*** *** 281" → "281").
  final String? counterpartPhone;

  /// What the payer wrote with the payment ("pasaje bus").
  final String? message;
  final String? operation;

  /// Plin or Yape when a bank app sent the money through them ("Enviado a
  /// … PLIN" from BCP).
  final ReceiptSource? via;

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
      _ when via != null && !received =>
        who == null ? via!.label : '${via!.label} a $who',
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

  /// When the OCR reads the label column first, the number comes a few
  /// lines after its label ("Nro. de operación / *** *** 257 / Yape /
  /// 33947938"). The gap never crosses a phone label, so a phone is not
  /// taken for the operation.
  static final _operationLater = RegExp(
    r'(?:n[uú]mero|n(?:ro|°|º)?\.?)\s*de\s*operaci[oó]n(?:(?!celular)[\s\S]){0,60}?(?<!\d)(\d{5,})',
    caseSensitive: false,
  );

  /// Masked phone of the other side: "*** *** 281".
  static final _maskedPhone = RegExp(r'\*[*\s]*\*\s*(\d{3})(?!\d)');

  /// Unmasked phone after its label: "Celular 987 654 321".
  static final _labeledPhone = RegExp(
    r'celular\D{0,20}?(\d[\d ]{5,}\d)',
    caseSensitive: false,
  );

  /// Peruvian mobile written in full: "938 804 597".
  static final _mobile = RegExp(r'(?<!\d)9\d{2} ?\d{3} ?\d{3}(?!\d)');

  /// "Enviado a:" of bank and Plin receipts, with the name after it or on
  /// the next lines.
  static final _sentTo = RegExp(
    r'^enviado\s+a\s*:?\s*(.*)$',
    caseSensitive: false,
  );

  /// "Mensaje" title of a message box (BCP), with the text on the next
  /// line or after it.
  static final _messageTitle = RegExp(
    r'^mensaje\s*:?\s*(.*)$',
    caseSensitive: false,
  );

  /// Lines that end the message box: the labels under it.
  static final _afterMessage = RegExp(
    r'c[oó]digo\s*de\s*seguridad|datos\s*de\s*la\s*transacci[oó]n|'
    r'n(?:ro|°|º)?\.?\s*de\s*(?:celular|operaci[oó]n)|^destino|^compartir',
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
    final sentTo = _sentToBlock(lines);
    final counterpart = _clean(
      _sender.firstMatch(ocrText)?.group(1)?.trim() ??
          sentTo?.name ??
          _counterpart(lines, amountLine),
    );
    return ReceiptReading(
      isReceipt: isReceipt,
      direction: direction,
      source: source,
      at: _date(ocrText, now) ?? now,
      amountCents: amount,
      counterpart: counterpart,
      counterpartPhone: _phone(ocrText, sentTo),
      message:
          _titledMessage(lines) ??
          (source == ReceiptSource.yape ? _message(lines, counterpart) : null),
      operation:
          _operation.firstMatch(ocrText)?.group(1) ??
          _operationLater.firstMatch(ocrText)?.group(1),
      via: _via(text, source),
      text: text,
    );
  }

  static final _sources = {
    ReceiptSource.yape: RegExp('yape'),
    ReceiptSource.plin: RegExp('plin'),
    ReceiptSource.bbva: RegExp('bbva'),
    ReceiptSource.interbank: RegExp('interbank'),
    ReceiptSource.scotiabank: RegExp('scotiabank'),
    ReceiptSource.bcp: RegExp(r'\bbcp\b'),
  };

  /// The app or bank that issued the receipt: the first one named, which
  /// is its logo. Later names are where the money went ("Enviado a …
  /// PLIN" from BCP, "938 804 597 - BCP" from Interbank).
  static ReceiptSource _source(String text) {
    var best = ReceiptSource.other;
    var at = text.length;
    for (final MapEntry(key: source, value: pattern) in _sources.entries) {
      final i = pattern.firstMatch(text)?.start;
      if (i != null && i < at) {
        best = source;
        at = i;
      }
    }
    return best;
  }

  /// Plin or Yape named after a bank issuer.
  static ReceiptSource? _via(String text, ReceiptSource source) {
    const banks = [
      ReceiptSource.bcp,
      ReceiptSource.bbva,
      ReceiptSource.interbank,
      ReceiptSource.scotiabank,
    ];
    if (!banks.contains(source)) return null;
    if (text.contains('plin')) return ReceiptSource.plin;
    if (text.contains('yape')) return ReceiptSource.yape;
    return null;
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

  /// Date and time written in [text], if any.
  static DateTime? dateIn(String text, DateTime now) => _date(text, now);

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

  /// "Andrez Qui*" → "Andrez Qui".
  static String? _clean(String? name) {
    final n = name?.replaceAll(RegExp(r'[\s*]+$'), '').trim();
    return n == null || n.isEmpty ? null : n;
  }

  static String? _phone(String text, _SentTo? sentTo) {
    final masked = _maskedPhone.firstMatch(text)?.group(1);
    if (masked != null) return masked;
    final mobile = sentTo == null
        ? null
        : _mobile.firstMatch(sentTo.after)?.group(0)?.replaceAll(' ', '');
    if (mobile != null) return mobile.substring(mobile.length - 3);
    final digits = _labeledPhone
        .firstMatch(text)
        ?.group(1)
        ?.replaceAll(' ', '');
    return digits?.substring(digits.length - 3);
  }

  /// "Enviado a MOISES …" or "Enviado a:" followed by the name, which may
  /// wrap to a second line. [_SentTo.after] holds the lines under it,
  /// where Plin writes the phone.
  static _SentTo? _sentToBlock(List<String> lines) {
    final i = lines.indexWhere(_sentTo.hasMatch);
    if (i < 0) return null;
    final parts = [_sentTo.firstMatch(lines[i])!.group(1)!.trim()];
    var next = i + 1;
    bool isName(String l) =>
        RegExp(r'^[\p{L} .]+$', unicode: true).hasMatch(l) &&
        !_label.hasMatch(l) &&
        !RegExp(r'^comisi[oó]n', caseSensitive: false).hasMatch(l);
    // Name on the next lines when the label stands alone; one wrapped line
    // when it continues.
    final maxLines = parts.first.isEmpty ? 2 : 1;
    var taken = 0;
    while (next < lines.length && taken < maxLines && isName(lines[next])) {
      final upperName = lines[next] == lines[next].toUpperCase();
      if (parts.first.isNotEmpty && !upperName) break;
      parts.add(lines[next]);
      next++;
      taken++;
    }
    final name = parts.where((p) => p.isNotEmpty).join(' ');
    return _SentTo(
      name: name.isEmpty ? null : _titleCase(name),
      after: lines.skip(next).take(3).join('\n'),
    );
  }

  /// "MOISES DAVID" → "Moises David"; mixed case stays as written.
  static String _titleCase(String name) => name != name.toUpperCase()
      ? name
      : name
            .toLowerCase()
            .split(' ')
            .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
            .join(' ');

  /// Text under a "Mensaje" title (BCP), or after it on the same line.
  static String? _titledMessage(List<String> lines) {
    final i = lines.indexWhere(_messageTitle.hasMatch);
    if (i < 0) return null;
    final inline = _messageTitle.firstMatch(lines[i])!.group(1)!.trim();
    if (inline.isNotEmpty) return inline;
    return i + 1 < lines.length ? lines[i + 1] : null;
  }

  /// The box under the date: the first line with words after the date and
  /// before the labels under it (código de seguridad, datos de la
  /// transacción). Receipts without a message go straight to those labels.
  static String? _message(List<String> lines, String? counterpart) {
    final dateLine = lines.indexWhere(
      (l) => _textDate.hasMatch(l) || _numericDate.hasMatch(l),
    );
    if (dateLine < 0) return null;
    for (var i = dateLine + 1; i < lines.length; i++) {
      final line = lines[i];
      if (_afterMessage.hasMatch(line)) return null;
      // The OCR may keep the note icon as a stray symbol before the text.
      final text = line.replaceFirst(
        RegExp(r'^[^\p{L}\p{N}]+', unicode: true),
        '',
      );
      // The time can land on its own line: "10:31 p. m.".
      if (text.isEmpty ||
          _clean(text) == counterpart ||
          RegExp(r'^\d{1,2}:\d{2}').hasMatch(text)) {
        continue;
      }
      if (RegExp(r'\p{L}', unicode: true).hasMatch(text)) return text;
    }
    return null;
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

/// Name and the lines under "Enviado a".
final class _SentTo {
  const _SentTo({required this.name, required this.after});

  final String? name;
  final String after;
}
