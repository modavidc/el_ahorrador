import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/onboarding/presentation/share_demo.dart';

/// What the user chose in the welcome.
final class OnboardingResult {
  const OnboardingResult({this.budgetCents, this.activateCapture = false});

  /// Monthly budget confirmed on step 2; null when it was skipped.
  final int? budgetCents;

  /// "Activar captura y empezar" on the last step.
  final bool activateCapture;
}

/// Welcome in 3 steps (design §1): Bienvenida, Presupuesto and the capture
/// demo. The budget typed on step 2 becomes the real monthly budget.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.initialBudgetCents,
    required this.onFinish,
    this.animateDemo = true,
  });

  final int initialBudgetCents;
  final ValueChanged<OnboardingResult> onFinish;

  /// Off in tests: the demo loops forever.
  final bool animateDemo;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _presets = [180000, 240000, 300000];

  var _step = 0;
  int? _confirmedBudget;
  late final _budget = TextEditingController(
    text: (widget.initialBudgetCents ~/ 100).toString(),
  );

  int? get _typedBudget {
    final cents = Fmt.parseCents(_budget.text);
    return cents == null || cents <= 0 ? null : cents;
  }

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 1) {
      final cents = _typedBudget;
      if (cents == null) return;
      _confirmedBudget = cents;
    }
    if (_step < 2) {
      FocusScope.of(context).unfocus();
      setState(() => _step++);
      return;
    }
    widget.onFinish(
      OnboardingResult(budgetCents: _confirmedBudget, activateCapture: true),
    );
  }

  void _skip() =>
      widget.onFinish(OnboardingResult(budgetCents: _confirmedBudget));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignColors.paper,
    resizeToAvoidBottomInset: false,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _step
                            ? DesignColors.red
                            : DesignColors.lineStrong,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                child: switch (_step) {
                  0 => const _Welcome(),
                  1 => _Budget(
                    controller: _budget,
                    presets: _presets,
                    onChanged: () => setState(() {}),
                  ),
                  _ => _Demo(animate: widget.animateDemo),
                },
              ),
            ),
            SheetButton(
              key: const ValueKey('onboarding-next'),
              label: _step == 2 ? 'Activar captura y empezar' : 'Continuar',
              height: 56,
              onTap: _step == 1 && _typedBudget == null ? null : _next,
              color: _step == 1 && _typedBudget == null
                  ? DesignColors.disabled
                  : DesignColors.red,
            ),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _skip,
                child: SizedBox(
                  height: 46,
                  child: Center(
                    child: Text(
                      _step == 2 ? 'Ahora no' : 'Saltar',
                      style: DesignText.body14Bold.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 60),
      DecoratedBox(
        decoration: BoxDecoration(
          // The mark's corner: 114 of 512 units.
          borderRadius: BorderRadius.circular(64 * 114 / 512),
          boxShadow: DesignShadows.fab,
        ),
        child: const BrandMark(size: 64),
      ),
      const SizedBox(height: 24),
      Text('Tu plata,\nen orden.', style: DesignText.hero),
      const SizedBox(height: 14),
      Text(
        'Pagaste. Compartiste. Solito se encarga del resto: tus gastos se '
        'registran solos y sabes cuánto puedes gastar hoy.',
        style: DesignText.lead.copyWith(color: DesignColors.ink2),
      ),
    ],
  );
}

class _Budget extends StatelessWidget {
  const _Budget({
    required this.controller,
    required this.presets,
    required this.onChanged,
  });

  final TextEditingController controller;
  final List<int> presets;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 60),
      Text('¿Cuánto quieres gastar al mes?', style: DesignText.question),
      const SizedBox(height: 12),
      Text(
        'Con eso calculamos cuánto puedes gastar cada día.',
        style: DesignText.lead.copyWith(color: DesignColors.ink2),
      ),
      const SizedBox(height: 28),
      Container(
        padding: const EdgeInsets.only(bottom: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: DesignColors.ink, width: 2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'S/',
              style: DesignText.currencyLarge.copyWith(
                color: DesignColors.ink2,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const ValueKey('onboarding-budget'),
                controller: controller,
                onChanged: (_) => onChanged(),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: DesignText.budgetInput,
                cursorColor: DesignColors.red,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final cents in presets)
            DsChip(
              label: Fmt.money0(cents / 100),
              selected: Fmt.parseCents(controller.text) == cents,
              padding: 16,
              onTap: () {
                controller.text = (cents ~/ 100).toString();
                onChanged();
              },
            ),
        ],
      ),
    ],
  );
}

class _Demo extends StatelessWidget {
  const _Demo({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 28),
      Text('Registra sin escribir', style: DesignText.stepTitle),
      const SizedBox(height: 8),
      Text(
        'Pagas con Yape, compartes el comprobante y se registra solo.',
        style: DesignText.lead.copyWith(color: DesignColors.ink2),
      ),
      const SizedBox(height: 16),
      ShareDemo(animate: animate),
    ],
  );
}
