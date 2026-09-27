import 'dart:convert';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';

/// [ConversationRepository] as JSON in `app_settings`; keeps the last 30.
class DriftConversationRepository implements ConversationRepository {
  DriftConversationRepository(this._db);

  final AppDatabase _db;

  static const _key = 'coach_conversations';
  static const _limit = 30;

  @override
  Stream<List<Conversation>> watch() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(_key)))
          .watchSingleOrNull()
          .map((row) => _decode(row?.value));

  @override
  Future<void> save(Conversation conversation) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(_key))).getSingleOrNull();
    final all = [
      conversation,
      for (final c in _decode(row?.value))
        if (c.id != conversation.id) c,
    ].take(_limit);
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _key,
            value: jsonEncode([for (final c in all) _encode(c)]),
          ),
        );
  }

  static Map<String, Object> _encode(Conversation c) => {
    'id': c.id,
    'at': c.startedAt.millisecondsSinceEpoch,
    'messages': [
      for (final m in c.messages) {'user': m.fromUser, 'text': m.text},
    ],
  };

  static List<Conversation> _decode(String? json) {
    if (json == null) return const [];
    try {
      return [
        for (final j in jsonDecode(json) as List)
          Conversation(
            id: j['id'] as String,
            startedAt: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
            messages: [
              for (final m in j['messages'] as List)
                ChatMessage(
                  fromUser: m['user'] as bool,
                  text: m['text'] as String,
                ),
            ],
          ),
      ];
    } on Object {
      return const [];
    }
  }
}
