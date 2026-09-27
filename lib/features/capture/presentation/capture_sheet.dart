import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/legacy_widgets.dart';

/// Capture sheet of v3: "Leyendo comprobante…" → "Registrado" for one
/// image, "Leyendo 3 de 7…" → "7 imágenes procesadas" for several.
class CaptureSheet extends StatelessWidget {
  const CaptureSheet({
    super.key,
    required this.controller,
    required this.onUndo,
    required this.onOpenInbox,
    required this.onOpenMovement,
  });

  final CaptureController controller;
  final ValueChanged<List<String>> onUndo;
  final VoidCallback onOpenInbox;
  final ValueChanged<String> onOpenMovement;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final job = controller.job;
      if (job == null) return const SizedBox.shrink();
      final single = job.single ? job.items.single : null;
      final outcome = single?.outcome;
      final title = single == null
          ? job.finished
                ? '${job.items.length} imágenes procesadas'
                : 'Leyendo ${job.processed + 1} de ${job.items.length}…'
          : switch (outcome?.status) {
              null => 'Leyendo comprobante…',
              CaptureStatus.registered => 'Registrado',
              CaptureStatus.review => 'Falta un dato',
              CaptureStatus.duplicate => 'Ya estaba registrado',
              CaptureStatus.notReceipt => 'No es un comprobante',
              CaptureStatus.failed => 'No se pudo leer',
            };
      final footer = _footer(context, job);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    style: DesignText.style(
                      26,
                      FontWeight.w800,
                      letterSpacing: -.03,
                      height: 1.1,
                    ),
                  ),
                  if (single != null)
                    ..._single(context, single)
                  else
                    ..._batch(context, job),
                  if (!job.finished)
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          height: 44,
                          margin: const EdgeInsets.only(top: 8),
                          alignment: Alignment.center,
                          child: Text(
                            'Seguir en segundo plano',
                            style: DesignText.body14Bold.copyWith(
                              color: DesignColors.ink2,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 16), footer],
        ],
      );
    },
  );

  /// Buttons pinned under the scrolling content, so they stay visible with
  /// many images.
  Widget? _footer(BuildContext context, CaptureJob job) {
    if (!job.finished) return null;
    if (job.single) {
      final item = job.items.single;
      final o = item.outcome!;
      return Row(
        children: [
          if (switch (o.status) {
                CaptureStatus.registered => SheetButton.secondary(
                  label: 'Deshacer',
                  onTap: () {
                    Navigator.of(context).pop();
                    onUndo([o.movementId!]);
                  },
                ),
                CaptureStatus.review => SheetButton.secondary(
                  label: 'Ver Por revisar',
                  onTap: () {
                    Navigator.of(context).pop();
                    onOpenInbox();
                  },
                ),
                CaptureStatus.duplicate when o.originalMovementId != null =>
                  SheetButton.secondary(
                    label: 'Ver original',
                    onTap: () {
                      Navigator.of(context).pop();
                      onOpenMovement(o.originalMovementId!);
                    },
                  ),
                CaptureStatus.failed => SheetButton.secondary(
                  label: 'Reintentar',
                  onTap: () => controller.retry(item),
                ),
                _ => null,
              }
              case final secondary?) ...[
            Expanded(child: secondary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: SheetButton.ink(
              label: 'Listo',
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      );
    }
    final hasReview = job.count(CaptureStatus.review) > 0;
    return Row(
      children: [
        if (hasReview) ...[
          Expanded(
            child: SheetButton.secondary(
              label: 'Ver Por revisar',
              onTap: () {
                Navigator.of(context).pop();
                onOpenInbox();
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: SheetButton.ink(
            label: 'Listo',
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  List<Widget> _single(BuildContext context, CaptureItem item) {
    final o = item.outcome;
    if (o == null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: DesignColors.red,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Leyendo monto, comercio y fecha…',
                  style: DesignText.row.copyWith(
                    fontWeight: FontWeight.w400,
                    color: DesignColors.ink2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ];
    }
    final draft = o.draft;
    return [
      if (draft != null) ...[
        const SizedBox(height: 14),
        _DraftCard(draft: draft, why: o.status == CaptureStatus.review),
      ] else ...[
        const SizedBox(height: 12),
        Text(
          o.status == CaptureStatus.notReceipt
              ? 'No encontramos un pago de Yape, Plin o tu banco en '
                    '${item.fileName}.'
              : 'Algo falló al leer ${item.fileName}. Puedes reintentar o '
                    'registrarlo a mano.',
          style: DesignText.row.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: DesignColors.ink2,
          ),
        ),
      ],
    ];
  }

  List<Widget> _batch(BuildContext context, CaptureJob job) {
    return [
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, box) => Container(
          height: 6,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: DesignColors.line,
            borderRadius: BorderRadius.circular(3),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: box.maxWidth * job.processed / job.items.length,
            decoration: BoxDecoration(
              color: DesignColors.red,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
      if (job.finished) ...[
        const SizedBox(height: 10),
        Text(
          job.summary,
          style: DesignText.body14Semi.copyWith(color: DesignColors.ink2),
        ),
      ],
      const SizedBox(height: 10),
      PaperCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        child: Column(
          children: [
            for (final (i, item) in job.items.indexed)
              _BatchRow(
                item: item,
                first: i == 0,
                action: switch (item.outcome?.status) {
                  CaptureStatus.duplicate
                      when item.outcome!.originalMovementId != null =>
                    (
                      'Ver original',
                      () {
                        Navigator.of(context).pop();
                        onOpenMovement(item.outcome!.originalMovementId!);
                      },
                    ),
                  CaptureStatus.failed || CaptureStatus.notReceipt => (
                    'Reintentar',
                    () => controller.retry(item),
                  ),
                  _ => null,
                },
              ),
          ],
        ),
      ),
    ];
  }
}

/// What was read: category tile, note, "Hoy · 21:38 · Yape · Mercado", the
/// amount and the reading and rule chips.
class _DraftCard extends StatelessWidget {
  const _DraftCard({required this.draft, required this.why});

  final CaptureDraft draft;
  final bool why;

  @override
  Widget build(BuildContext context) {
    final d = draft;
    final style = CategoryStyle.forName(d.category);
    final today = AppClock.now();
    final when = DateUtils.isSameDay(d.at, today)
        ? 'Hoy'
        : '${d.at.day} ${Fmt.months[d.at.month - 1].toLowerCase()}';
    final amount = d.amountCents == null
        ? 'S/ —'
        : '${d.type == MovementType.income ? '+' : Fmt.minus}'
              '${Fmt.money(d.amountCents! / 100)}';
    return PaperCard(
      radius: DesignRadius.menu,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconTile.category(style, size: 44, iconSize: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DesignText.rowAmount,
                    ),
                    Text(
                      [
                        '$when · ${Fmt.time(d.at)}',
                        d.account,
                        ?d.category,
                      ].join(' · '),
                      style: DesignText.small.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style:
                  DesignText.style(
                    40,
                    FontWeight.w800,
                    letterSpacing: -.03,
                    height: 1,
                  ).copyWith(
                    color: d.type == MovementType.income
                        ? DesignColors.green
                        : DesignColors.ink,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (why && d.why != null)
                _Tag(
                  d.why!,
                  background: DesignColors.amberSoft,
                  color: DesignColors.amberDeep,
                  icon: DesignIcons.info,
                ),
              if (d.ocrPercent != null)
                _Tag(
                  'Lectura ${d.ocrPercent}%',
                  background: DesignColors.greenSoft,
                  color: DesignColors.green,
                ),
              if (d.ruleLabel != null)
                _Tag(
                  d.ruleLabel!,
                  background: DesignColors.tile,
                  color: DesignColors.ink2,
                  weight: FontWeight.w600,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(
    this.text, {
    required this.background,
    required this.color,
    this.icon,
    this.weight = FontWeight.w700,
  });

  final String text;
  final Color background;
  final Color color;
  final IconData? icon;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(DesignRadius.pill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Sym(icon!, size: 14, color: color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: DesignText.small.copyWith(color: color, fontWeight: weight),
          ),
        ),
      ],
    ),
  );
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.item, required this.first, this.action});

  final CaptureItem item;
  final bool first;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    final o = item.outcome;
    final draft = o?.draft;
    final (icon, label, color) = switch (o?.status) {
      null => (DesignIcons.checkCircle, 'Esperando', DesignColors.ink2),
      CaptureStatus.registered => (
        DesignIcons.checkCircle,
        'Registrado',
        DesignColors.green,
      ),
      CaptureStatus.duplicate => (
        DesignIcons.contentCopy,
        'Duplicado · omitido',
        DesignColors.amber,
      ),
      CaptureStatus.review => (
        DesignIcons.inbox,
        '${draft?.why ?? 'Falta un dato'} → Por revisar',
        DesignColors.amber,
      ),
      CaptureStatus.notReceipt => (
        DesignIcons.error,
        'No es un comprobante',
        DesignColors.red,
      ),
      CaptureStatus.failed => (
        DesignIcons.error,
        'No se pudo leer',
        DesignColors.red,
      ),
    };
    final amount = draft?.amountCents;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: o == null ? .35 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 54),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.lineSoft)),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: color,
              background: color.withAlpha(0x1F),
              size: 32,
              iconSize: 18,
              radius: 10,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft?.note ?? item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DesignText.body14Semi,
                    ),
                    Text(
                      label,
                      style: DesignText.smallSemi.copyWith(color: color),
                    ),
                  ],
                ),
              ),
            ),
            if (action case (final text, final onTap)) ...[
              const SizedBox(width: 6),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: DesignColors.chip,
                      borderRadius: BorderRadius.circular(DesignRadius.pill),
                    ),
                    child: Text(text, style: DesignText.smallBold),
                  ),
                ),
              ),
            ],
            const SizedBox(width: 8),
            Text(
              amount == null ? '—' : Fmt.money(amount / 100),
              style: DesignText.body14Bold,
            ),
          ],
        ),
      ),
    );
  }
}
