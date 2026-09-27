import 'package:flutter/material.dart';

import '../../core/app_clock.dart';
import '../../features/coach/coach_insights.dart';
import '../../theme/design_tokens.dart';
import '../ledger_scope.dart';
import '../widgets.dart';

/// Coach of the v1 prototype: actionable insights (not statistics) and
/// decision questions.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key, this.onShowBudget, this.onShowCategory});

  final VoidCallback? onShowBudget;
  final ValueChanged<String>? onShowCategory;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _chat = <(bool, String)>[]; // (fromUser, text)
  final _dismissed = <InsightKind>{};

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _ask(CoachAnalysis analysis, String question) {
    if (question.trim().isEmpty) return;
    setState(() {
      _chat
        ..add((true, question.trim()))
        ..add((false, analysis.answer(question)));
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ledger = LedgerScope.of(context);
    final analysis = CoachAnalysis(
      movements: ledger.movements,
      budgets: ledger.budgets,
      today: AppClock.now(),
    );
    final questions = [
      '¿Puedo gastar S/ 300 este finde?',
      '¿Qué suscripciones me sobran?',
      'Plan para ahorrar S/ 500',
      '¿Por qué gasto más que en ${analysis.previousMonthLong}?',
    ];
    final insights = analysis
        .insights()
        .where((i) => !_dismissed.contains(i.kind))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: DesignColors.surfaceCard,
            border: Border(bottom: BorderSide(color: DesignColors.border)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DesignColors.primary,
                  borderRadius: BorderRadius.circular(DesignRadius.tile),
                ),
                child: const Sym(
                  DesignIcons.autoAwesome,
                  size: 20,
                  color: DesignColors.onPrimary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Coach', style: DesignText.headline),
                    Text(
                      'Analizó ${analysis.current.length} movimientos de '
                      '${analysis.monthLong}',
                      style: DesignText.caption.copyWith(
                        color: DesignColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            children: [
              if (insights.isEmpty && _chat.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Text(
                    'Registra movimientos este mes y aquí verás consejos '
                    'para decidir mejor.',
                    textAlign: TextAlign.center,
                    style: DesignText.body.copyWith(
                      color: DesignColors.textTertiary,
                    ),
                  ),
                ),
              for (final (i, insight) in insights.indexed) ...[
                if (i > 0) const SizedBox(height: 10),
                _InsightCard(insight: insight, actions: _actionsFor(insight)),
              ],
              for (final (fromUser, text) in _chat) ...[
                const SizedBox(height: 10),
                _Bubble(fromUser: fromUser, text: text),
              ],
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            color: DesignColors.surfaceCard,
            border: Border(top: BorderSide(color: DesignColors.border)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  itemCount: questions.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DesignSpacing.sm),
                  itemBuilder: (context, i) => _Pill(
                    label: questions[i],
                    onTap: () => _ask(analysis, questions[i]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: DesignColors.inputFill,
                          border: Border.all(color: DesignColors.borderInput),
                          borderRadius: BorderRadius.circular(
                            DesignRadius.pill,
                          ),
                        ),
                        child: TextField(
                          controller: _input,
                          style: DesignText.body,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (q) => _ask(analysis, q),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Pregúntale al Coach...',
                            hintStyle: DesignText.body.copyWith(
                              color: DesignColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignSpacing.sm),
                    Semantics(
                      button: true,
                      label: 'Enviar',
                      child: GestureDetector(
                        onTap: () => _ask(analysis, _input.text),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: DesignColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Sym(
                            DesignIcons.arrowUpward,
                            size: 20,
                            color: DesignColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  (String, VoidCallback, String, VoidCallback) _actionsFor(Insight insight) {
    void dismiss(String message) {
      setState(() => _dismissed.add(insight.kind));
      showDsToast(context, message);
    }

    void open() {
      final category = insight.category;
      if (category != null) widget.onShowCategory?.call(category);
    }

    return switch (insight.kind) {
      InsightKind.pace => (
        'Ver presupuesto',
        () => widget.onShowBudget?.call(),
        'Entendido',
        () => dismiss('Te aviso si el ritmo cambia'),
      ),
      InsightKind.habit => (
        'Poner tope',
        () => showDsToast(context, 'Próximamente'),
        'Ver pedidos',
        open,
      ),
      InsightKind.subscriptions => (
        'Revisar',
        open,
        'Ignorar',
        () => dismiss('No volveré a mostrar esta sugerencia'),
      ),
      InsightKind.unusual => (
        'Fue único',
        () => dismiss('Marcado como gasto único'),
        'Es normal',
        () => dismiss('Anotado, ajusto tu referencia'),
      ),
    };
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.actions});

  final Insight insight;
  final (String, VoidCallback, String, VoidCallback) actions;

  static const _looks = {
    InsightKind.pace: (
      'Ritmo del mes',
      DesignIcons.speed,
      CategoryStyle.servicios,
    ),
    InsightKind.habit: (
      'Hábito detectado',
      DesignIcons.deliveryDining,
      CategoryStyle.comida,
    ),
    InsightKind.subscriptions: (
      'Suscripciones',
      DesignIcons.subscriptions,
      CategoryStyle.suscripciones,
    ),
    InsightKind.unusual: (
      'Gasto inusual',
      DesignIcons.error,
      CategoryStyle.educacion,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final (kicker, icon, colors) = _looks[insight.kind]!;
    final (primary, onPrimary, secondary, onSecondary) = actions;
    return DsCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(DesignRadius.sm),
                ),
                child: Sym(icon, size: 18, color: colors.foreground),
              ),
              const SizedBox(width: DesignSpacing.sm),
              Text(
                kicker.toUpperCase(),
                style: DesignText.microStrong.copyWith(
                  color: colors.foreground,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(insight.title, style: DesignText.headline.copyWith(height: 1.3)),
          const SizedBox(height: DesignSpacing.xs),
          Text(
            insight.body,
            style: DesignText.label.copyWith(
              color: DesignColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: DesignSpacing.md),
          Row(
            children: [
              _Pill(label: primary, onTap: onPrimary, primary: true),
              const SizedBox(width: DesignSpacing.sm),
              _Pill(label: secondary, onTap: onSecondary),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill button: primary (34px, filled) or outlined; chips use the 30px
/// outlined variant.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap, this.primary});

  final String label;
  final VoidCallback onTap;

  /// null → question chip (30px, 12px text).
  final bool? primary;

  @override
  Widget build(BuildContext context) {
    final chip = primary == null;
    final filled = primary ?? false;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: chip ? 30 : 34,
        padding: EdgeInsets.symmetric(horizontal: chip ? 12 : 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? DesignColors.primary : DesignColors.surfaceCard,
          border: filled ? null : Border.all(color: DesignColors.borderInput),
          borderRadius: BorderRadius.circular(DesignRadius.pill),
        ),
        child: Text(
          label,
          style: chip
              ? DesignText.caption.copyWith(color: DesignColors.textSecondary)
              : filled
              ? DesignText.labelMedium.copyWith(color: DesignColors.onPrimary)
              : DesignText.label.copyWith(color: DesignColors.textSecondary),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.fromUser, required this.text});

  final bool fromUser;
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
    child: FractionallySizedBox(
      widthFactor: 0.84,
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Align(
        alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
          decoration: BoxDecoration(
            color: fromUser ? DesignColors.primary : DesignColors.surfaceCard,
            borderRadius: fromUser
                ? const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(4),
                  )
                : const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(16),
                  ),
            boxShadow: DesignShadows.bubble,
          ),
          child: Text(
            text,
            style: DesignText.body.copyWith(
              color: fromUser
                  ? DesignColors.onPrimary
                  : DesignColors.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      ),
    ),
  );
}
