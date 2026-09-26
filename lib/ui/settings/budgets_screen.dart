import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_database.dart';
import '../../features/ledger/ledger.dart';
import '../../theme/design_tokens.dart';
import '../format.dart';
import '../widgets.dart';

/// Ajustes → Presupuestos: monthly cap per expense category, read by the
/// Presupuesto card of Trans. → Total and by the Coach.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late final _repository = LedgerRepository(widget.db);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignColors.background,
    body: SafeArea(
      child: StreamBuilder<List<Movement>>(
        stream: _repository.watchMovements(),
        builder: (context, movements) => StreamBuilder<Map<String, int>>(
          stream: _repository.watchBudgets(),
          builder: (context, budgets) {
            final caps = budgets.data ?? const <String, int>{};
            final categories = <String>{
              ...caps.keys,
              for (final m in movements.data ?? const <Movement>[])
                if (m.type == MovementType.expense) m.category,
            }.toList()..sort();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  decoration: const BoxDecoration(
                    color: DesignColors.surfaceCard,
                    border: Border(
                      bottom: BorderSide(color: DesignColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => Navigator.of(context).pop(),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Sym(DesignIcons.arrowBack, size: 24),
                        ),
                      ),
                      const SizedBox(width: DesignSpacing.sm),
                      Text('Presupuestos', style: DesignText.sheetTitle),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                        child: Text(
                          'Tope mensual por categoría. Déjalo vacío para no '
                          'controlar una categoría.',
                          style: DesignText.caption.copyWith(
                            color: DesignColors.textTertiary,
                          ),
                        ),
                      ),
                      DsCard(
                        child: Column(
                          children: [
                            for (final (i, name) in categories.indexed)
                              _BudgetField(
                                key: ValueKey(name),
                                category: name,
                                capCents: caps[name],
                                first: i == 0,
                                onSaved: (cents) => cents == null
                                    ? _repository.clearBudget(name)
                                    : _repository.setBudget(name, cents),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _BudgetField extends StatefulWidget {
  const _BudgetField({
    super.key,
    required this.category,
    required this.capCents,
    required this.first,
    required this.onSaved,
  });

  final String category;
  final int? capCents;
  final bool first;
  final Future<void> Function(int? cents) onSaved;

  @override
  State<_BudgetField> createState() => _BudgetFieldState();
}

class _BudgetFieldState extends State<_BudgetField> {
  late final _controller = TextEditingController(
    text: widget.capCents == null ? '' : Fmt.number(widget.capCents! / 100),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final text = _controller.text.replaceAll(',', '').trim();
    final value = double.tryParse(text);
    widget.onSaved(value == null || value <= 0 ? null : (value * 100).round());
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: widget.first
          ? null
          : const Border(top: BorderSide(color: DesignColors.borderSubtle)),
    ),
    child: Row(
      children: [
        CategoryTile(category: widget.category),
        const SizedBox(width: DesignSpacing.md),
        Expanded(child: Text(widget.category, style: DesignText.body)),
        Text(
          'S/.',
          style: DesignText.body.copyWith(color: DesignColors.textTertiary),
        ),
        const SizedBox(width: DesignSpacing.xs),
        SizedBox(
          width: 96,
          child: TextField(
            controller: _controller,
            textAlign: TextAlign.right,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: DesignText.bodyStrong,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: '—',
              hintStyle: DesignText.body.copyWith(
                color: DesignColors.textDisabled,
              ),
            ),
            onSubmitted: (_) => _save(),
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              _save();
            },
          ),
        ),
      ],
    ),
  );
}
