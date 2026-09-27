import 'package:flutter/services.dart';

import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/reminders/domain/reminders.dart';

/// Runs in the headless engine the Android capture service keeps warm, so a
/// screenshot or a payment notification is registered in 1–2 seconds even
/// with the app closed.
///
/// Channel `el_ahorrador/capture_background`:
/// - `processImage(path)` / `processText({text, source})` → the notification
///   to show: `{status, title, body, movementId}`; no title means silence
///   (duplicates, images that are not receipts).
/// - `undo(movementId)` from the notification's "Deshacer".
/// - `reminders(slot)` from an alarm of Recordatorios → `[{id, title, body}]`.
Future<void> runBackgroundCapture() async {
  final db = AppDatabase();
  final dependencies = AppDependencies(db);
  final service = dependencies.capture.service;
  const channel = MethodChannel('el_ahorrador/capture_background');

  channel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'processImage':
        return notificationFor(
          await service.process(
            call.arguments as String,
            origin: MovementOrigin.screenshot,
          ),
        );
      case 'processText':
        final args = call.arguments as Map;
        return notificationFor(
          await service.processText(
            args['text'] as String,
            sourceLabel: args['source'] as String? ?? 'Aviso',
          ),
        );
      case 'undo':
        await dependencies.ledger.deleteById(call.arguments as String);
        return null;
      case 'reminders':
        final notices = await dependencies.reminders.due(
          ReminderSlot.values.byName(call.arguments as String),
        );
        return [
          for (final n in notices)
            {'id': n.id, 'title': n.title, 'body': n.body},
        ];
    }
    return null;
  });
  await channel.invokeMethod<void>('ready');
}

/// What the "Registrado" notification says; empty for silent outcomes.
Map<String, Object?> notificationFor(CaptureOutcome outcome) {
  final d = outcome.draft;
  String amount() => d?.amountCents == null
      ? ''
      : '${d!.type == MovementType.income ? '+' : ''}'
            '${Fmt.money(d.amountCents! / 100)}';
  return switch (outcome.status) {
    CaptureStatus.registered => {
      'status': 'registered',
      'title': 'Registrado · ${amount()}',
      'body': [d!.note, ?d.category, d.account].join(' · '),
      'movementId': outcome.movementId,
    },
    CaptureStatus.review => {
      'status': 'review',
      'title': 'Falta un dato',
      'body': '${d!.note} · ${d.why ?? 'Revísalo en Por revisar'}',
    },
    _ => {'status': outcome.status.name},
  };
}
