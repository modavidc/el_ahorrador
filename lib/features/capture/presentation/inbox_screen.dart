import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';

/// Por revisar: captured payments missing an amount or a category, completed
/// inside their card and approved or discarded.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.service, this.onApproved});

  final CaptureService service;

  /// Called with each registered movement id.
  final ValueChanged<String>? onApproved;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late final Stream<List<InboxItem>> _inbox = widget.service.watchInbox();

  /// What the user filled in each card, by capture id.
  final _category = <String, String>{};
  final _amount = <String, int>{};

  String? _categoryOf(InboxItem i) =>
      _category[i.captureId] ?? i.draft.category;
  int? _amountOf(InboxItem i) => _amount[i.captureId] ?? i.draft.amountCents;

  bool _ready(InboxItem i) => _categoryOf(i) != null && (_amountOf(i) ?? 0) > 0;

  Future<void> _approve(InboxItem item) async {
    final id = await widget.service.approve(
      item,
      category: _categoryOf(item),
      amountCents: _amountOf(item),
    );
    widget.onApproved?.call(id);
    if (mounted) showUndoToast(context, 'Registrado');
  }

  Future<void> _approveAll(List<InboxItem> items) async {
    final ready = items.where(_ready).toList();
    for (final item in ready) {
      await _approve(item);
    }
    if (mounted) showUndoToast(context, '${ready.length} registrados');
  }

  Future<void> _discard(InboxItem item) async {
    await widget.service.discard(item);
    if (!mounted) return;
    showUndoToast(
      context,
      'Descartado',
      onUndo: () => widget.service.restore(item),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<InboxItem>>(
    stream: _inbox,
    builder: (context, snapshot) {
      final items = snapshot.data ?? const <InboxItem>[];
      final ready = items.where(_ready).length;
      return SubPage(
        title: 'Por revisar',
        trailing:
            '${items.length} '
            '${items.length == 1 ? 'pendiente' : 'pendientes'}',
        children: [
          if (snapshot.hasData && items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 70, 20, 0),
              child: Column(
                children: [
                  Text(
                    'Todo al día',
                    style: DesignText.style(
                      26,
                      FontWeight.w800,
                      letterSpacing: -.02,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No hay pagos pendientes.',
                    style: DesignText.body14.copyWith(color: DesignColors.ink2),
                  ),
                ],
              ),
            ),
          if (ready > 1)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => _approveAll(items),
                child: SizedBox(
                  height: 44,
                  child: Center(
                    child: Text(
                      'Aprobar todo',
                      style: DesignText.body14Bold.copyWith(
                        color: DesignColors.red,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          for (final item in items) ...[
            const SizedBox(height: 10),
            _InboxCard(
              key: ValueKey(item.captureId),
              item: item,
              category: _categoryOf(item),
              amountCents: _amountOf(item),
              onCategory: (c) => setState(() => _category[item.captureId] = c),
              onAmount: (a) => setState(() {
                if (a == null) {
                  _amount.remove(item.captureId);
                } else {
                  _amount[item.captureId] = a;
                }
              }),
              onApprove: _ready(item) ? () => _approve(item) : null,
              onDiscard: () => _discard(item),
            ),
          ],
        ],
      );
    },
  );
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    super.key,
    required this.item,
    required this.category,
    required this.amountCents,
    required this.onCategory,
    required this.onAmount,
    required this.onApprove,
    required this.onDiscard,
  });

  final InboxItem item;
  final String? category;
  final int? amountCents;
  final ValueChanged<String> onCategory;
  final ValueChanged<int?> onAmount;
  final VoidCallback? onApprove;
  final VoidCallback onDiscard;

  static const _choices = [
    'Comida',
    'Mercado',
    'Transporte',
    'Compras',
    'Otros',
  ];

  @override
  Widget build(BuildContext context) {
    final d = item.draft;
    final needsCategory = d.category == null;
    final needsAmount = d.amountCents == null;
    final style = CategoryStyle.forName(category);
    final missing = (amountCents ?? 0) <= 0
        ? 'Falta el monto'
        : category == null
        ? 'Falta la categoría'
        : null;
    return PaperCard(
      radius: DesignRadius.menu,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile.category(style, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignText.rowAmount,
                    ),
                    Text(
                      '${item.origin.label ?? 'Captura'} · '
                      '${Fmt.time(item.receivedAt)} · ${d.account}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignText.small.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                amountCents == null ? 'S/ —' : Fmt.money(amountCents! / 100),
                style: DesignText.button,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: DesignColors.amberSoft,
              borderRadius: BorderRadius.circular(DesignRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Sym(
                  DesignIcons.info,
                  size: 14,
                  color: DesignColors.amberDeep,
                ),
                const SizedBox(width: 6),
                Text(
                  d.why ?? 'Revisa los datos',
                  style: DesignText.smallBold.copyWith(
                    color: DesignColors.amberDeep,
                  ),
                ),
              ],
            ),
          ),
          if (needsCategory) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in _choices)
                  _OutlineChip(
                    name: name,
                    selected: category == name,
                    onTap: () => onCategory(name),
                  ),
              ],
            ),
          ],
          if (needsAmount) ...[
            const SizedBox(height: 10),
            TextField(
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: DesignText.style(17, FontWeight.w700),
              onChanged: (v) {
                final value = double.tryParse(v);
                onAmount(value == null ? null : (value * 100).round());
              },
              decoration: InputDecoration(
                hintText: 'S/ 0.00',
                hintStyle: DesignText.style(
                  17,
                  FontWeight.w700,
                ).copyWith(color: DesignColors.inkFaint),
                filled: true,
                fillColor: DesignColors.paper,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                enabledBorder: _border(DesignColors.lineStrong),
                focusedBorder: _border(DesignColors.ink),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardButton(
                  label: 'Descartar',
                  background: DesignColors.tile,
                  color: DesignColors.ink2,
                  onTap: onDiscard,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardButton(
                  label: onApprove == null ? missing ?? 'Aprobar' : 'Aprobar',
                  background: onApprove == null
                      ? DesignColors.chip
                      : DesignColors.ink,
                  color: onApprove == null
                      ? DesignColors.ink2
                      : DesignColors.card,
                  onTap: onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(DesignRadius.button),
    borderSide: BorderSide(color: color, width: 1.5),
  );
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? DesignColors.card : DesignColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? DesignColors.ink : null,
            borderRadius: BorderRadius.circular(DesignRadius.pill),
            border: Border.all(
              color: selected ? DesignColors.ink : DesignColors.lineStrong,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sym(CategoryStyle.forName(name).icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(name, style: DesignText.label13Semi.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.background,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(DesignRadius.button),
        ),
        child: Text(label, style: DesignText.body14Bold.copyWith(color: color)),
      ),
    ),
  );
}
