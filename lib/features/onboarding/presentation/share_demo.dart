import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';

/// The looping demo of the onboarding (`design/share-demo-ahorrador.js`),
/// recreated with native animation: pay with Yape → Compartir → El
/// Ahorrador reads it → it is in Movimientos with "Registrado · Deshacer".
class ShareDemo extends StatefulWidget {
  const ShareDemo({super.key, this.animate = true});

  /// Off: shows the last scene still (tests and visual checks).
  final bool animate;

  static const length = 12.6;
  static const segments = [
    (0.0, 3.2, 'Paga'),
    (3.2, 5.3, 'Compartir'),
    (5.3, 8.4, 'El Ahorrador'),
    (8.4, length, 'Listo'),
  ];

  @override
  State<ShareDemo> createState() => _ShareDemoState();
}

class _ShareDemoState extends State<ShareDemo>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 12600),
    value: widget.animate ? 0 : 0.8,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _clock.repeat();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _toggle() => setState(() {
    if (_clock.isAnimating) {
      _clock.stop();
    } else {
      _clock.repeat();
    }
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _clock,
    builder: (context, _) {
      final t = _clock.value * ShareDemo.length;
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          color: DesignColors.tile,
          borderRadius: BorderRadius.circular(DesignRadius.card),
        ),
        child: Column(
          children: [
            Container(
              width: 194,
              height: 374,
              decoration: BoxDecoration(
                color: DesignColors.card,
                borderRadius: BorderRadius.circular(DesignRadius.sheet),
                border: Border.all(color: DesignColors.ink, width: 7),
                boxShadow: DesignShadows.floating,
              ),
              // Drawn at phone size and scaled down, as the prototype does.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(DesignRadius.sheet - 7),
                child: FittedBox(
                  child: SizedBox(width: 210, height: 420, child: _scene(t)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Semantics(
                  button: true,
                  label: _clock.isAnimating ? 'Pausar' : 'Reproducir',
                  child: GestureDetector(
                    onTap: _toggle,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: DesignColors.card,
                        shape: BoxShape.circle,
                      ),
                      child: Sym(
                        DesignIcons.filled(
                          _clock.isAnimating
                              ? DesignIcons.pause
                              : DesignIcons.playArrow,
                        ),
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                for (final (from, to, label) in ShareDemo.segments) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    flex: ((to - from) * 10).round(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProgressLine(
                          ratio: ((t - from) / (to - from)).clamp(0, 1),
                          color: DesignColors.ink,
                          height: 3,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t >= from && t < to
                              ? DesignText.label13Bold
                              : DesignText.label13.copyWith(
                                  color: DesignColors.ink2,
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    },
  );

  Widget _scene(double t) {
    if (t < 1.8) return _YapeForm(pressed: t > 1.4);
    if (t < 3.2) return _YapeDone(highlight: t > 2.6);
    if (t < 5.3) {
      return Stack(
        children: [
          const _YapeDone(highlight: false),
          const ColoredBox(color: DesignColors.scrim, child: SizedBox.expand()),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionalTranslation(
              translation: Offset(0, 1 - _ease(((t - 3.2) / .4).clamp(0, 1))),
              child: _ShareSheet(highlight: t > 4.4),
            ),
          ),
        ],
      );
    }
    if (t < 8.4) return _Reading(t: t - 5.3);
    return const _Movements();
  }

  static double _ease(double x) => 1 - math.pow(1 - x, 3).toDouble();
}

class _YapeForm extends StatelessWidget {
  const _YapeForm({required this.pressed});

  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final onYape = DesignColors.card;
    return Column(
      children: [
        Container(
          color: DesignColors.yape,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Sym(DesignIcons.arrowBack, size: 16, color: onYape),
                  const SizedBox(width: 6),
                  Text(
                    'Yapear a',
                    style: DesignText.smallSemi.copyWith(color: onYape),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Rosa Quispe M.',
                style: DesignText.body14Bold.copyWith(color: onYape),
              ),
              Text(
                '••• ••• 482',
                style: DesignText.small.copyWith(color: onYape),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Text('S/ 16', style: DesignText.figure),
        const SizedBox(height: 6),
        Text(
          'Almuerzo',
          style: DesignText.label13.copyWith(color: DesignColors.ink2),
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(14),
          child: AnimatedScale(
            scale: pressed ? .96 : 1,
            duration: const Duration(milliseconds: 120),
            child: SheetButton(
              label: 'Yapear',
              height: 40,
              color: DesignColors.yape,
              onTap: null,
            ),
          ),
        ),
      ],
    );
  }
}

class _YapeDone extends StatelessWidget {
  const _YapeDone({required this.highlight});

  final bool highlight;

  static Widget _receiptRow(String label, String value) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DesignText.tiny.copyWith(color: DesignColors.ink2),
        ),
      ),
      Text(value, style: DesignText.tinyBold),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final onYape = DesignColors.card;
    return ColoredBox(
      color: DesignColors.yape,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 26, 8, 10),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: onYape, shape: BoxShape.circle),
              child: Sym(DesignIcons.check, size: 26, color: DesignColors.yape),
            ),
            const SizedBox(height: 10),
            Text(
              '¡Yapeaste!',
              style: DesignText.subTitle.copyWith(color: onYape),
            ),
            const SizedBox(height: 6),
            Text('S/ 16', style: DesignText.figure.copyWith(color: onYape)),
            const SizedBox(height: 4),
            Text(
              'Rosa Quispe M.',
              style: DesignText.smallBold.copyWith(color: onYape),
            ),
            Text(
              '26 set. 2026 · 01:12 p. m.',
              style: DesignText.tiny.copyWith(color: onYape),
            ),
            const SizedBox(height: 14),
            PaperCard(
              radius: DesignRadius.md,
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  _receiptRow('Nro. de operación', '04812345'),
                  const SizedBox(height: 6),
                  _receiptRow('Destino', 'Yape'),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 34,
                    decoration: BoxDecoration(
                      color: DesignColors.card,
                      borderRadius: BorderRadius.circular(DesignRadius.pill),
                      border: Border.all(
                        color: highlight
                            ? DesignColors.onDarkText
                            : DesignColors.card,
                        width: 3,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Sym(
                          DesignIcons.share,
                          size: 12,
                          color: DesignColors.yape,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Compartir',
                          style: DesignText.tinyBold.copyWith(
                            color: DesignColors.yape,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(DesignRadius.pill),
                      border: Border.all(color: onYape),
                    ),
                    child: Text(
                      'Ir a inicio',
                      style: DesignText.tinyBold.copyWith(color: onYape),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareSheet extends StatelessWidget {
  const _ShareSheet({required this.highlight});

  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    height: 170,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    decoration: const BoxDecoration(
      color: DesignColors.card,
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Compartir imagen', style: DesignText.label13Bold),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _app(DesignIcons.forum, 'WhatsApp'),
            _app(DesignIcons.mail, 'Gmail'),
            _app(DesignIcons.backup, 'Drive'),
            _app(DesignIcons.savings, 'El Ahorrador', ours: true),
          ],
        ),
      ],
    ),
  );

  Widget _app(IconData icon, String label, {bool ours = false}) => SizedBox(
    width: 56,
    child: Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: ours ? DesignColors.red : DesignColors.tile,
            borderRadius: BorderRadius.circular(ours ? 12 : 999),
            border: ours && highlight
                ? Border.all(color: DesignColors.ink, width: 2)
                : null,
          ),
          child: Sym(
            ours ? DesignIcons.filled(icon) : icon,
            size: 20,
            color: ours ? DesignColors.onPrimary : DesignColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DesignText.tiny,
        ),
      ],
    ),
  );
}

class _Reading extends StatelessWidget {
  const _Reading({required this.t});

  /// Seconds since the app opened.
  final double t;

  @override
  Widget build(BuildContext context) {
    final reading = t < 1.4;
    final saved = t > 2.2;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Sym(
                DesignIcons.filled(DesignIcons.savings),
                size: 18,
                color: DesignColors.red,
              ),
              const SizedBox(width: 6),
              Text('El Ahorrador', style: DesignText.smallBold),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: 60,
            height: 84,
            decoration: BoxDecoration(
              color: DesignColors.yape,
              borderRadius: BorderRadius.circular(DesignRadius.sm),
            ),
            child: Sym(
              DesignIcons.checkCircle,
              size: 22,
              color: DesignColors.card,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reading ? 'Leyendo comprobante…' : 'Comprobante leído',
            style: DesignText.small.copyWith(color: DesignColors.ink2),
          ),
          const SizedBox(height: 10),
          if (!reading) ...[
            _field('Monto', 'S/ 16.00'),
            _field('Categoría', 'Comida'),
            _field('Cuenta', 'Yape'),
          ],
          const Spacer(),
          AnimatedOpacity(
            opacity: saved ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: SheetButton(
              label: 'Guardado',
              height: 38,
              color: DesignColors.green,
              onTap: null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: DesignText.small.copyWith(color: DesignColors.ink2)),
        Text(value, style: DesignText.smallBold),
      ],
    ),
  );
}

class _Movements extends StatelessWidget {
  const _Movements();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: DesignColors.paper,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Movimientos', style: DesignText.cardTitle),
          const SizedBox(height: 10),
          Text(
            'Hoy · dom 27',
            style: DesignText.smallBold.copyWith(color: DesignColors.ink2),
          ),
          const SizedBox(height: 6),
          PaperCard(
            radius: DesignRadius.lg,
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                _row('Almuerzo', 'Comida · Yape', '−S/ 16.00', fresh: true),
                _row('Café Tostado', 'Café · Yape', '−S/ 9.00'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ayer · sáb 26',
            style: DesignText.smallBold.copyWith(color: DesignColors.ink2),
          ),
          const SizedBox(height: 6),
          PaperCard(
            radius: DesignRadius.lg,
            padding: const EdgeInsets.all(10),
            child: _row('Uber a oficina', 'Taxi · BCP Visa', '−S/ 16.00'),
          ),
        ],
      ),
    ),
  );

  Widget _row(String note, String meta, String amount, {bool fresh = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note, style: DesignText.label13Bold),
                  Text(
                    meta,
                    style: DesignText.tiny.copyWith(color: DesignColors.ink2),
                  ),
                  if (fresh) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: DesignColors.greenSoft,
                        borderRadius: BorderRadius.circular(DesignRadius.pill),
                      ),
                      child: Text(
                        'Registrado · Deshacer',
                        style: DesignText.tinyBold.copyWith(
                          color: DesignColors.green,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(amount, style: DesignText.label13Bold),
          ],
        ),
      );
}
