import 'package:flutter/services.dart';

import 'package:el_ahorrador/features/reminders/domain/reminders.dart';

/// [ReminderScheduler] backed by Android alarms
/// (`android/app/src/main/kotlin/.../reminders`). Each alarm wakes the
/// background engine, which asks [ReminderService.due] what to notify.
///
/// Channel `solito/reminders`:
/// - `schedule({evening, hour, minute, morning})`
/// - `show({id, title, body})`
class AndroidReminderScheduler implements ReminderScheduler {
  const AndroidReminderScheduler({
    MethodChannel channel = const MethodChannel('solito/reminders'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<void> schedule(ReminderPlan plan) => _call('schedule', {
    'evening': plan.evening,
    'hour': plan.hour,
    'minute': plan.minute,
    'morning': plan.morning,
    'morningHour': ReminderPlan.morningHour,
  });

  @override
  Future<void> show(ReminderNotice notice) => _call('show', {
    'id': notice.id,
    'title': notice.title,
    'body': notice.body,
  });

  Future<void> _call(String method, Object arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Background engine or tests: the activity owns the channel.
    }
  }
}

/// Platforms without alarms (tests, desktop).
class NoReminderScheduler implements ReminderScheduler {
  const NoReminderScheduler();

  @override
  Future<void> schedule(ReminderPlan plan) async {}

  @override
  Future<void> show(ReminderNotice notice) async {}
}
