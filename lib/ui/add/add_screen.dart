import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../core/app_clock.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';
import '../../features/ledger/entry_form.dart';
import '../../features/ledger/ledger.dart';
import '../../theme/design_tokens.dart';
import '../format.dart';
import '../widgets.dart';

/// "Nueva transacción" of the v1 prototype (also used to edit a movement):
/// Ingreso / Gasto / Transf., natural-language box and the 52px form.
class AddScreen extends StatefulWidget {
  const AddScreen({
    super.key,
    required this.db,
    required this.accounts,
    this.editing,
  });

  final AppDatabase db;
  final List<LedgerAccount> accounts;
  final Movement? editing;

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final _nl = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  MovementType _type = MovementType.expense;
  late DateTime _date;
  String? _category;
  String? _account;
  String? _toAccount;
  bool _yape = false;
  String _hint = '';
  bool _hintIsError = false;
  List<Category> _categories = const [];

  List<String> get _accountNames => [for (final a in widget.accounts) a.name];

  List<String> _categoriesFor(MovementType type) => {
    for (final c in _categories)
      if (isIncomeCategory(c.name) == (type == MovementType.income)) c.name,
  }.toList();

  @override
  void initState() {
    super.initState();
    final m = widget.editing;
    _date = m?.at ?? AppClock.now();
    if (m != null) {
      _type = m.type;
      _amount.text = m.amount.toStringAsFixed(2);
      _note.text = m.note;
      _category = m.type == MovementType.transfer ? null : m.category;
      _account = m.account;
      _toAccount = m.toAccount;
      _yape = m.method == 'Yape';
    } else {
      _account = _accountNames.isEmpty ? null : _accountNames.first;
    }
    (widget.db.select(
      widget.db.categories,
    )..orderBy([(c) => OrderingTerm.asc(c.order)])).get().then((rows) {
      if (!mounted) return;
      setState(() {
        _categories = rows;
        final options = _categoriesFor(_type);
        if (_type != MovementType.transfer && !options.contains(_category)) {
          _category = options.contains('Comida')
              ? 'Comida'
              : options.firstOrNull;
        }
      });
    });
  }

  @override
  void dispose() {
    _nl.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _setType(MovementType type) => setState(() {
    _type = type;
    if (type == MovementType.transfer) {
      _toAccount ??= _accountNames.where((a) => a != _account).firstOrNull;
    } else {
      final options = _categoriesFor(type);
      if (!options.contains(_category)) _category = options.firstOrNull;
    }
  });

  void _interpret() {
    final text = _nl.text.trim();
    if (text.isEmpty) return;
    final result = interpretEntry(
      text,
      categories: [for (final c in _categories) c.name],
      accounts: widget.accounts,
    );
    setState(() {
      _type = result.type;
      if (result.amount != null) _amount.text = result.amount!;
      _category = result.category;
      if (result.account.isNotEmpty) _account = result.account;
      _note.text = result.note;
      _yape = result.yape;
      _hint = result.hint;
      _hintIsError = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(
        () => _date = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _date.hour,
          _date.minute,
        ),
      );
    }
  }

  String? _accountId(String? name) =>
      widget.accounts.where((a) => a.name == name).firstOrNull?.id;

  Future<void> _delete() async {
    final m = widget.editing!;
    await _deleteRows(m);
    if (!mounted) return;
    Navigator.of(context).pop('Transacción eliminada');
  }

  Future<void> _deleteRows(Movement m) async {
    final db = widget.db;
    if (m.type == MovementType.transfer) {
      await (db.delete(
        db.expenses,
      )..where((e) => e.origination.equals(m.id))).go();
    } else {
      await db.deleteExpense(m.id);
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amount == null || amount <= 0) {
      setState(() {
        _hint = 'Ingresa un monto válido.';
        _hintIsError = true;
      });
      return;
    }
    final cents = (amount * 100).round();
    final db = widget.db;
    final editing = widget.editing;
    final id = editing?.id ?? const Uuid().v4();
    final note = _note.text.trim();
    final category = _categories.where((c) => c.name == _category).firstOrNull;
    try {
      await db.transaction(() async {
        // Editing an income/expense updates the same row, so a captured
        // movement keeps its image, merchant and OCR data.
        if (editing != null &&
            editing.type != MovementType.transfer &&
            _type != MovementType.transfer) {
          final original = await (db.select(
            db.expenses,
          )..where((e) => e.id.equals(editing.id))).getSingle();
          final isManual = const {
            null,
            'Manual',
            'Yape',
          }.contains(original.sourceApp);
          await (db.update(
            db.expenses,
          )..where((e) => e.id.equals(editing.id))).write(
            ExpensesCompanion(
              date: Value(_date.millisecondsSinceEpoch),
              amountCents: Value(_type == MovementType.income ? cents : -cents),
              categoryId: Value(category?.id),
              subcategoryId: original.categoryId == category?.id
                  ? const Value.absent()
                  : const Value(null),
              accountId: Value(_accountId(_account)),
              account: Value(_account),
              vendor: category == null
                  ? Value(_category)
                  : const Value.absent(),
              description: Value(note.isEmpty ? null : note),
              sourceApp: isManual
                  ? Value(_yape ? 'Yape' : 'Manual')
                  : const Value.absent(),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
          return;
        }
        if (editing != null) await _deleteRows(editing);
        if (_type == MovementType.transfer) {
          final from = _accountId(_account);
          final to = _accountId(_toAccount);
          if (from == null || to == null || from == to) {
            throw ArgumentError('Elige dos cuentas distintas.');
          }
          await db.insertTransfer(
            id: id,
            dateEpochMs: _date.millisecondsSinceEpoch,
            amountCents: cents,
            currency: 'PEN',
            sourceAccountId: from,
            destinationAccountId: to,
            sourceAccount: _account,
            destinationAccount: _toAccount,
            description: note.isEmpty ? null : note,
          );
        } else {
          await db.insertExpenseFromParser(
            id: id,
            dateEpochMs: _date.millisecondsSinceEpoch,
            amountCents: _type == MovementType.income ? cents : -cents,
            currency: 'PEN',
            categoryId: category?.id,
            accountId: _accountId(_account),
            account: _account,
            vendor: category == null ? _category : null,
            description: note.isEmpty ? null : note,
            sourceApp: _yape ? 'Yape' : 'Manual',
          );
        }
      });
    } on ArgumentError catch (error) {
      setState(() {
        _hint = '${error.message}';
        _hintIsError = true;
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop('Transacción guardada');
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing != null;
    final amountColor = _type == MovementType.income
        ? DesignColors.income
        : DesignColors.expense;
    return Scaffold(
      backgroundColor: DesignColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: DesignColors.surfaceCard,
          ),
          ColoredBox(
            color: DesignColors.primary,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Sym(
                          DesignIcons.arrowBack,
                          size: 24,
                          color: DesignColors.onPrimary,
                        ),
                      ),
                      const SizedBox(width: DesignSpacing.md),
                      Expanded(
                        child: Text(
                          editing ? 'Editar transacción' : 'Nueva transacción',
                          style: DesignText.headline.copyWith(
                            color: DesignColors.onPrimary,
                          ),
                        ),
                      ),
                      if (editing)
                        Semantics(
                          button: true,
                          label: 'Eliminar transacción',
                          child: GestureDetector(
                            onTap: _delete,
                            child: const Sym(
                              DesignIcons.close,
                              size: 24,
                              color: DesignColors.onPrimary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    for (final (type, label) in const [
                      (MovementType.income, 'Ingreso'),
                      (MovementType.expense, 'Gasto'),
                      (MovementType.transfer, 'Transf.'),
                    ])
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _setType(type),
                          child: Opacity(
                            opacity: _type == type ? 1 : 0.7,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    width: 3,
                                    color: _type == type
                                        ? DesignColors.onPrimary
                                        : Colors.transparent,
                                  ),
                                ),
                              ),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: DesignText.body.copyWith(
                                  color: DesignColors.onPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                12,
                12,
                12,
                12 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                if (!editing) _naturalLanguageCard(),
                if (editing && _hint.isNotEmpty) ...[
                  _hintBox(),
                  const SizedBox(height: DesignSpacing.md),
                ],
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: DesignColors.surfaceCard,
                    borderRadius: BorderRadius.circular(DesignRadius.lg),
                  ),
                  child: Column(
                    children: [
                      _row(
                        'Fecha',
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _pickDate,
                          child: Text(
                            '${Fmt.twoDigits(_date.day)}.'
                            '${Fmt.twoDigits(_date.month)}.${_date.year} '
                            '(${Fmt.weekday(_date)})',
                            style: DesignText.body,
                          ),
                        ),
                      ),
                      _row(
                        'Monto',
                        Row(
                          children: [
                            Text(
                              'S/.',
                              style: DesignText.body.copyWith(
                                color: DesignColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: DesignSpacing.xs),
                            Expanded(
                              child: TextField(
                                controller: _amount,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                style: DesignText.headline.copyWith(
                                  color: amountColor,
                                ),
                                decoration: InputDecoration.collapsed(
                                  hintText: '0.00',
                                  hintStyle: DesignText.headline.copyWith(
                                    color: DesignColors.textTertiary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_type == MovementType.transfer)
                        _row(
                          'Destino',
                          _select(
                            value: _toAccount,
                            options: _accountNames,
                            onChanged: (v) => setState(() => _toAccount = v),
                          ),
                        )
                      else
                        _row(
                          'Categoría',
                          _select(
                            value: _category,
                            options: _categoriesFor(_type),
                            onChanged: (v) => setState(() => _category = v),
                          ),
                        ),
                      _row(
                        'Cuenta',
                        _select(
                          value: _account,
                          options: _accountNames,
                          onChanged: (v) => setState(() => _account = v),
                        ),
                      ),
                      _row(
                        'Nota',
                        TextField(
                          controller: _note,
                          style: DesignText.body,
                          decoration: InputDecoration.collapsed(
                            hintText: 'Descripción',
                            hintStyle: DesignText.body.copyWith(
                              color: DesignColors.textTertiary,
                            ),
                          ),
                        ),
                        last: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: DesignSpacing.lg),
                _primaryButton('Guardar', _save, height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _naturalLanguageCard() => Container(
    margin: const EdgeInsets.only(bottom: DesignSpacing.md),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: DesignColors.surfaceCard,
      border: Border.all(color: DesignColors.primarySoft),
      borderRadius: BorderRadius.circular(DesignRadius.lg),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Sym(
              DesignIcons.autoAwesome,
              size: 16,
              color: DesignColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Escribe en lenguaje natural',
              style: DesignText.captionStrong.copyWith(
                color: DesignColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: DesignSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: DesignColors.inputFill,
            border: Border.all(color: DesignColors.borderInput),
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
          child: TextField(
            controller: _nl,
            minLines: 2,
            maxLines: 2,
            style: DesignText.body,
            decoration: InputDecoration.collapsed(
              hintText: 'ej. rappi pizza 42 soles con la visa',
              hintStyle: DesignText.body.copyWith(
                color: DesignColors.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: DesignSpacing.sm),
        _primaryButton('Interpretar', _interpret, height: 44, small: true),
        if (_hint.isNotEmpty) ...[
          const SizedBox(height: DesignSpacing.sm),
          _hintBox(),
        ],
      ],
    ),
  );

  Widget _hintBox() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
    decoration: BoxDecoration(
      color: _hintIsError ? DesignColors.primarySoft : DesignColors.successSoft,
      borderRadius: BorderRadius.circular(DesignRadius.sm),
    ),
    child: Text(
      _hint,
      style: DesignText.caption.copyWith(
        color: _hintIsError ? DesignColors.expense : DesignColors.success,
      ),
    ),
  );

  Widget _primaryButton(
    String label,
    VoidCallback onTap, {
    required double height,
    bool small = false,
  }) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DesignColors.primary,
          borderRadius: BorderRadius.circular(DesignRadius.md),
        ),
        child: Text(
          label,
          style: (small ? DesignText.bodyStrong : DesignText.headline).copyWith(
            color: DesignColors.onPrimary,
          ),
        ),
      ),
    ),
  );

  Widget _row(String label, Widget value, {bool last = false}) => Container(
    height: 52,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: DesignColors.borderSubtle)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: DesignText.label.copyWith(color: DesignColors.textTertiary),
          ),
        ),
        Expanded(child: value),
      ],
    ),
  );

  Widget _select({
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonHideUnderline(
    child: DropdownButton<String>(
      value: options.contains(value) ? value : null,
      isExpanded: true,
      icon: const Sym(DesignIcons.expandMore, size: 22),
      style: DesignText.body,
      dropdownColor: DesignColors.surfaceCard,
      items: [
        for (final o in options)
          DropdownMenuItem(
            value: o,
            child: Text(o, style: DesignText.body),
          ),
      ],
      onChanged: onChanged,
    ),
  );
}
