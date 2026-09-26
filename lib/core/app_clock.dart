/// Source of "now" for screens that depend on the current date (current
/// month, today's calendar cell, days left in the month). Tests and visual
/// goldens pin it to a fixed moment.
abstract final class AppClock {
  static DateTime Function() _now = DateTime.now;

  static DateTime now() => _now();

  static void pin(DateTime moment) => _now = () => moment;

  static void reset() => _now = DateTime.now;
}
