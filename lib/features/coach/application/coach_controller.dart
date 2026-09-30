import 'package:flutter/foundation.dart';

import 'package:el_ahorrador/features/coach/domain/coach.dart';

/// The open conversation: asks the assistant, shows "Pensando…" and keeps
/// every exchange in the history.
class CoachController extends ChangeNotifier {
  CoachController({
    required CoachAssistant assistant,
    required ConversationRepository history,
    required DateTime Function() now,
  }) : _assistant = assistant,
       _history = history,
       _now = now;

  final CoachAssistant _assistant;
  final ConversationRepository _history;
  final DateTime Function() _now;

  Conversation? _conversation;
  bool _thinking = false;

  List<ChatMessage> get messages => _conversation?.messages ?? const [];
  bool get thinking => _thinking;
  bool get isEmpty => messages.isEmpty;

  Stream<List<Conversation>> watchHistory() => _history.watch();

  Future<void> ask(String question, CoachContext context) async {
    final text = question.trim();
    if (text.isEmpty || _thinking) return;
    final current =
        _conversation ??
        Conversation(
          id: _now().microsecondsSinceEpoch.toString(),
          startedAt: _now(),
          messages: const [],
        );
    _conversation = _with(current, ChatMessage(fromUser: true, text: text));
    _thinking = true;
    notifyListeners();

    String reply;
    try {
      reply = await _assistant.reply(text, context);
    } on Object {
      // The on-device answer is always available.
      reply = LocalCoach.answer(text, context);
    }
    _conversation = _with(
      _conversation!,
      ChatMessage(fromUser: false, text: reply),
    );
    _thinking = false;
    notifyListeners();
    await _history.save(_conversation!);
  }

  /// "Nueva conversación".
  void reset() {
    _conversation = null;
    _thinking = false;
    notifyListeners();
  }

  /// Reopens a past conversation.
  void open(Conversation conversation) {
    _conversation = conversation;
    notifyListeners();
  }

  static Conversation _with(Conversation c, ChatMessage m) => Conversation(
    id: c.id,
    startedAt: c.startedAt,
    messages: [...c.messages, m],
  );
}
