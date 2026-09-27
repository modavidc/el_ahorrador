import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/coach/application/coach_controller.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// Coach (v3): "Lo que veo en setiembre", chat with suggestions, and the
/// history of conversations.
class CoachScreen extends StatefulWidget {
  const CoachScreen({
    super.key,
    required this.controller,
    required this.preferences,
  });

  final CoachController controller;
  final AppPreferences preferences;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final Stream<String> _tone = widget.preferences.watchText(
    TextPreference.coachTone,
  );

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  CoachContext _context(String tone) {
    final data = LedgerScope.of(context);
    return CoachContext(
      movements: data.movements,
      budgetCents: data.monthlyBudgetCents,
      today: AppClock.now(),
      tone: CoachTone.fromLabel(tone),
    );
  }

  Future<void> _ask(String question, String tone) async {
    _input.clear();
    final asking = widget.controller.ask(question, _context(tone));
    _toBottom();
    await asking;
    _toBottom();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  });

  void _openHistory() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ConversationsScreen(
        controller: widget.controller,
        onOpen: (c) {
          widget.controller.open(c);
          Navigator.of(context).pop();
        },
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<String>(
    stream: _tone,
    builder: (context, toneSnapshot) {
      final tone = toneSnapshot.data ?? TextPreference.coachTone.defaultValue;
      final coach = _context(tone);
      return ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final c = widget.controller;
          return Stack(
            children: [
              ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Coach', style: DesignText.tabTitle),
                        ),
                        IconAction(
                          icon: DesignIcons.history,
                          label: 'Historial',
                          onTap: _openHistory,
                        ),
                        IconAction(
                          icon: DesignIcons.editSquare,
                          label: 'Nueva conversación',
                          onTap: c.reset,
                        ),
                      ],
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -6),
                    child: Text(
                      'Tono ${tone.toLowerCase()} · analizó '
                      '${coach.month.movements.length} movimientos',
                      style: DesignText.label13.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ),
                  if (c.isEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Lo que veo en ${coach.monthName}',
                      style: DesignText.style(
                        22,
                        FontWeight.w800,
                        letterSpacing: -.02,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final insight in insightsFor(coach)) ...[
                      _InsightCard(insight: insight),
                      const SizedBox(height: 10),
                    ],
                  ],
                  const SizedBox(height: 6),
                  for (final m in c.messages) ...[
                    _Bubble(message: m),
                    const SizedBox(height: 8),
                  ],
                  if (c.thinking)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: DesignColors.card,
                          borderRadius: BorderRadius.circular(DesignRadius.cta),
                        ),
                        child: Text(
                          'Pensando…',
                          style: DesignText.body14.copyWith(
                            color: DesignColors.ink2,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final q in suggestionsFor(coach))
                        _SuggestionChip(label: q, onTap: () => _ask(q, tone)),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: _InputBar(
                  controller: _input,
                  onSend: () => _ask(_input.text, tone),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final (icon, background, color) = switch (insight.kind) {
      InsightKind.topCategory => (
        DesignIcons.trendingUp,
        DesignColors.blush,
        DesignColors.red,
      ),
      InsightKind.capture => (
        DesignIcons.autoAwesome,
        DesignColors.greenSoft,
        DesignColors.green,
      ),
      InsightKind.monthClose => (
        DesignIcons.event,
        DesignColors.amberSoft,
        DesignColors.amber,
      ),
    };
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(
            icon: icon,
            color: color,
            background: background,
            size: 36,
            iconSize: 20,
            radius: DesignRadius.md,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: DesignText.rowAmount),
                const SizedBox(height: 2),
                Text(
                  insight.body,
                  style: DesignText.body14.copyWith(
                    color: DesignColors.ink2,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.fromUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: user ? .8 : .88,
        alignment: user ? Alignment.centerRight : Alignment.centerLeft,
        child: Align(
          alignment: user ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: user
                ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                : const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: user ? DesignColors.ink : DesignColors.card,
              borderRadius: user
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    )
                  : const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
              boxShadow: user ? null : DesignShadows.card,
            ),
            child: Text(
              message.text,
              style: user
                  ? DesignText.body14.copyWith(
                      color: DesignColors.card,
                      height: 1.4,
                    )
                  : DesignText.input.copyWith(height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignRadius.pill),
          border: Border.all(color: DesignColors.lineStrong, width: 1.5),
        ),
        child: Text(label, style: DesignText.body14Semi),
      ),
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: DesignColors.card,
      borderRadius: BorderRadius.circular(DesignRadius.card),
      boxShadow: DesignShadows.floating,
    ),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            onSubmitted: (_) => onSend(),
            textInputAction: TextInputAction.send,
            style: DesignText.input,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
              hintText: 'Pregúntale a tu coach',
              hintStyle: DesignText.input.copyWith(color: DesignColors.ink2),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: 'Enviar',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DesignColors.red,
                borderRadius: BorderRadius.circular(DesignRadius.lg),
              ),
              child: const Center(
                child: Sym(
                  DesignIcons.arrowUpward,
                  size: 22,
                  color: DesignColors.card,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Conversaciones: search and past conversations by week and month.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({
    super.key,
    required this.controller,
    required this.onOpen,
  });

  final CoachController controller;
  final ValueChanged<Conversation> onOpen;

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late final Stream<List<Conversation>> _history = widget.controller
      .watchHistory();
  String _query = '';

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Conversation>>(
    stream: _history,
    builder: (context, snapshot) {
      final today = AppClock.now();
      final weekStart = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: today.weekday - 1));
      final q = _query.toLowerCase();
      final all = [
        for (final c in snapshot.data ?? const <Conversation>[])
          if ('${c.title} ${c.preview}'.toLowerCase().contains(q)) c,
      ];
      final groups = <String, List<Conversation>>{};
      for (final c in all) {
        final title = c.startedAt.isAfter(weekStart)
            ? 'Esta semana'
            : Fmt.monthTitle(c.startedAt.month);
        groups.putIfAbsent(title, () => []).add(c);
      }
      return SubPage(
        title: 'Conversaciones',
        children: [
          SearchBox(
            hint: 'Buscar en conversaciones',
            onChanged: (v) => setState(() => _query = v),
          ),
          if (snapshot.hasData && all.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  const IconTile(
                    icon: DesignIcons.forum,
                    color: DesignColors.red,
                    background: DesignColors.blush,
                    size: 56,
                    iconSize: 28,
                    radius: 18,
                  ),
                  const SizedBox(height: 12),
                  Text('Sin conversaciones', style: DesignText.sheetTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Pregúntale algo a tu coach y aparecerá aquí.',
                    textAlign: TextAlign.center,
                    style: DesignText.body14.copyWith(color: DesignColors.ink2),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: SheetButton.ink(
                      label: 'Hacer una pregunta',
                      height: 48,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          for (final MapEntry(key: title, value: items) in groups.entries) ...[
            SectionHeader(title: title),
            PaperCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (final (i, c) in items.indexed)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onOpen(c),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: i == 0
                              ? null
                              : const Border(
                                  top: BorderSide(color: DesignColors.lineSoft),
                                ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.title, style: DesignText.rowAmount),
                            const SizedBox(height: 2),
                            Text(
                              c.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesignText.label13.copyWith(
                                color: DesignColors.ink2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}
