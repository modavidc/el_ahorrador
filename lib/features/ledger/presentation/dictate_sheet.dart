import 'dart:async';

import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/ledger/domain/category_letters.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/entry_interpreter.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/speech_input.dart';
import 'package:el_ahorrador/features/ledger/presentation/entry_sheet.dart';

/// Opens Dictar (design §6).
Future<EntryResult?> showDictateSheet(
  BuildContext context, {
  required SpeechInput speech,
  required LedgerRepository repository,
  required List<LedgerAccount> accounts,
  CategoryLetters letters = CategoryLetters.defaults,
}) => showPaperSheet<EntryResult>(
  context,
  builder: (_) => DictateSheet(
    speech: speech,
    repository: repository,
    accounts: accounts,
    letters: letters,
  ),
);

/// Microphone with a pulse → transcript → amount, category and account
/// (editable) and Hoy → Editar / Guardar. The sentence is read by
/// [interpretEntry].
class DictateSheet extends StatefulWidget {
  const DictateSheet({
    super.key,
    required this.speech,
    required this.repository,
    required this.accounts,
    this.letters = CategoryLetters.defaults,
  });

  final SpeechInput speech;
  final LedgerRepository repository;
  final List<LedgerAccount> accounts;

  /// "C 15" → Comida S/ 15.
  final CategoryLetters letters;

  @override
  State<DictateSheet> createState() => _DictateSheetState();
}

class _DictateSheetState extends State<DictateSheet>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  final _amount = TextEditingController();
  final _note = TextEditingController();
  StreamSubscription<SpeechText>? _listening;

  String _heard = '';
  bool _done = false;
  String? _error;
  bool _editing = false;
  MovementType _type = MovementType.expense;
  Category _category = Category.otros;
  String? _account;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _listening?.cancel();
    widget.speech.stop();
    _pulse.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _listen() {
    setState(() {
      _heard = '';
      _done = false;
      _error = null;
      _editing = false;
    });
    _pulse.repeat(reverse: true);
    _listening?.cancel();
    _listening = widget.speech.listen().listen(
      (s) {
        setState(() => _heard = s.text);
        if (s.done) _interpret();
      },
      onError: (Object e) {
        _pulse.stop();
        setState(
          () => _error = e is SpeechUnavailable
              ? e.message
              : 'No se pudo escuchar. Intenta otra vez.',
        );
      },
      onDone: () {
        if (!_done && _error == null) _interpret();
      },
    );
  }

  void _interpret() {
    _pulse.stop();
    final entry = interpretEntry(
      _heard,
      accounts: widget.accounts,
      letters: widget.letters,
    );
    setState(() {
      _done = true;
      _type = entry.type;
      _category = entry.category;
      _account = entry.account.isEmpty ? null : entry.account;
      _amount.text = entry.amount ?? '';
      _note.text = entry.note;
      _editing = entry.amount == null;
    });
  }

  int? get _cents => Fmt.parseCents(_amount.text);

  bool get _canSave => _done && (_cents ?? 0) > 0 && _account != null;

  Future<void> _save() async {
    final cents = _cents!;
    final id = await widget.repository.addEntry(
      type: _type,
      amountCents: cents,
      account: _account!,
      category: _category.label,
      note: _note.text,
      sourceApp: 'Voz',
    );
    if (!mounted) return;
    final kind = _type == MovementType.income ? 'Ingreso' : 'Gasto';
    Navigator.of(
      context,
    ).pop(EntryResult(id, '$kind de ${Fmt.money(cents / 100)} registrado'));
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Flexible(child: SingleChildScrollView(child: _body())),
      if (_done) ...[
        const SizedBox(height: 14),
        Row(
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
                key: const ValueKey('dictate-save'),
                label: 'Guardar',
                onTap: _canSave ? _save : null,
                color: _canSave ? DesignColors.red : DesignColors.disabled,
              ),
            ),
          ],
        ),
      ],
    ],
  );

  Widget _body() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Dictar', style: DesignText.sheetHeading),
      const SizedBox(height: 4),
      Text(
        'Por ejemplo: “almuerzo 18 soles con Yape”',
        style: DesignText.label13.copyWith(color: DesignColors.ink2),
      ),
      const SizedBox(height: 20),
      Center(child: _mic()),
      const SizedBox(height: 16),
      Text(
        _heard.isEmpty ? (_error == null ? 'Te escucho…' : '') : '“$_heard”',
        textAlign: TextAlign.center,
        style: DesignText.headline,
      ),
      if (_error != null) ...[
        Center(child: ErrorText(_error!)),
        const SizedBox(height: 16),
        SheetButton.secondary(label: 'Intentar otra vez', onTap: _listen),
      ],
      if (_done) ..._result(),
    ],
  );

  Widget _mic() => Semantics(
    button: true,
    label: _done ? 'Dictar otra vez' : 'Terminar',
    child: GestureDetector(
      onTap: _done || _error != null ? _listen : widget.speech.stop,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) => Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.blush,
            border: Border.all(
              color: DesignColors.blush,
              width: 6 + 10 * _pulse.value,
            ),
          ),
          child: child,
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: DesignColors.red,
          ),
          child: Sym(
            DesignIcons.filled(DesignIcons.mic),
            size: 30,
            color: DesignColors.onPrimary,
          ),
        ),
      ),
    ),
  );

  List<Widget> _result() {
    final categories = _type == MovementType.income
        ? Category.incomes
        : Category.expenses;
    return [
      const SizedBox(height: 16),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          TileChip(
            label: _cents == null ? 'Sin monto' : Fmt.money(_cents! / 100),
            onTap: () => setState(() => _editing = true),
          ),
          TileChip(
            label: _type == MovementType.income ? 'Ingreso' : 'Gasto',
            onTap: () => setState(() {
              _type = _type == MovementType.income
                  ? MovementType.expense
                  : MovementType.income;
              _category = _type == MovementType.income
                  ? Category.extra
                  : Category.otros;
            }),
          ),
          TileChip(label: 'Hoy', onTap: () {}),
        ],
      ),
      if (_editing) ...[
        const FieldLabel('Monto'),
        FieldBox(
          key: const ValueKey('dictate-amount'),
          controller: _amount,
          amount: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const FieldLabel('Nota'),
        FieldBox(controller: _note),
      ],
      const FieldLabel('Categoría'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final c in categories)
            DsChip(
              label: c.label,
              selected: c == _category,
              onTap: () => setState(() => _category = c),
            ),
        ],
      ),
      const FieldLabel('Cuenta'),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final a in widget.accounts)
            DsChip(
              label: a.name,
              selected: a.name == _account,
              onTap: () => setState(() => _account = a.name),
            ),
        ],
      ),
    ];
  }
}
