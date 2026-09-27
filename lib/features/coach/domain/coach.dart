import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';

/// Everything the Coach knows about the user's money, computed from the
/// ledger. Answers and insights read only these figures, never the screens.
final class CoachContext {
  CoachContext({
    required List<Movement> movements,
    required this.budgetCents,
    required this.today,
    this.tone = CoachTone.amable,
  }) : month = MonthSummary(
         movements: movements,
         budgetCents: budgetCents,
         today: today,
       ),
       previous = MonthSummary(
         movements: movements,
         budgetCents: budgetCents,
         today: today,
         month: DateTime(today.year, today.month - 1),
       );

  final int budgetCents;
  final DateTime today;
  final CoachTone tone;
  final MonthSummary month;
  final MonthSummary previous;

  List<Movement> get expenses => [
    for (final m in month.movements)
      if (m.type == MovementType.expense) m,
  ];

  /// Expenses of this month by category, largest first.
  List<(Category, int)> get byCategory {
    final totals = <Category, int>{};
    for (final m in expenses) {
      totals.update(
        Category.of(m.category),
        (t) => t + m.amountCents,
        ifAbsent: () => m.amountCents,
      );
    }
    return [for (final e in totals.entries) (e.key, e.value)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
  }

  /// Payments registered by sharing or capturing this month.
  int get captured =>
      month.movements.where((m) => m.origin != MovementOrigin.manual).length;

  String get monthName => Fmt.monthsLong[today.month - 1];
  String get previousName => Fmt.monthsLong[(today.month + 10) % 12];
}

enum CoachTone {
  directo('Directo'),
  amable('Amable'),
  motivador('Motivador');

  const CoachTone(this.label);

  final String label;

  static CoachTone fromLabel(String? label) =>
      values.where((t) => t.label == label).firstOrNull ?? amable;
}

enum InsightKind { topCategory, capture, monthClose }

final class Insight {
  const Insight(this.kind, this.title, this.body);

  final InsightKind kind;
  final String title;
  final String body;
}

/// "Lo que veo en setiembre": the three observations of the prototype.
List<Insight> insightsFor(CoachContext c) {
  final m = c.month;
  final top = c.byCategory.firstOrNull;
  final daysLeft = m.daysLeft;
  return [
    if (top != null)
      Insight(
        InsightKind.topCategory,
        '${top.$1.label} es tu mayor gasto',
        '${Fmt.money(top.$2 / 100)} este mes, '
            '${(top.$2 / m.spentCents * 100).round()}% del total.',
      ),
    Insight(
      InsightKind.capture,
      'La captura te ahorra tiempo',
      c.captured == 0
          ? 'Comparte un comprobante de Yape y se registra solo.'
          : '${c.captured} ${c.captured == 1 ? 'pago se registró' : 'pagos se registraron'} '
                'solos este mes.',
    ),
    Insight(
      InsightKind.monthClose,
      'Cierre de mes en $daysLeft ${daysLeft == 1 ? 'día' : 'días'}',
      m.overBudget
          ? 'Ya pasaste el presupuesto por ${Fmt.money(-m.leftCents / 100)}.'
          : 'Con ${Fmt.money(m.perDay)} diarios llegas justo al presupuesto.',
    ),
  ];
}

/// Suggested questions under the chat.
List<String> suggestionsFor(CoachContext c) => [
  '¿Puedo gastar S/ 300 este finde?',
  '¿Me alcanza hasta fin de mes?',
  '¿Cuánto gasté en Comida?',
  'Plan para ahorrar S/ 500',
  '¿Qué suscripciones tengo?',
  '¿Gasto más que en ${c.previousName}?',
];

/// Answers questions about the user's money.
abstract interface class CoachAssistant {
  Future<String> reply(String question, CoachContext context);
}

/// Answers computed on the device from the ledger, as the prototype does.
/// Used when no language model is configured, and as its fallback.
class LocalCoach implements CoachAssistant {
  const LocalCoach();

  @override
  Future<String> reply(String question, CoachContext c) async =>
      answer(question, c);

  static String answer(String question, CoachContext c) {
    final q = question.toLowerCase();
    final m = c.month;
    final left = m.leftCents / 100;
    final days = m.daysLeft;
    final ranked = c.byCategory;
    String money(int cents) => Fmt.money(cents / 100);

    final asked = Category.values.where(
      (cat) => q.contains(cat.label.toLowerCase()),
    );
    if (asked.isNotEmpty) {
      final cat = asked.first;
      final list = [
        for (final e in c.expenses)
          if (Category.of(e.category) == cat) e,
      ]..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      if (list.isEmpty) {
        return 'Este mes no tienes gastos en ${cat.label}.';
      }
      final total = list.fold(0, (t, e) => t + e.amountCents);
      return 'En ${cat.label} llevas ${money(total)} en ${list.length} '
          '${list.length == 1 ? 'movimiento' : 'movimientos'}. El más alto '
          'fue ${list.first.note} (${money(list.first.amountCents)}).';
    }

    final amount = RegExp(r'\d+').firstMatch(q)?.group(0);
    if (q.contains('finde') || q.contains('fin de semana')) {
      final spend = double.parse(amount ?? '300');
      if (left - spend > 0) {
        final after = (left - spend) / (days - 2).clamp(1, 31);
        return 'Puedes, pero ajustado: te quedan ${Fmt.money(left)}. '
            'Después del finde tendrías ${Fmt.money(after)} por día.';
      }
      return 'Mejor no: te quedan ${Fmt.money(left)} para $days días y '
          '${Fmt.money0(spend)} te dejaría en negativo. Un tope sano para el '
          'finde sería ${Fmt.money((left * .5).clamp(0, double.infinity))}.';
    }

    if (q.contains('suscrip')) {
      final subs = [
        for (final e in c.expenses)
          if (RegExp(
            r'netflix|spotify|disney|youtube|prime|hbo|max|internet|icloud|google one',
            caseSensitive: false,
          ).hasMatch(e.note))
            e,
      ];
      if (subs.isEmpty) return 'No encontré suscripciones este mes.';
      return 'Encontré ${subs.length} pagos recurrentes: '
          '${subs.map((e) => '${e.note} ${money(e.amountCents)}').join(', ')}. '
          'Suman ${money(subs.fold(0, (t, e) => t + e.amountCents))} al mes.';
    }

    if (q.contains('ahorr') && ranked.isNotEmpty) {
      final goal = double.parse(amount ?? '500');
      final first = ranked.first;
      final second = ranked.length > 1 ? ranked[1] : null;
      final cut = first.$2 * .2 + (second?.$2 ?? 0) * .15;
      final months = (goal * 100 / cut.clamp(1, double.infinity)).ceil();
      return 'Para juntar ${Fmt.money0(goal)}: baja ${first.$1.label} un 20% '
          '(${money((first.$2 * .2).round())})'
          '${second == null ? '' : ' y ${second.$1.label} un 15% (${money((second.$2 * .15).round())})'}. '
          'Eso suma ${money(cut.round())} por mes; llegarías en $months '
          '${months == 1 ? 'mes' : 'meses'}.';
    }

    if (q.contains('mes pasado') ||
        q.contains(c.previousName) ||
        q.contains('más que')) {
      final before = c.previous.spentCents;
      if (before == 0) {
        return 'No tengo gastos de ${c.previousName} para comparar. Este mes '
            'llevas ${money(m.spentCents)}.';
      }
      final change = (m.spentCents - before) / before * 100;
      return 'Este mes llevas ${money(m.spentCents)} y en ${c.previousName} '
          'gastaste ${money(before)}: ${change.abs().round()}% '
          '${change < 0 ? 'menos' : 'más'}, y aún faltan $days días.'
          '${ranked.isEmpty ? '' : ' Lo que más pesa es ${ranked.first.$1.label} (${money(ranked.first.$2)}).'}';
    }

    if (q.contains('alcanza') || q.contains('fin de mes')) {
      if (left >= 0) {
        return 'Sí: te quedan ${Fmt.money(left)} para $days días, unos '
            '${Fmt.money(m.perDay)} diarios. Tu promedio de ${c.monthName} es '
            '${money((m.spentCents / c.today.day).round())} por día.';
      }
      return 'No: ya pasaste el presupuesto por ${Fmt.money(-left)}.';
    }

    if (ranked.isEmpty) {
      return 'Aún no tienes gastos este mes. Registra o comparte uno y te '
          'cuento cómo vas.';
    }
    return 'Este mes llevas ${money(m.spentCents)} de '
        '${Fmt.money0(c.budgetCents / 100)}. Lo que más pesa es '
        '${ranked.first.$1.label} (${money(ranked.first.$2)})'
        '${ranked.length > 1 ? ', seguido de ${ranked[1].$1.label} (${money(ranked[1].$2)})' : ''}. '
        'Pregúntame por una categoría, por ejemplo “¿cuánto gasté en Comida?”.';
  }
}

/// One message of a conversation.
final class ChatMessage {
  const ChatMessage({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;
}

final class Conversation {
  const Conversation({
    required this.id,
    required this.startedAt,
    required this.messages,
  });

  final String id;
  final DateTime startedAt;
  final List<ChatMessage> messages;

  /// The first question.
  String get title =>
      messages.where((m) => m.fromUser).firstOrNull?.text ?? 'Conversación';

  /// The first answer.
  String get preview =>
      messages.where((m) => !m.fromUser).firstOrNull?.text ?? '';
}

/// Past conversations (Coach → Historial).
abstract interface class ConversationRepository {
  Stream<List<Conversation>> watch();
  Future<void> save(Conversation conversation);
}
