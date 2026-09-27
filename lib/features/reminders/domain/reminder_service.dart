import 'dart:async';

import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/reminders/domain/reminders.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// Keeps the phone's alarms in line with Recordatorios and decides what each
/// alarm notifies.
class ReminderService {
  ReminderService({
    required LedgerRepository ledger,
    required AppPreferences preferences,
    required ReminderScheduler scheduler,
    required DateTime Function() now,
  }) : _ledger = ledger,
       _preferences = preferences,
       _scheduler = scheduler,
       _now = now;

  final LedgerRepository _ledger;
  final AppPreferences _preferences;
  final ReminderScheduler _scheduler;
  final DateTime Function() _now;

  /// The alarms Recordatorios asks for, as the switches change.
  Stream<ReminderPlan> watchPlan() {
    late final StreamController<ReminderPlan> out;
    StreamSubscription<Object>? switches, hour;
    Map<Preference, bool>? prefs;
    String? time;
    ReminderPlan? last;
    void emit() {
      if (prefs == null || time == null) return;
      final plan = ReminderPlan.from(prefs!, time!);
      if (plan != last) out.add(last = plan);
    }

    out = StreamController(
      onListen: () {
        switches = _preferences.watch().listen((v) {
          prefs = v;
          emit();
        });
        hour = _preferences.watchText(TextPreference.reminderTime).listen((v) {
          time = v;
          emit();
        });
      },
      onCancel: () async {
        await switches?.cancel();
        await hour?.cancel();
      },
    );
    return out.stream;
  }

  /// Applies [watchPlan] to the phone for the life of the app.
  Stream<ReminderPlan> keepScheduled() => watchPlan().asyncMap((plan) async {
    await _scheduler.schedule(plan);
    return plan;
  });

  /// Notices of an alarm; once-only ones are remembered.
  Future<List<ReminderNotice>> due(ReminderSlot slot) async {
    final notices = remindersFor(
      slot,
      movements: await _ledger.watchMovements().first,
      budgetCents: await _ledger.watchMonthlyBudget().first,
      prefs: await _preferences.watch().first,
      sent: await _preferences.watchDismissedNotices().first,
      now: _now(),
    );
    for (final n in notices) {
      final key = n.onceKey;
      if (key != null) await _preferences.dismissNotice(key);
    }
    return notices;
  }

  /// Recordatorios → "Probar recordatorio".
  Future<void> test() async => _scheduler.show(
    dailyReminder(await _ledger.watchMovements().first, _now(), force: true)!,
  );
}
