import 'package:flutter/material.dart';

import '../features/ledger/ledger.dart';
import '../theme/design_tokens.dart';
import 'format.dart';

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

/// White rounded card with the `elevation.card` shadow.
class DsCard extends StatelessWidget {
  const DsCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: DesignColors.surfaceCard,
      borderRadius: BorderRadius.circular(DesignRadius.lg),
      boxShadow: DesignShadows.card,
    ),
    child: child,
  );
}

/// Horizontal 1px line.
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.color = DesignColors.borderSubtle});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(height: 1, color: color);
}

/// Equal-width tabs with a 3px underline (Trans. and Estad. headers).
class UnderlineTabs extends StatelessWidget {
  const UnderlineTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.only(top: 10, bottom: 9),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 3,
                    color: i == selected
                        ? DesignColors.primary
                        : Colors.transparent,
                  ),
                ),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                style: i == selected
                    ? DesignText.bodyStrong
                    : DesignText.body.copyWith(
                        color: DesignColors.textTertiary,
                      ),
              ),
            ),
          ),
        ),
    ],
  );
}

/// `‹ Sep 2026 ›` plus optional trailing actions.
class PeriodHeader extends StatelessWidget {
  const PeriodHeader({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    this.trailing,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 10, 12, 0),
    child: Row(
      children: [
        _Chevron(icon: DesignIcons.chevronLeft, onTap: onPrevious),
        const SizedBox(width: DesignSpacing.xs),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 92),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: DesignText.title,
          ),
        ),
        const SizedBox(width: DesignSpacing.xs),
        _Chevron(icon: DesignIcons.chevronRight, onTap: onNext),
        const Spacer(),
        ?trailing,
      ],
    ),
  );
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Sym(icon, size: 24),
    ),
  );
}

/// Ingresos / Gastos / Total bar under the tabs.
class SummaryBar extends StatelessWidget {
  const SummaryBar({super.key, required this.items});

  final List<(String, String, Color)> items;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
    decoration: const BoxDecoration(
      border: Border.symmetric(
        horizontal: BorderSide(color: DesignColors.border),
      ),
    ),
    child: Row(
      children: [
        for (final (label, value, color) in items)
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: DesignText.caption.copyWith(
                    color: DesignColors.textTertiary,
                  ),
                ),
                const SizedBox(height: DesignSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  style: DesignText.bodyStrong.copyWith(color: color),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

/// 36px rounded tile with the category icon.
class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.forName(category);
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(DesignRadius.tile),
      ),
      child: Sym(style.icon, size: 20, color: style.foreground),
    );
  }
}

Color amountColor(MovementType type) => switch (type) {
  MovementType.income => DesignColors.income,
  MovementType.expense => DesignColors.expense,
  MovementType.transfer => DesignColors.neutralAmount,
};

/// `Categoría · Sub · Cuenta · Hora` (transfers: `Origen → Destino`).
String movementMeta(Movement m) {
  final account = m.type == MovementType.transfer
      ? '${m.account} → ${m.toAccount}'
      : m.account;
  return [
    m.category,
    m.subcategory,
    account,
    Fmt.time(m.at),
  ].where((part) => part.isNotEmpty).join(' · ');
}

/// Compact transaction row. [inlineAmount] is the Daily layout (amount on
/// the title line and chips on the meta line); otherwise the amount sits on
/// the right, vertically centred (Calendar).
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.movement,
    required this.first,
    this.inlineAmount = true,
    this.onTap,
  });

  final Movement movement;
  final bool first;
  final bool inlineAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final title = Text(
      m.note,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DesignText.bodyMedium,
    );
    final amount = Text(
      Fmt.money(m.amount),
      style: DesignText.bodyStrong.copyWith(color: amountColor(m.type)),
    );
    final meta = Text(
      movementMeta(m),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: DesignText.caption.copyWith(color: DesignColors.textTertiary),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.borderSubtle)),
        ),
        child: Row(
          children: [
            CategoryTile(category: m.category),
            const SizedBox(width: DesignSpacing.md),
            Expanded(
              child: inlineAmount
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Expanded(child: title),
                            const SizedBox(width: DesignSpacing.sm),
                            amount,
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(child: meta),
                            if (m.method != null) ...[
                              const SizedBox(width: 6),
                              Pill.method(m.method!),
                            ],
                            if (m.ocrPercent != null) ...[
                              const SizedBox(width: 6),
                              Pill.ocr(m.ocrPercent!),
                            ],
                          ],
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: DesignSpacing.xxs),
                        meta,
                      ],
                    ),
            ),
            if (!inlineAmount) ...[
              const SizedBox(width: DesignSpacing.md),
              amount,
            ],
          ],
        ),
      ),
    );
  }
}

/// 20px pill chips: `Yape` (purple) and `OCR 92%` (green).
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
  });

  Pill.method(String method, {Key? key})
    : this(
        key: key,
        label: method,
        icon: DesignIcons.smartphone,
        foreground: DesignColors.ai,
        background: DesignColors.aiSoft,
      );

  Pill.ocr(int percent, {Key? key})
    : this(
        key: key,
        label: 'OCR $percent%',
        icon: DesignIcons.documentScanner,
        foreground: DesignColors.success,
        background: DesignColors.successSoft,
      );

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    height: 20,
    padding: const EdgeInsets.symmetric(horizontal: 7),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(DesignRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Sym(icon, size: 13, color: foreground),
        const SizedBox(width: 3),
        Text(label, style: DesignText.micro.copyWith(color: foreground)),
      ],
    ),
  );
}

/// Dark toast above the bottom navigation, as in the prototype.
void showDsToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: DesignColors.inverse,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        duration: const Duration(milliseconds: 2200),
        content: Row(
          children: [
            const Sym(
              DesignIcons.checkCircle,
              size: 18,
              color: DesignColors.toastIcon,
            ),
            const SizedBox(width: DesignSpacing.sm),
            Expanded(
              child: Text(
                message,
                style: DesignText.label.copyWith(
                  color: DesignColors.textInverse,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Empty space at the end of scrollable screens so the FAB never covers the
/// last row.
const bottomScrollSpacer = SizedBox(height: 96);
