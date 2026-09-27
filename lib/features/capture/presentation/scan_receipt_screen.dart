import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/capture/domain/capture_models.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/capture/domain/capture_service.dart';

/// Escanear boleta (design §5): camera → photo with the red reading line →
/// amount, merchant and reading %, with category and account editable →
/// Editar / Guardar.
class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({
    super.key,
    required this.service,
    required this.camera,
    required this.accounts,
    required this.onSaved,
  });

  final CaptureService service;
  final ReceiptCamera camera;

  /// Names of the user's accounts.
  final List<String> accounts;

  /// The new movement, for the "Registrado · Deshacer" pill and the toast.
  final void Function(String movementId, String message) onSaved;

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen>
    with SingleTickerProviderStateMixin {
  late final _line = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String? _photo;
  ReceiptScan? _scan;
  String? _error;
  String? _category;
  String? _account;
  bool _editing = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _takePhoto();
  }

  @override
  void dispose() {
    final scan = _scan;
    if (scan != null && !_saved) {
      // Best effort: a capture left open is failed at the next start.
      unawaited(widget.service.cancelScan(scan).catchError((Object _) {}));
    }
    _line.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final scan = _scan;
    if (scan != null) await widget.service.cancelScan(scan);
    setState(() {
      _scan = null;
      _error = null;
      _editing = false;
    });
    final path = await widget.camera.takePhoto();
    if (!mounted) return;
    if (path == null) {
      if (_photo == null) Navigator.of(context).pop();
      return;
    }
    setState(() => _photo = path);
    _line.repeat(reverse: true);
    try {
      final result = await widget.service.scan(path);
      if (!mounted) return;
      final d = result.draft;
      setState(() {
        _scan = result;
        _category = d.category;
        _account = d.account;
        _amount.text = d.amountCents == null
            ? ''
            : (d.amountCents! / 100).toStringAsFixed(2);
        _note.text = d.note;
      });
    } on ScanException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      _line.stop();
    }
  }

  int? get _amountCents => Fmt.parseCents(_amount.text);

  bool get _canSave =>
      _scan != null &&
      _category != null &&
      _account != null &&
      (_amountCents ?? 0) > 0;

  Future<void> _save() async {
    final scan = _scan!;
    final amount = _amountCents!;
    final id = await widget.service.saveScan(
      scan,
      category: _category!,
      account: _account!,
      amountCents: amount,
      note: _note.text,
    );
    _saved = true;
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.onSaved(
      id,
      'Registrado · ${_note.text.trim()} ${Fmt.money(amount / 100)}',
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: DesignColors.cameraBackground,
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Sym(
                    DesignIcons.close,
                    size: 24,
                    color: DesignColors.card,
                  ),
                ),
                Text(
                  'Escanear boleta',
                  style: DesignText.subTitle.copyWith(color: DesignColors.card),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                _Viewfinder(photo: _photo, line: _line),
                const SizedBox(height: 16),
                _panel(),
              ],
            ),
          ),
          if (_scan != null && _error == null) _actions(),
        ],
      ),
    ),
  );

  Widget _panel() {
    if (_error != null) {
      return PaperCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('No se pudo registrar', style: DesignText.cardTitle),
            ErrorText(_error!),
            const SizedBox(height: 16),
            SheetButton(label: 'Tomar otra foto', onTap: _takePhoto),
          ],
        ),
      );
    }
    final scan = _scan;
    if (scan == null) {
      return PaperCard(
        padding: const EdgeInsets.all(18),
        child: Text(
          _photo == null ? 'Abriendo la cámara…' : 'Leyendo boleta…',
          style: DesignText.body14Semi.copyWith(color: DesignColors.ink2),
        ),
      );
    }
    final d = scan.draft;
    return PaperCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _note.text,
                  style: DesignText.body14Bold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (d.ocrPercent != null)
                StatusPill(
                  label: 'Lectura ${d.ocrPercent}%',
                  background: DesignColors.greenSoft,
                  color: DesignColors.green,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _amountCents == null ? 'S/ —' : Fmt.money(_amountCents! / 100),
            style: DesignText.figure,
          ),
          if (_editing) ...[
            const FieldLabel('Monto'),
            FieldBox(
              key: const ValueKey('scan-amount'),
              controller: _amount,
              amount: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const FieldLabel('Nota'),
            FieldBox(
              key: const ValueKey('scan-note'),
              controller: _note,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const FieldLabel('Categoría'),
          _choices(
            [for (final c in Category.expenses) c.label],
            _category,
            (v) => setState(() => _category = v),
          ),
          const FieldLabel('Cuenta'),
          _choices(
            widget.accounts,
            _account,
            (v) => setState(() => _account = v),
          ),
        ],
      ),
    );
  }

  /// Editar / Guardar, pinned under the scroll.
  Widget _actions() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Row(
      children: [
        Expanded(
          child: SheetButton.secondary(
            label: _editing ? 'Listo' : 'Editar',
            onTap: () => setState(() => _editing = !_editing),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SheetButton(
            key: const ValueKey('scan-save'),
            label: 'Guardar',
            onTap: _canSave ? _save : null,
            color: _canSave ? DesignColors.red : DesignColors.disabled,
          ),
        ),
      ],
    ),
  );

  Widget _choices(
    List<String> options,
    String? selected,
    ValueChanged<String> onSelected,
  ) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final o in options)
        DsChip(label: o, selected: o == selected, onTap: () => onSelected(o)),
    ],
  );
}

/// White frame with the photo and the red reading line while it is read.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.photo, required this.line});

  final String? photo;
  final AnimationController line;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 3 / 4,
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: DesignColors.onDarkTile,
        borderRadius: BorderRadius.circular(DesignRadius.notice),
        border: Border.all(color: DesignColors.card, width: 3),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photo != null)
            Image.file(
              File(photo!),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          else
            Center(
              child: Sym(
                DesignIcons.documentScanner,
                size: 48,
                color: DesignColors.onDarkText,
              ),
            ),
          AnimatedBuilder(
            animation: line,
            builder: (context, _) => line.isAnimating
                ? Align(
                    alignment: Alignment(0, line.value * 2 - 1),
                    child: Container(height: 3, color: DesignColors.red),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    ),
  );
}
