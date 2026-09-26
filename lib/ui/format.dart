/// Formatting exactly as the v1 prototype does it.
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
    'septiembre',
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

  /// "S/. 1,234.50" (sign kept inside the number: "S/. -5.00").
  static String money(double value) => 'S/. ${number(value)}';

  /// Signed total: "-S/. 448.90" or "S/. 1,372.50".
  static String signedMoney(double value) =>
      '${value < 0 ? '-' : ''}S/. ${number(value.abs())}';

  /// Calendar cell amounts: ≥1000 without decimals ("2,482"), otherwise
  /// two decimals ("249.00").
  static String short(double value) => value >= 1000
      ? _group(value.round().toString())
      : value.toStringAsFixed(2);

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
