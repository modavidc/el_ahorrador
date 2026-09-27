import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';
import 'package:el_ahorrador/features/ledger/domain/ledger_repository.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/legacy_widgets.dart';

/// What the manual sheet registered, for the toast and the "Registrado"
/// pill.
final class EntryResult {
  const EntryResult(this.id, this.message);

  final String id;
  final String message;
}

/// Opens the manual entry sheet (Gasto · Ingreso · Transferencia).
Future<EntryResult?> showEntrySheet(
  BuildContext context, {
  required LedgerRepository repository,
  required List<LedgerAccount> accounts,
  required List<Movement> movements,
}) => showPaperSheet<EntryResult>(
  context,
  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
  builder: (_) => EntrySheet(
    repository: repository,
    accounts: accounts,
    movements: movements,
  ),
);

/// Manual entry of v3: type segment, big amount, frequent entries, category
/// grid, a folded "Yape · Hoy · Sin nota" row and its own keypad, with
/// Guardar always visible at the bottom.
class EntrySheet extends StatefulWidget {
  const EntrySheet({
    super.key,
    required this.repository,
    required this.accounts,
    required this.movements,
  });

  final LedgerRepository repository;
  final List<LedgerAccount> accounts;
  final List<Movement> movements;

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  MovementType _type = MovementType.expense;
  String _amount = '';
  String _category = Category.expenses.first.label;
  late String _account = _defaultAccount;
  String? _toAccount;
  bool _yesterday = false;
  bool _more = false;
  bool _saving = false;
  String? _error;
  final _note = TextEditingController();

  List<String> get _accountNames => [for (final a in widget.accounts) a.name];

  /// Yape when the user has it (the prototype's default), else the first
  /// account.
  String get _defaultAccount => _accountNames.firstWhere(
    (n) => n.toLowerCase() == 'yape',
    orElse: () => _accountNames.isEmpty ? '' : _accountNames.first,
  );

  double get _value => double.tryParse(_amount) ?? 0;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _setType(MovementType type) => setState(() {
    _type = type;
    _category = type == MovementType.income
        ? Category.incomes.first.label
        : Category.expenses.first.label;
    _toAccount = null;
    _error = null;
  });

  /// Keypad: at most 2 decimals and 8 characters.
  void _press(String key) {
    HapticFeedback.selectionClick();
    final c = _amount;
    String next;
    if (key == 'del') {
      next = c.isEmpty ? c : c.substring(0, c.length - 1);
    } else if ((key == '.' && c.contains('.')) ||
        (c.contains('.') && c.split('.')[1].length >= 2) ||
        c.length >= 8) {
      next = c;
    } else {
      next = key == '.' && c.isEmpty ? '0.' : c + key;
    }
    setState(() {
      _amount = next;
      _error = null;
    });
  }

  void _useFrequent(Movement m) => setState(() {
    _amount = _plain(m.amount);
    _note.text = m.note;
    _category = m.category;
    if (_accountNames.contains(m.account)) _account = m.account;
  });

  static String _plain(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(2);

  Future<void> _save() async {
    if (_value <= 0 || _saving) return;
    final transfer = _type == MovementType.transfer;
    final to = _toAccount;
    if (transfer && (to == null || to == _account)) {
      setState(() => _error = 'Elige la cuenta de destino.');
      return;
    }
    setState(() => _saving = true);
    final now = AppClock.now();
    final at = _yesterday ? now.subtract(const Duration(days: 1)) : now;
    final cents = (_value * 100).round();
    try {
      final id = await widget.repository.addEntry(
        type: _type,
        amountCents: cents,
        account: _account,
        category: transfer ? null : _category,
        toAccount: to,
        note: _note.text.trim().isEmpty
            ? (transfer ? '$_account → $to' : null)
            : _note.text,
        at: at,
      );
      if (!mounted) return;
      final kind = switch (_type) {
        MovementType.expense => 'Gasto',
        MovementType.income => 'Ingreso',
        MovementType.transfer => 'Transferencia',
      };
      Navigator.of(
        context,
      ).pop(EntryResult(id, '$kind de ${Fmt.money(_value)} registrado'));
    } on ArgumentError catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfer = _type == MovementType.transfer;
    final frequents = transfer
        ? const <Movement>[]
        : frequentEntries(widget.movements, _type);
    final categories = _type == MovementType.income
        ? [for (final c in Category.incomes) c.label]
        : [for (final c in Category.expenses) c.label];
    final summary = [
      if (!transfer) _account,
      _yesterday ? 'Ayer' : 'Hoy',
      _note.text.trim().isEmpty ? 'Sin nota' : _note.text.trim(),
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Segmented(
                  labels: const ['Gasto', 'Ingreso', 'Transferencia'],
                  selected: _type.index == 0
                      ? 1
                      : _type.index == 1
                      ? 0
                      : 2,
                  height: 38,
                  onSelected: (i) => _setType(
                    const [
                      MovementType.expense,
                      MovementType.income,
                      MovementType.transfer,
                    ][i],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'S/',
                      style: DesignText.currency.copyWith(
                        color: DesignColors.ink2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _amount.isEmpty ? '0' : _amount,
                          style: DesignText.amountInput.copyWith(
                            color: _amount.isEmpty
                                ? DesignColors.inkFaint
                                : DesignColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (frequents.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OverflowBox(
                      maxWidth: MediaQuery.sizeOf(context).width,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                        itemCount: frequents.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 6),
                        itemBuilder: (_, i) => _FrequentChip(
                          movement: frequents[i],
                          onTap: () => _useFrequent(frequents[i]),
                        ),
                      ),
                    ),
                  ),
                ],
                if (transfer) ...[
                  _Label('DESDE'),
                  _AccountChips(
                    names: _accountNames,
                    selected: _account,
                    onSelected: (n) => setState(() {
                      _account = n;
                      if (_toAccount == n) _toAccount = null;
                    }),
                  ),
                  _Label('HACIA', top: 10),
                  _AccountChips(
                    names: [
                      for (final n in _accountNames)
                        if (n != _account) n,
                    ],
                    selected: _toAccount,
                    onSelected: (n) => setState(() => _toAccount = n),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1.35,
                    children: [
                      for (final name in categories)
                        _CategoryCell(
                          name: name,
                          selected: _category == name,
                          onTap: () => setState(() => _category = name),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _MoreRow(
                  summary: summary,
                  open: _more,
                  onTap: () => setState(() => _more = !_more),
                ),
                if (_more) ...[
                  if (!transfer) ...[
                    const SizedBox(height: 10),
                    _AccountChips(
                      names: _accountNames,
                      selected: _account,
                      onSelected: (n) => setState(() => _account = n),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      DsChip(
                        label: 'Hoy',
                        selected: !_yesterday,
                        onTap: () => setState(() => _yesterday = false),
                      ),
                      const SizedBox(width: 6),
                      DsChip(
                        label: 'Ayer',
                        selected: _yesterday,
                        onTap: () => setState(() => _yesterday = true),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            color: DesignColors.card,
                            borderRadius: BorderRadius.circular(
                              DesignRadius.pill,
                            ),
                          ),
                          child: TextField(
                            controller: _note,
                            onChanged: (_) => setState(() {}),
                            style: DesignText.body14,
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Nota',
                              hintStyle: DesignText.body14.copyWith(
                                color: DesignColors.ink2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: DesignText.label13Semi.copyWith(
                      color: DesignColors.red,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _Keypad(onPress: _press),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SheetButton(
          label: _value > 0
              ? 'Guardar ${Fmt.money(_value)}'
              : 'Escribe el monto',
          color: _value > 0 ? DesignColors.red : DesignColors.disabled,
          onTap: _value > 0 ? _save : null,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.top = 14});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: top, bottom: 6),
    child: Text(
      text,
      style: DesignText.smallBold.copyWith(color: DesignColors.ink2),
    ),
  );
}

class _AccountChips extends StatelessWidget {
  const _AccountChips({
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final List<String> names;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final n in names)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 36,
          ),
          child: DsChip(
            label: n,
            selected: n == selected,
            padding: 12,
            onTap: () => onSelected(n),
          ),
        ),
    ],
  );
}

class _FrequentChip extends StatelessWidget {
  const _FrequentChip({required this.movement, required this.onTap});

  final Movement movement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
        decoration: BoxDecoration(
          color: DesignColors.card,
          borderRadius: BorderRadius.circular(DesignRadius.pill),
          boxShadow: DesignShadows.chip,
        ),
        child: Row(
          children: [
            const Sym(DesignIcons.bolt, size: 16, color: DesignColors.red),
            const SizedBox(width: 6),
            Text(
              '${movement.note} · ${Fmt.money0(movement.amount)}',
              style: DesignText.label13Semi,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
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
          decoration: BoxDecoration(
            color: selected ? DesignColors.ink : DesignColors.chip,
            borderRadius: BorderRadius.circular(DesignRadius.tile),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Sym(CategoryStyle.forName(name).icon, size: 20, color: fg),
              const SizedBox(height: 3),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignText.smallBold.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
    required this.summary,
    required this.open,
    required this.onTap,
  });

  final String summary;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    expanded: open,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: DesignColors.card,
          borderRadius: BorderRadius.circular(DesignRadius.button),
        ),
        child: Row(
          children: [
            const Sym(DesignIcons.tune, size: 18, color: DesignColors.ink2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DesignText.label13Semi,
              ),
            ),
            Sym(
              open ? DesignIcons.expandLess : DesignIcons.expandMore,
              size: 20,
              color: DesignColors.ink2,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onPress});

  final ValueChanged<String> onPress;

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '.',
    '0',
    'del',
  ];

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 4,
    crossAxisSpacing: 4,
    childAspectRatio: 2.5,
    children: [
      for (final k in _keys)
        _Key(key: ValueKey('keypad-$k'), value: k, onPress: onPress),
    ],
  );
}

/// Key that sinks (scale .94 and beige) while pressed.
class _Key extends StatefulWidget {
  const _Key({super.key, required this.value, required this.onPress});

  final String value;
  final ValueChanged<String> onPress;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: widget.value == 'del' ? 'Borrar' : widget.value,
    excludeSemantics: true,
    child: GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onPress(widget.value);
      },
      child: AnimatedScale(
        scale: _down ? .94 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _down ? DesignColors.lineStrong : null,
            borderRadius: BorderRadius.circular(DesignRadius.md),
          ),
          child: widget.value == 'del'
              ? const Sym(DesignIcons.backspace, size: 22)
              : Text(widget.value, style: DesignText.keypad),
        ),
      ),
    ),
  );
}

/// Detail of a movement: meta, note, amount, origin, category chips and
/// Eliminar · Repetir · Listo.
class MovementDetailSheet extends StatelessWidget {
  const MovementDetailSheet({
    super.key,
    required this.movement,
    required this.onCategory,
    required this.onDelete,
    required this.onRepeat,
  });

  final Movement movement;
  final ValueChanged<String> onCategory;
  final VoidCallback onDelete;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final today = AppClock.now();
    final t = DateTime(today.year, today.month, today.day);
    final when = m.day == t
        ? 'Hoy'
        : m.day == DateTime(t.year, t.month, t.day - 1)
        ? 'Ayer'
        : '${m.day.day} ${Fmt.months[m.day.month - 1].toLowerCase()}';
    final categories = m.type == MovementType.income
        ? [for (final c in Category.incomes) c.label]
        : [for (final c in Category.expenses) c.label, Category.otros.label];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$when · ${m.account}',
            style: DesignText.label13Semi.copyWith(color: DesignColors.ink2),
          ),
          const SizedBox(height: 4),
          Text(m.note, style: DesignText.sheetTitle),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              signedAmount(m),
              style: DesignText.style(
                44,
                FontWeight.w800,
                letterSpacing: -.03,
              ).copyWith(color: movementAmountColor(m)),
            ),
          ),
          if (m.origin.label case final origin?) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: DesignColors.tile,
                borderRadius: BorderRadius.circular(DesignRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Sym(DesignIcons.autoAwesome, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Vía ${origin.toLowerCase()}',
                    style: DesignText.smallBold,
                  ),
                ],
              ),
            ),
          ],
          if (m.type != MovementType.transfer) ...[
            const SizedBox(height: 16),
            Text(
              'Categoría',
              style: DesignText.label13Bold.copyWith(color: DesignColors.ink2),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final name in categories)
                  _IconChip(
                    name: name,
                    selected:
                        CategoryStyle.forName(m.category) ==
                            CategoryStyle.forName(name) &&
                        (m.category == name ||
                            !categories.contains(m.category)),
                    onTap: () => onCategory(name),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OutlineButton(
                  icon: DesignIcons.delete,
                  label: 'Eliminar',
                  color: DesignColors.red,
                  onTap: onDelete,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutlineButton(
                  icon: DesignIcons.contentCopy,
                  label: 'Repetir',
                  color: DesignColors.ink,
                  onTap: onRepeat,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SheetButton.ink(
                  label: 'Listo',
                  height: 52,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
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
            color: selected ? DesignColors.ink : DesignColors.chip,
            borderRadius: BorderRadius.circular(DesignRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sym(CategoryStyle.forName(name).icon, size: 16, color: fg),
              const SizedBox(width: 4),
              Text(name, style: DesignText.label13Bold.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(DesignRadius.lg),
          border: Border.all(color: DesignColors.lineStrong, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Sym(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(label, style: DesignText.rowAmount.copyWith(color: color)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Streak: days in a row, best streak, this week and "Registrar ahora".
class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key, required this.movements, required this.onAdd});

  final List<Movement> movements;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final now = AppClock.now();
    final today = DateTime(now.year, now.month, now.day);
    final streak = streakDays(movements, now);
    final best = bestStreak(movements);
    final days = {for (final m in movements) m.day};
    final monday = today.subtract(Duration(days: today.weekday - 1));
    const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconTile(
              icon: DesignIcons.filled(DesignIcons.localFireDepartment),
              color: DesignColors.red,
              background: DesignColors.blush,
              size: 60,
              iconSize: 36,
              radius: 20,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$streak ${streak == 1 ? 'día' : 'días'}',
                    style: DesignText.style(
                      36,
                      FontWeight.w800,
                      letterSpacing: -.03,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tu mejor racha: $best ${best == 1 ? 'día' : 'días'}',
                    style: DesignText.body14.copyWith(color: DesignColors.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: _StreakDay(
                  letter: letters[i],
                  day: monday.add(Duration(days: i)),
                  today: today,
                  done: days.contains(monday.add(Duration(days: i))),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Cuenta un día cuando registras al menos un movimiento, a mano o '
          'con captura.',
          style: DesignText.body14.copyWith(
            color: DesignColors.ink2,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        SheetButton(label: 'Registrar ahora', onTap: onAdd),
      ],
    );
  }
}

class _StreakDay extends StatelessWidget {
  const _StreakDay({
    required this.letter,
    required this.day,
    required this.today,
    required this.done,
  });

  final String letter;
  final DateTime day;
  final DateTime today;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final future = day.isAfter(today);
    return Column(
      children: [
        Text(
          letter,
          style: DesignText.smallBold.copyWith(color: DesignColors.ink2),
        ),
        const SizedBox(height: 6),
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? DesignColors.red
                : future
                ? DesignColors.chip
                : DesignColors.blush,
            shape: BoxShape.circle,
          ),
          child: Sym(
            done ? DesignIcons.check : DesignIcons.localFireDepartment,
            size: 20,
            color: done
                ? DesignColors.card
                : future
                ? DesignColors.inkFaint
                : DesignColors.red,
          ),
        ),
      ],
    );
  }
}

/// "Prueba la función principal": the three steps of sharing a receipt.
class TryShareSheet extends StatelessWidget {
  const TryShareSheet({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Registra sin escribir',
        style: DesignText.style(24, FontWeight.w800, letterSpacing: -.03),
      ),
      const SizedBox(height: 6),
      Text(
        'Pagas con Yape, compartes el comprobante y se registra solo.',
        style: DesignText.body14.copyWith(
          color: DesignColors.ink2,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 16),
      for (final (n, title, subtitle) in const [
        ('1', 'Paga', 'Con Yape, Plin o tu banco.'),
        ('2', 'Compartir', 'En el comprobante, toca Compartir.'),
        ('3', 'El Ahorrador', 'Elige la app y listo: queda registrado.'),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PaperCard(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: DesignColors.blush,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    n,
                    style: DesignText.rowAmountStrong.copyWith(
                      color: DesignColors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: DesignText.row),
                      Text(
                        subtitle,
                        style: DesignText.small.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 6),
      SheetButton.ink(
        label: 'Entendido',
        onTap: () => Navigator.of(context).pop(),
      ),
    ],
  );
}
