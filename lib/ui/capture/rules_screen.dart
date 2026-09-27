import 'package:flutter/material.dart';

import '../../features/capture/capture_rules.dart';
import '../../features/ledger/ledger.dart';
import '../../theme/design_tokens.dart';
import '../kit.dart';
import '../widgets.dart';

/// Reglas de captura: "Si llega de Yape con “Yapeaste”" → type, account and
/// category, each changed by tapping its chip.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key, required this.store, required this.accounts});

  final CaptureRuleStore store;

  /// Names the account chip cycles through.
  final List<String> accounts;

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _RulesScreenState extends State<RulesScreen> {
  late final Stream<List<CaptureRule>> _rules = widget.store.watch();

  static const _categories = [
    CaptureRule.automatic,
    'Comida',
    'Mercado',
    'Transporte',
    'Extra',
    'Otros',
  ];

  static T _next<T>(List<T> list, T value) =>
      list[(list.indexOf(value) + 1) % list.length];

  @override
  Widget build(BuildContext context) => StreamBuilder<List<CaptureRule>>(
    stream: _rules,
    builder: (context, snapshot) {
      final rules = snapshot.data ?? const <CaptureRule>[];
      final active = rules.where((r) => r.enabled).length;
      return SubPage(
        title: 'Reglas de captura',
        trailing: '$active ${active == 1 ? 'activa' : 'activas'}',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Toca tipo, cuenta o categoría para cambiarlos.',
              style: DesignText.body14.copyWith(
                color: DesignColors.ink2,
                height: 1.45,
              ),
            ),
          ),
          for (final rule in rules) ...[
            _RuleCard(
              rule: rule,
              onToggle: () =>
                  widget.store.update(rule.copyWith(enabled: !rule.enabled)),
              onType: () => widget.store.update(
                rule.copyWith(
                  type: rule.type == MovementType.expense
                      ? MovementType.income
                      : MovementType.expense,
                ),
              ),
              onAccount: widget.accounts.isEmpty
                  ? null
                  : () => widget.store.update(
                      rule.copyWith(
                        account: widget.accounts.contains(rule.account)
                            ? _next(widget.accounts, rule.account)
                            : widget.accounts.first,
                      ),
                    ),
              onCategory: () => widget.store.update(
                rule.copyWith(
                  category: _categories.contains(rule.category)
                      ? _next(_categories, rule.category)
                      : _categories.first,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    },
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.onToggle,
    required this.onType,
    required this.onAccount,
    required this.onCategory,
  });

  final CaptureRule rule;
  final VoidCallback onToggle;
  final VoidCallback onType;
  final VoidCallback? onAccount;
  final VoidCallback onCategory;

  @override
  Widget build(BuildContext context) {
    final auto = rule.category == CaptureRule.automatic;
    final income = rule.type == MovementType.income;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: rule.enabled ? 1 : .55,
      child: PaperCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Si llega de ${rule.from} con',
                        style: DesignText.small.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                      Text(rule.matchLabel, style: DesignText.button),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DsToggle(value: rule.enabled, onTap: onToggle),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _RuleChip(
                  label: income ? 'Ingreso' : 'Gasto',
                  color: income ? DesignColors.green : DesignColors.ink,
                  onTap: onType,
                ),
                _RuleChip(
                  icon: DesignIcons.accountBalanceWallet,
                  label: rule.account,
                  onTap: onAccount,
                ),
                _RuleChip(
                  icon: auto
                      ? DesignIcons.autoAwesome
                      : CategoryStyle.forName(rule.category).icon,
                  label: auto ? 'Automática (IA)' : rule.category,
                  onTap: onCategory,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  const _RuleChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.color = DesignColors.ink,
  });

  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: DesignColors.tile,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Sym(icon!, size: 16, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style:
                  (icon == null
                          ? DesignText.label13Bold
                          : DesignText.label13Semi)
                      .copyWith(color: color),
            ),
          ],
        ),
      ),
    ),
  );
}
