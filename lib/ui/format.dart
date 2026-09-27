/// Formatting exactly as the v3 prototype does it (`capture-core.js`).
abstract final class Fmt {
  static const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  static const monthsLong = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'setiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// Week starts on Sunday: index 0 = Dom.
  static const weekdays = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  /// 0 = Sunday … 6 = Saturday.
  static int weekdayIndex(DateTime date) => date.weekday % 7;

  static String weekday(DateTime date) => weekdays[weekdayIndex(date)];

  /// 1234.5 → "1,234.50"
  static String number(double value) {
    final cents = (value.abs() * 100).round();
    final whole = (cents ~/ 100).toString();
    final decimals = (cents % 100).toString().padLeft(2, '0');
    return '${value < 0 ? '-' : ''}${_group(whole)}.$decimals';
  }

  /// Typographic minus used before amounts ("−S/ 16.00").
  static const minus = '\u2212';

  /// "S/ 1,234.50" (sign kept inside the number: "S/ -5.00").
  static String money(double value) => 'S/ ${number(value)}';

  /// "S/ 1,235": whole soles (`f0`).
  static String money0(double value) =>
      'S/ ${value < 0 ? '-' : ''}${_group(value.abs().round().toString())}';

  /// Signed total: "−S/ 448.90" or "S/ 1,372.50".
  static String signedMoney(double value) =>
      '${value < 0 ? minus : ''}S/ ${number(value.abs())}';

  /// Net with an explicit sign: "+S/ 392.00", "−S/ 25.00".
  static String net(double value) =>
      '${value < 0 ? minus : '+'}S/ ${number(value.abs())}';

  /// Whole-soles net: "+S/ 1,542".
  static String net0(double value) =>
      '${value < 0 ? minus : '+'}${money0(value.abs())}';

  /// Calendar cell amounts: ≥1000 as thousands ("3.2k"), otherwise two
  /// decimals ("146.30").
  static String short(double value) => value >= 1000
      ? '${(value / 1000).toStringAsFixed(1)}k'
      : value.toStringAsFixed(2);

  /// "Setiembre"
  static String monthTitle(int month) {
    final name = monthsLong[month - 1];
    return name[0].toUpperCase() + name.substring(1);
  }

  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  /// "19:43"
  static String time(DateTime at) =>
      '${twoDigits(at.hour)}:${twoDigits(at.minute)}';

  static String _group(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
