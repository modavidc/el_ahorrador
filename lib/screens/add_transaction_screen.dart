import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/app_database.dart';
import '../data/daos.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key, required this.db});

  final AppDatabase db;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  static const _types = ['Ingreso', 'Gasto', 'Transferencia'];
  static const _currencies = ['S/.', r'$', 'Bs.S'];
  static const _expenseCategories = [
    'Comida',
    'Familia',
    'Educación',
    'Servicios',
    'Transporte',
    'Hogar',
    'Salud',
    'Entretenimiento',
    'Compras',
    'Otro',
  ];
  static const _incomeCategories = [
    'Sueldo',
    'Venta',
    'Intereses',
    'Regalo',
    'Otros ingresos',
  ];
  static const _expenseCategoryIds = {
    'Comida': 'cat_1',
    'Transporte': 'cat_2',
    'Servicios': 'cat_3',
    'Salud': 'cat_4',
    'Entretenimiento': 'cat_5',
    'Educación': 'cat_6',
    'Familia': 'cat_7',
    'Otro': 'cat_8',
  };
  static const _income = Color(0xff438fe5);
  static const _expense = Color(0xffff5d5d);
  static const _transfer = Color(0xff303641);

  int _type = 1;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String _amount = '';
  String _currency = 'S/.';
  bool _showPad = false;
  String? _category;
  bool _saving = false;
  bool _favorite = false;
  String? _repeat;
  String? _attachment;

  final _account = TextEditingController();
  final _note = TextEditingController();
  final _description = TextEditingController();
  final List<TextEditingController> _route = [
    TextEditingController(),
    TextEditingController(),
  ];

  Color get _accent => switch (_type) {
    0 => _income,
    1 => _expense,
    _ => _transfer,
  };
  bool get _isTransfer => _type == 2;

  @override
  void dispose() {
    _account.dispose();
    _note.dispose();
    _description.dispose();
    for (final controller in _route) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff7f8fa),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [
                    _typeTabs(),
                    const SizedBox(height: 20),
                    _dateTime(),
                    const SizedBox(height: 18),
                    _amountField(),
                    const SizedBox(height: 14),
                    if (_isTransfer)
                      _transferRoute()
                    else ...[
                      _categoryField(),
                      _lineField('Cuenta', _account),
                    ],
                    _lineField('Nota', _note),
                    const SizedBox(height: 18),
                    _descriptionField(),
                    const SizedBox(height: 24),
                    _actions(),
                  ],
                ),
              ),
            ),
            if (_showPad) _numberPad(),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
    child: Column(
      children: [
        Container(
          width: 42,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar sin guardar',
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Text(
                _types[_type],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _favorite ? Icons.star_rounded : Icons.star_border_rounded,
                color: _favorite ? Colors.amber.shade700 : null,
              ),
              tooltip: 'Marcar como favorita',
              onPressed: () => setState(() => _favorite = !_favorite),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _typeTabs() => Row(
    children: List.generate(_types.length, (index) {
      final selected = index == _type;
      final color = index == 0
          ? _income
          : index == 1
          ? _expense
          : _transfer;
      return Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: index == 2 ? 0 : 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() {
              _type = index;
              _category = null;
              _showPad = false;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: .08) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? color : const Color(0xffe2e4e8),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Text(
                _types[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? color : Colors.black54,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }),
  );

  Widget _dateTime() => Row(
    children: [
      const SizedBox(
        width: 76,
        child: Text(
          'Fecha',
          style: TextStyle(color: Colors.black54, fontSize: 16),
        ),
      ),
      Expanded(
        child: InkWell(
          onTap: _pickDate,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              '${_date.day}/${_date.month}/${_date.year}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
      InkWell(
        onTap: _pickTime,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _time.format(context),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      IconButton(
        tooltip: _repeat == null ? 'Repetir transacción' : 'Repetir $_repeat',
        onPressed: _chooseRepeat,
        icon: Icon(
          Icons.repeat_rounded,
          color: _repeat == null ? Colors.black38 : _accent,
        ),
      ),
    ],
  );

  Widget _amountField() => InkWell(
    onTap: () {
      FocusScope.of(context).unfocus();
      setState(() => _showPad = true);
    },
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(
          width: 76,
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Importe',
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ),
        ),
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.only(bottom: 7),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _accent, width: 2.5)),
            ),
            child: Text(
              _amount.isEmpty ? '0.00' : '$_currency $_amount',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: _amount.isEmpty ? Colors.black26 : _accent,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _lineField(
    String label,
    TextEditingController controller, {
    String? hint,
    Widget? trailing,
  }) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            onTap: () => setState(() => _showPad = false),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              suffixIcon: trailing,
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xffdfe1e5)),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoryField() => InkWell(
    onTap: _chooseCategory,
    child: Row(
      children: [
        const SizedBox(
          width: 76,
          child: Text(
            'Categoría',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xffdfe1e5))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _category ?? 'Seleccionar',
                    style: TextStyle(
                      color: _category == null
                          ? Colors.black38
                          : Colors.black87,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black45),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _transferRoute() => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xffe3e5e9)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ruta de supertransferencia',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        const Text(
          'El dinero recorrerá las cuentas en este orden.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < _route.length; index++) _routeRow(index),
        TextButton.icon(
          onPressed: _addStop,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Añadir cuenta intermedia'),
        ),
      ],
    ),
  );

  Widget _routeRow(int index) {
    final first = index == 0;
    final last = index == _route.length - 1;
    final label = first
        ? 'Origen'
        : last
        ? 'Destino'
        : 'Escala $index';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: first
                    ? _expense.withValues(alpha: .12)
                    : last
                    ? _income.withValues(alpha: .12)
                    : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(
                first
                    ? Icons.north_east
                    : last
                    ? Icons.south_west
                    : Icons.swap_vert,
                size: 16,
                color: first
                    ? _expense
                    : last
                    ? _income
                    : Colors.black54,
              ),
            ),
            if (!last) Container(width: 2, height: 30, color: Colors.black12),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _route[index],
            onTap: () => setState(() => _showPad = false),
            decoration: InputDecoration(
              labelText: label,
              hintText: 'Nombre de cuenta',
              isDense: true,
            ),
          ),
        ),
        if (!first && !last)
          IconButton(
            onPressed: () => _removeStop(index),
            tooltip: 'Eliminar $label',
            icon: const Icon(
              Icons.remove_circle_outline,
              color: Colors.black38,
            ),
          ),
      ],
    );
  }

  Widget _descriptionField() => Column(
    children: [
      TextField(
        controller: _description,
        onTap: () => setState(() => _showPad = false),
        maxLines: 2,
        decoration: InputDecoration(
          labelText: 'Descripción',
          suffixIcon: IconButton(
            tooltip: 'Adjuntar comprobante',
            onPressed: _chooseAttachment,
            icon: Icon(
              _attachment == null
                  ? Icons.camera_alt_outlined
                  : Icons.image_outlined,
              color: _attachment == null ? null : _accent,
            ),
          ),
          border: const UnderlineInputBorder(),
        ),
      ),
      if (_repeat != null || _attachment != null)
        Wrap(
          spacing: 8,
          children: [
            if (_repeat != null)
              InputChip(
                avatar: const Icon(Icons.schedule_rounded, size: 17),
                label: Text('Repetir $_repeat'),
                onDeleted: () => setState(() => _repeat = null),
              ),
            if (_attachment != null)
              InputChip(
                avatar: const Icon(Icons.receipt_long_outlined, size: 17),
                label: Text(_attachment!),
                onDeleted: () => setState(() => _attachment = null),
              ),
          ],
        ),
    ],
  );

  Widget _actions() => Row(
    children: [
      Expanded(
        child: FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _accent,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _saving ? 'Guardando…' : 'Guardar',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      const SizedBox(width: 10),
      OutlinedButton(
        onPressed: _saving
            ? null
            : () async {
                if (await _save()) _resetForNext();
              },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text('Continuar'),
      ),
    ],
  );

  Widget _numberPad() => Material(
    color: const Color(0xff25272d),
    child: SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Dinero', style: TextStyle(color: Colors.white70)),
              ),
              ..._currencies.map(
                (item) => TextButton(
                  onPressed: () => setState(() => _currency = item),
                  child: Text(
                    item,
                    style: TextStyle(
                      color: item == _currency ? Colors.white : Colors.white54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showPad = false),
                tooltip: 'Ocultar teclado',
                icon: const Icon(Icons.keyboard_hide, color: Colors.white70),
              ),
            ],
          ),
          for (final row in const [
            ['1', '2', '3', 'DEL'],
            ['4', '5', '6', ''],
            ['7', '8', '9', ''],
            ['00', '0', '.', 'DONE'],
          ])
            Row(
              children: row
                  .map(
                    (key) => Expanded(
                      child: InkWell(
                        onTap: key.isEmpty ? null : () => _key(key),
                        child: SizedBox(
                          height: 46,
                          child: Center(
                            child: key == 'DEL'
                                ? const Icon(
                                    Icons.backspace_outlined,
                                    color: Colors.white,
                                  )
                                : Text(
                                    key == 'DONE' ? 'Finalizar' : key,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    ),
  );

  void _key(String key) => setState(() {
    if (key == 'DONE') {
      _showPad = false;
      return;
    }
    if (key == 'DEL') {
      if (_amount.isNotEmpty) {
        _amount = _amount.substring(0, _amount.length - 1);
      }
      return;
    }
    if (key == '.' && _amount.contains('.')) return;
    if (_amount.contains('.') && _amount.split('.').last.length >= 2) return;
    if (key == '00' && _amount.isEmpty) {
      _amount = '0';
      return;
    }
    if (_amount == '0' && key != '.') {
      _amount = key;
      return;
    }
    _amount = key == '.' && _amount.isEmpty ? '0.' : '$_amount$key';
  });

  void _addStop() =>
      setState(() => _route.insert(_route.length - 1, TextEditingController()));
  void _removeStop(int index) {
    final removed = _route.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _date = value);
  }

  Future<void> _pickTime() async {
    final value = await showTimePicker(context: context, initialTime: _time);
    if (value != null && mounted) setState(() => _time = value);
  }

  Future<void> _chooseRepeat() async {
    final value = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Repetir transacción',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'La programación se guardará como parte del registro.',
              ),
            ),
            for (final item in const ['cada semana', 'cada mes', 'cada año'])
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: Text(item),
                trailing: _repeat == item
                    ? Icon(Icons.check, color: _accent)
                    : null,
                onTap: () => Navigator.pop(context, item),
              ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => _repeat = value);
  }

  Future<void> _chooseAttachment() async {
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Añadir comprobante',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Selecciona cómo llegará el documento al flujo OCR.',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Tomar foto'),
              subtitle: const Text(
                'Maqueta de captura: integración de cámara pendiente',
              ),
              onTap: () => Navigator.pop(context, 'Foto del comprobante'),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Elegir captura'),
              subtitle: const Text(
                'Maqueta de galería: selector de archivo pendiente',
              ),
              onTap: () => Navigator.pop(context, 'Captura para OCR'),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => _attachment = value);
  }

  Future<void> _chooseCategory() async {
    final values = _type == 0 ? _incomeCategories : _expenseCategories;
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                'Categoría',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...values.map(
              (item) => ListTile(
                title: Text(item),
                trailing: item == _category
                    ? Icon(Icons.check, color: _accent)
                    : null,
                onTap: () => Navigator.pop(context, item),
              ),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) setState(() => _category = value);
  }

  bool _validate() {
    if ((double.tryParse(_amount) ?? 0) <= 0) {
      return _error('Ingresa un importe mayor que cero.');
    }
    if (_isTransfer) {
      if (_route.any((item) => item.text.trim().isEmpty)) {
        return _error('Completa todas las cuentas de la ruta.');
      }
      if (_route.map((item) => item.text.trim().toLowerCase()).toSet().length !=
          _route.length) {
        return _error('Cada punto de la ruta debe ser una cuenta diferente.');
      }
    } else {
      if (_category == null) return _error('Selecciona una categoría.');
      if (_account.text.trim().isEmpty) return _error('Ingresa una cuenta.');
    }
    return true;
  }

  bool _error(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return false;
  }

  Future<void> _submit() async {
    if (await _save() && mounted) Navigator.pop(context, true);
  }

  Future<bool> _save() async {
    if (!_validate()) return false;
    setState(() => _saving = true);
    try {
      final route = _route.map((item) => item.text.trim()).toList();
      final extraNotes = _description.text.trim();
      final routeNote = _isTransfer ? 'Ruta: ${route.join(' → ')}' : '';
      final routeData = _isTransfer
          ? '[supertransfer:v1] ${jsonEncode({'accounts': route})}'
          : '';
      final notes = [
        routeNote,
        routeData,
        extraNotes,
        if (_favorite) 'Favorita',
        if (_repeat != null) 'Repetición: $_repeat',
        if (_attachment != null) 'Adjunto: $_attachment',
      ].where((item) => item.isNotEmpty).join('\n');
      final dateTime = DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      );
      await widget.db.insertExpenseFromParser(
        id: const Uuid().v4(),
        dateEpochMs: dateTime.millisecondsSinceEpoch,
        amountCents: (double.parse(_amount) * 100).round(),
        currency: switch (_currency) {
          r'$' => 'USD',
          'Bs.S' => 'VES',
          _ => 'PEN',
        },
        categoryId: _type == 1 ? _expenseCategoryIds[_category] : null,
        account: _isTransfer ? route.first : _account.text.trim(),
        vendor: _isTransfer ? route.last : _category,
        description: _note.text.trim().isEmpty
            ? (_isTransfer ? 'Transferencia a ${route.last}' : _category)
            : _note.text.trim(),
        notes: notes.isEmpty ? null : notes,
        sourceApp: _isTransfer ? 'Supertransferencia' : 'Manual',
        transactionType: _type == 0
            ? 'income'
            : _type == 1
            ? 'expense'
            : 'transfer',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción guardada'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (_) {
      if (mounted) {
        _error('No se pudo guardar la transacción. Inténtalo de nuevo.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _resetForNext() => setState(() {
    _amount = '';
    _note.clear();
    _description.clear();
    _attachment = null;
    _showPad = true;
  });
}
