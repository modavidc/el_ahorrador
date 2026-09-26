import 'package:flutter/widgets.dart';

import '../core/app_clock.dart';

/// Month selected in Trans. and Estad.; both screens share it, as in the
/// prototype.
class PeriodController extends ValueNotifier<DateTime> {
  PeriodController() : super(_monthOf(AppClock.now()));

  static DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

  int get year => value.year;
  int get month => value.month;

  void shift(int months) => value = DateTime(value.year, value.month + months);

  void select(int year, int month) => value = DateTime(year, month);
}

class PeriodScope extends InheritedNotifier<PeriodController> {
  const PeriodScope({
    super.key,
    required PeriodController controller,
    required super.child,
  }) : super(notifier: controller);

  static PeriodController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PeriodScope>()!.notifier!;
}
