import 'dart:async';

import 'package:flutter/material.dart';

import '../features/ledger/ledger.dart';
import '../theme/design_tokens.dart';
import 'format.dart';
import 'widgets.dart';

/// Building blocks of the v3 design (`design/Tema El Ahorrador v3.dc.html`).

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
