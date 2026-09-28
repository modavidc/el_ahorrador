import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/core/format/fmt.dart';

/// Building blocks of the v3 design (`design/Tema El Ahorrador v3.dc.html`).

/// Material Symbols glyph with the prototype's `line-height: 1` box.
class Sym extends StatelessWidget {
  const Sym(this.icon, {super.key, required this.size, this.color});

  final IconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(icon, size: size, color: color ?? DesignColors.textPrimary);
}

/// White card: radius 22 and the soft paper shadow.
class PaperCard extends StatelessWidget {
  const PaperCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = DesignRadius.card,
    this.border,
    this.color = DesignColors.card,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final BoxBorder? border;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: border,
      boxShadow: DesignShadows.card,
    ),
    child: child,
  );
}

/// Beige track with equal-width options; the selected one is a white pill.
class Segmented extends StatelessWidget {
  const Segmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = 36,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: DesignColors.chip,
      borderRadius: BorderRadius.circular(DesignRadius.button),
    ),
    child: Row(
      children: [
        for (final (i, label) in labels.indexed)
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selected,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: height,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? DesignColors.card : null,
                    borderRadius: BorderRadius.circular(DesignRadius.segment),
                    boxShadow: i == selected ? DesignShadows.segment : null,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DesignText.body14Bold.copyWith(
                      color: i == selected
                          ? DesignColors.ink
                          : DesignColors.ink2,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// The single chip of v3: beige when off, ink when on. 40px tall.
class DsChip extends StatelessWidget {
  const DsChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.padding = 14,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double padding;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: EdgeInsets.symmetric(horizontal: padding),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? DesignColors.ink : DesignColors.chip,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DesignText.label13Bold.copyWith(
            color: selected ? DesignColors.card : DesignColors.ink,
          ),
        ),
      ),
    ),
  );
}

/// Rounded square holding one symbol (categories, notices, menu items).
class IconTile extends StatelessWidget {
  const IconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 40,
    this.iconSize = 22,
    this.radius = DesignRadius.tile,
  });

  IconTile.category(
    CategoryStyle style, {
    super.key,
    this.size = 40,
    this.iconSize = 22,
    this.radius = DesignRadius.tile,
  }) : icon = style.icon,
       color = style.foreground,
       background = style.background;

  final IconData icon;
  final Color color;
  final Color background;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(radius),
    ),
    child: Sym(icon, size: iconSize, color: color),
  );
}

/// Uppercase grey label above a group ("AVISOS · 3", "EN QUÉ SE FUE").
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: DesignText.section.copyWith(color: DesignColors.ink2),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Style of a movement: category tile, or grey arrows for transfers.
CategoryStyle movementStyle(Movement m) => m.type == MovementType.transfer
    ? CategoryStyle.transferencia
    : CategoryStyle.forName(m.category);

/// "−S/ 16.00", "+S/ 450.00", or "S/ 200.00" for transfers.
String signedAmount(Movement m) => switch (m.type) {
  MovementType.income => '+${Fmt.money(m.amount)}',
  MovementType.expense => '${Fmt.minus}${Fmt.money(m.amount)}',
  MovementType.transfer => Fmt.money(m.amount),
};

Color movementAmountColor(Movement m) =>
    m.type == MovementType.income ? DesignColors.green : DesignColors.ink;

/// "Comida · Yape", or "Transferencia" for transfers.
String movementMeta(Movement m) => m.type == MovementType.transfer
    ? 'Transferencia'
    : '${m.category} · ${m.account}';

/// One movement inside a day card: tile, note, meta with its origin label,
/// the "Registrado · Deshacer" pill while it is new, and the amount.
class MovementRow extends StatelessWidget {
  const MovementRow({
    super.key,
    required this.movement,
    required this.first,
    this.onTap,
    this.onUndo,
    this.compact = false,
  });

  final Movement movement;
  final bool first;
  final VoidCallback? onTap;

  /// Set while the movement was just registered; shows the green pill.
  final VoidCallback? onUndo;

  /// Calendar variant: 38px tile, 60px row, no origin label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final origin = m.origin.label;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: compact ? 60 : 64),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: DesignColors.lineSoft)),
          ),
          child: Row(
            children: [
              IconTile.category(
                movementStyle(m),
                size: compact ? 38 : 40,
                iconSize: compact ? 20 : 22,
                radius: compact ? 13 : DesignRadius.tile,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: compact ? 0 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DesignText.row,
                      ),
                      SizedBox(height: compact ? 0 : 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              movementMeta(m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DesignText.small.copyWith(
                                color: DesignColors.ink2,
                              ),
                            ),
                          ),
                          if (!compact && origin != null && onUndo == null) ...[
                            const SizedBox(width: 6),
                            OriginPill(origin),
                          ],
                        ],
                      ),
                      if (onUndo != null) ...[
                        const SizedBox(height: 4),
                        _FreshPill(onUndo: onUndo!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                signedAmount(m),
                style: DesignText.rowAmount.copyWith(
                  color: movementAmountColor(m),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sparkle + "Compartido" next to the row meta.
class OriginPill extends StatelessWidget {
  const OriginPill(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: DesignColors.tile,
      borderRadius: BorderRadius.circular(DesignRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Sym(DesignIcons.autoAwesome, size: 12, color: DesignColors.ink2),
        const SizedBox(width: 2),
        Text(
          label,
          style: DesignText.smallSemi.copyWith(color: DesignColors.ink2),
        ),
      ],
    ),
  );
}

class _FreshPill extends StatelessWidget {
  const _FreshPill({required this.onUndo});

  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final style = DesignText.smallBold.copyWith(color: DesignColors.green);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: DesignColors.greenSoft,
        borderRadius: BorderRadius.circular(DesignRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Sym(DesignIcons.check, size: 14, color: DesignColors.green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              'Registrado ·',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
          const SizedBox(width: 4),
          Semantics(
            button: true,
            child: GestureDetector(
              onTap: onUndo,
              child: Text(
                'Deshacer',
                style: style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationColor: DesignColors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Day header of the daily list: "27  Hoy ········ −S/ 25.00".
class DayHeader extends StatelessWidget {
  const DayHeader({
    super.key,
    required this.day,
    required this.label,
    required this.net,
    this.top = 22,
  });

  final int day;
  final String label;
  final String net;
  final double top;

  @override
  Widget build(BuildContext context) {
    final grey = DesignText.body14Semi.copyWith(color: DesignColors.ink2);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, top, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(Fmt.twoDigits(day), style: DesignText.dayNumber),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: grey,
            ),
          ),
          Text(net, style: grey),
        ],
      ),
    );
  }
}

/// Bottom sheet of v3: paper, 32px top corners, grab handle, at most 85% of
/// the screen, entering with the prototype's 280ms curve.
Future<T?> showPaperSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  EdgeInsets padding = const EdgeInsets.fromLTRB(18, 12, 18, 24),
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: DesignColors.paper,
  barrierColor: DesignColors.scrim,
  showDragHandle: false,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.sizeOf(context).height * .85,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(DesignRadius.sheet),
    ),
  ),
  sheetAnimationStyle: const AnimationStyle(
    duration: Duration(milliseconds: 280),
    curve: Cubic(.2, 0, 0, 1),
  ),
  builder: (context) => Padding(
    padding: padding.copyWith(
      bottom: padding.bottom + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: DesignColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Flexible(child: builder(context)),
      ],
    ),
  ),
);

/// Full-width button of sheets: red CTA, ink final action or beige
/// secondary.
class SheetButton extends StatelessWidget {
  const SheetButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = DesignColors.red,
    this.foreground = DesignColors.card,
    this.height = 54,
  });

  const SheetButton.secondary({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
  }) : color = DesignColors.chip,
       foreground = DesignColors.ink;

  const SheetButton.ink({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 54,
  }) : color = DesignColors.ink,
       foreground = DesignColors.card;

  final String label;
  final VoidCallback? onTap;
  final Color color;
  final Color foreground;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(DesignRadius.cta),
        ),
        child: Text(
          label,
          style: DesignText.button.copyWith(color: foreground),
        ),
      ),
    ),
  );
}

/// Ink toast above the navigation with an optional "Deshacer" button; stays
/// 3.5 s as in the prototype.
void showUndoToast(
  BuildContext context,
  String message, {
  FutureOr<void> Function()? onUndo,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: DesignColors.ink,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignRadius.lg),
        ),
        duration: const Duration(milliseconds: 3500),
        content: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  message,
                  style: DesignText.body14Semi.copyWith(
                    color: DesignColors.card,
                  ),
                ),
              ),
            ),
            if (onUndo != null)
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onUndo();
                  },
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(
                      'Deshacer',
                      style: DesignText.body14Bold.copyWith(
                        color: DesignColors.onDarkAccent,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
}

/// Sub-page of v3: back arrow, 17/700 title and an optional grey note on the
/// right ("2 pendientes"), over paper.
class SubPage extends StatelessWidget {
  const SubPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
  });

  final String title;
  final String? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignColors.paper,
    body: SafeArea(
      child: Column(
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Volver',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Sym(DesignIcons.arrowBack, size: 24),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: Text(title, style: DesignText.subTitle)),
                  if (trailing != null)
                    Text(
                      trailing!,
                      style: DesignText.label13Semi.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

/// On/off switch of v3: 50×30 track, red when on.
class DsToggle extends StatelessWidget {
  const DsToggle({super.key, required this.value, required this.onTap});

  final bool value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 30,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? DesignColors.red : DesignColors.lineStrong,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
        ),
        child: Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: DesignColors.card,
            shape: BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

/// Round 44px icon button of headers (search, history, +).
class IconAction extends StatelessWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = DesignColors.ink2,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: Sym(icon, size: 24, color: color)),
      ),
    ),
  );
}

/// "EFECTIVO ··········· S/ 145.00" above a group card.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final style = DesignText.label13Bold.copyWith(
      color: DesignColors.ink2,
      letterSpacing: .02 * 13,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 8),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: style)),
          if (trailing != null) Text(trailing!, style: style),
        ],
      ),
    );
  }
}

/// White card with an icon, a title, a line of help and one action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
    child: Column(
      children: [
        Sym(icon, size: 32, color: DesignColors.red),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: DesignText.cardTitle),
        const SizedBox(height: 4),
        Text(
          body,
          textAlign: TextAlign.center,
          style: DesignText.body14.copyWith(
            color: DesignColors.ink2,
            height: 1.45,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: SheetButton(label: action!, height: 48, onTap: onAction),
          ),
        ],
      ],
    ),
  );
}

/// Beige suggestion chip ("Interbank").
class TileChip extends StatelessWidget {
  const TileChip({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignColors.tile,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
        ),
        child: Text(label, style: DesignText.label13Semi),
      ),
    ),
  );
}

/// Small uppercase label above a form field ("SALDO INICIAL").
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 6),
    child: Text(
      text,
      style: DesignText.smallBold.copyWith(color: DesignColors.ink2),
    ),
  );
}

/// White input with the 1.5px beige border of v3 forms; [amount] makes it
/// 18/700 and accepts only numbers with two decimals.
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    required this.controller,
    this.hint,
    this.amount = false,
    this.keyboardType,
    this.onChanged,
    this.obscure = false,
  });

  final TextEditingController controller;
  final String? hint;
  final bool amount;

  /// Secrets such as an API key.
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final style = amount
        ? DesignText.style(18, FontWeight.w700)
        : DesignText.style(16, FontWeight.w400);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DesignRadius.button),
      borderSide: BorderSide(color: c, width: 1.5),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: style,
      keyboardType: keyboardType,
      obscureText: obscure,
      autocorrect: !obscure,
      enableSuggestions: !obscure,
      inputFormatters: amount
          ? [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}'))]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style.copyWith(color: DesignColors.inkFaint),
        filled: true,
        fillColor: DesignColors.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: border(DesignColors.lineStrong),
        focusedBorder: border(DesignColors.ink),
      ),
    );
  }
}

class ErrorText extends StatelessWidget {
  const ErrorText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Text(
      text,
      style: DesignText.label13Semi.copyWith(color: DesignColors.red),
    ),
  );
}

/// 52px outlined action of sheets ("Eliminar", "Ocultar", "Repetir").
class OutlineAction extends StatelessWidget {
  const OutlineAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = DesignColors.ink,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          border: Border.all(color: DesignColors.lineStrong, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sym(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: DesignText.body14Bold.copyWith(color: color)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Message of a failed change, without the exception type.
String friendlyError(Object e) => switch (e) {
  StateError(:final message) => message,
  ArgumentError(:final message) => '$message',
  _ => 'No se pudo guardar. Inténtalo otra vez.',
};

/// Thin bar over a beige track; [ratio] is clamped to 0–1.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.ratio,
    required this.color,
    this.height = 6,
  });

  final double ratio;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Container(
      height: height,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: DesignColors.chip,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Container(
        width: box.maxWidth * ratio.clamp(0, 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    ),
  );
}

/// Small colored pill with an icon ("vs agosto: +12%").
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.color,
    this.icon,
  });

  final String label;
  final Color background;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(DesignRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Sym(icon!, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: DesignText.smallBold.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

/// Settings row: optional icon tile, label, optional subtitle and either a
/// value with a chevron or a switch.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.value,
    this.toggle,
    this.first = false,
    this.dot = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final String? subtitle;

  /// Text on the right, followed by a chevron.
  final String? value;

  /// When not null, a switch replaces the value and chevron.
  final bool? toggle;
  final bool first;

  /// Red dot before the chevron: something needs attention.
  final bool dot;

  @override
  Widget build(BuildContext context) => Semantics(
    button: toggle == null,
    toggled: toggle,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.lineSoft)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              IconTile(
                icon: icon!,
                color: DesignColors.ink,
                background: DesignColors.tile,
                size: 36,
                iconSize: 20,
                radius: DesignRadius.md,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: DesignText.row),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: DesignText.small.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (toggle != null)
              DsToggle(value: toggle!, onTap: onTap ?? () {})
            else ...[
              if (value != null && value!.isNotEmpty)
                Text(
                  value!,
                  style: DesignText.body14.copyWith(color: DesignColors.ink2),
                ),
              if (dot) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: DesignColors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const Sym(
                DesignIcons.chevronRight,
                size: 20,
                color: DesignColors.inkFaint,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// [SettingRow] with a switch.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.first = false,
  });

  final String label;
  final bool value;
  final VoidCallback onTap;
  final IconData? icon;
  final String? subtitle;
  final bool first;

  @override
  Widget build(BuildContext context) => SettingRow(
    label: label,
    icon: icon,
    subtitle: subtitle,
    toggle: value,
    first: first,
    onTap: onTap,
  );
}

/// White card of rows under an optional section title.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.rows});

  final String? title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title != null)
        SectionHeader(title: title!)
      else
        const SizedBox(height: 16),
      PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(children: rows),
      ),
    ],
  );
}

/// White search field with a magnifier, 48px tall.
class SearchBox extends StatelessWidget {
  const SearchBox({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.autofocus = false,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: DesignColors.card,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      boxShadow: DesignShadows.card,
    ),
    child: Row(
      children: [
        const Sym(DesignIcons.search, size: 20, color: DesignColors.ink2),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: autofocus,
            onChanged: onChanged,
            style: DesignText.input,
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: hint,
              hintStyle: DesignText.input.copyWith(color: DesignColors.ink2),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Setting with a few choices as chips ("Tono: Directo · Amable · …").
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.first = false,
  });

  final String label;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final bool first;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      border: first
          ? null
          : const Border(top: BorderSide(color: DesignColors.lineSoft)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DesignText.row),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final o in options)
              DsChip(
                label: o,
                selected: o == selected,
                onTap: () => onSelected(o),
              ),
          ],
        ),
      ],
    ),
  );
}

/// The Solito app icon ("Sol-moneda"): a paper sun-coin with "S/" on a red
/// rounded square, drawn like `docs/producto/play-store/icon.svg`.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Solito',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandMarkPainter()),
    ),
  );
}

class _BrandMarkPainter extends CustomPainter {
  static const _canvas = 512.0;
  static const _center = Offset(256, 256);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _canvas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, _canvas, _canvas),
        const Radius.circular(114),
      ),
      Paint()..color = DesignColors.red,
    );
    final rays = Paint()
      ..color = DesignColors.paper
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final direction = Offset.fromDirection(i * math.pi / 6 - math.pi / 2);
      canvas.drawLine(
        _center + direction * 150,
        _center + direction * 196,
        rays,
      );
    }
    canvas.drawCircle(_center, 122, Paint()..color = DesignColors.paper);
    final text = TextPainter(
      text: TextSpan(text: 'S/', style: DesignText.brandMark),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = text.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    text.paint(canvas, Offset(256 - text.width / 2, 298 - baseline));
    text.dispose();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) => false;
}
