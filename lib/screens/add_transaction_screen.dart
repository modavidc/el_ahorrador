import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/app_database.dart';
import '../data/daos.dart';

class AddTransactionScreen extends StatefulWidget {
  final AppDatabase db;

  const AddTransactionScreen({super.key, required this.db});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  int _selectedTypeIndex = 1; // 0: Ingreso, 1: Gasto, 2: Transferencia
  final List<String> _transactionTypes = ['Ingreso', 'Gasto', 'Transferencia'];

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  String _amount = '';
  String _selectedCurrency = 'S/.';
  final List<String> _currencies = ['\$', 'S/.', 'Bs.S'];
  bool _showKeyboard = false; // Deshabilitado al inicio
  String? _selectedCategory;
  String? _selectedSubcategory;

  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void dispose() {
    _categoryController.dispose();
    _accountController.dispose();
    _noteController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Contenido scrollable
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // Tabs de tipo de transacción
                  _buildTransactionTypeTabs(),

                  const SizedBox(height: 12),

                  // Fecha y hora
                  _buildDateTimeRow(),

                  const SizedBox(height: 12),

                  // Importe
                  _buildAmountField(),

                  const SizedBox(height: 16),

                  // Categoría (con selector)
                  _buildCategoryField(),

                  const SizedBox(height: 12),

                  // Cuenta
                  _buildSimpleField('Cuenta', _accountController),

                  const SizedBox(height: 12),

                  // Título/Detalle con IA
                  _buildSimpleField(
                    'Título/Detalle',
                    _noteController,
                    showAI: true,
                  ),

                  const SizedBox(height: 16),

                  // Notas adicionales con cámara
                  _buildDescriptionField(),

                  const SizedBox(height: 20),

                  // Botones Guardar y Continuar
                  _buildActionButtons(),

                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Teclado numérico personalizado
          if (_showKeyboard) _buildCustomKeyboard(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        _transactionTypes[_selectedTypeIndex],
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.star_border, color: Colors.black),
          onPressed: () {
            // TODO: Marcar como favorito
          },
        ),
      ],
    );
  }

  Widget _buildTransactionTypeTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(_transactionTypes.length, (index) {
          final isSelected = index == _selectedTypeIndex;
          final isIncome = index == 0;
          final isExpense = index == 1;

          Color selectedColor = Colors.grey[800]!;
          if (isIncome) selectedColor = Colors.blue;
          if (isExpense) selectedColor = Colors.red;

          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: 'Tipo de transacción: ${_transactionTypes[index]}',
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTypeIndex = index;
                  });
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  margin: EdgeInsets.only(
                    right: index < _transactionTypes.length - 1 ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? selectedColor : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? selectedColor : Colors.grey[300]!,
                      width: 2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: selectedColor.withValues(alpha: 0.3),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [],
                  ),
                  child: Text(
                    _transactionTypes[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[700],
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDateTimeRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Campo Fecha
          Expanded(
            child: GestureDetector(
              onTap: _selectDate,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fecha',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateShort(_selectedDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Campo Hora
          Expanded(
            child: GestureDetector(
              onTap: _selectTime,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hora',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime.format(context),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _showKeyboard = false;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
        _showKeyboard = false;
      });
    }
  }

  Widget _buildAmountField() {
    final color = _selectedTypeIndex == 0
        ? Colors.blue
        : (_selectedTypeIndex == 1 ? Colors.red : Colors.grey[800]!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Importe',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            textField: true,
            label: 'Importe',
            value: _amount.isEmpty
                ? 'Sin importe'
                : '$_amount $_selectedCurrency',
            hint: 'Activa para introducir el importe',
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showKeyboard = true;
                });
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                width: double.infinity,
                padding: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: color, width: 2)),
                ),
                child: Text(
                  _amount.isEmpty ? '' : _amount,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleField(
    String label,
    TextEditingController controller, {
    bool showAI = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (showAI) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _generateNoteWithAI,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple[200]!, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.purple[700],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'IA',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onTap: () {
                setState(() {
                  _showKeyboard = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _generateNoteWithAI() {
    // TODO: Implementar generación de nota con IA
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generación de nota con IA - Funcionalidad pendiente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildCategoryField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categoría',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () {
              setState(() => _showKeyboard = false);
              _showCategorySelector();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  if (_selectedCategory != null) ...[
                    Text(
                      _getCategoryIcon(_selectedCategory!),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      _selectedCategory ?? '',
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedCategory == null
                            ? Colors.grey[400]
                            : Colors.black87,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Categoría',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () {
                        // TODO: Editar categorías
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Lista de categorías
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: _getCategories().map((category) {
                    final subcats = category['subcategories'] as List<dynamic>?;
                    return _buildCategoryItem(
                      icon: category['icon']!,
                      name: category['name']!,
                      subcategories: subcats?.cast<String>(),
                      onTap: () {
                        setState(() {
                          _selectedCategory = category['name'];
                          _categoryController.text = category['name']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryItem({
    required String icon,
    required String name,
    List<String>? subcategories,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedCategory == name;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.pink[50] : Colors.white,
          border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: Colors.black87,
                ),
              ),
            ),
            if (subcategories != null && subcategories.isNotEmpty)
              Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  String _getCategoryIcon(String categoryName) {
    final categories = _getCategories();
    return categories.firstWhere(
      (c) => c['name'] == categoryName,
      orElse: () => {'icon': '📁'},
    )['icon']!;
  }

  List<Map<String, dynamic>> _getCategories() {
    return [
      {
        'icon': '🍝',
        'name': 'Comida',
        'subcategories': ['Restaurante', 'Supermercado', 'Delivery'],
      },
      {'icon': '👨‍👩‍👧‍👦', 'name': 'Familia', 'subcategories': []},
      {
        'icon': '📙',
        'name': 'Educación',
        'subcategories': ['Libros', 'Cursos', 'Material'],
      },
      {'icon': '🏛️', 'name': 'Préstamos Dados', 'subcategories': []},
      {'icon': '😃', 'name': 'Préstamos Pagados', 'subcategories': []},
      {
        'icon': '🧹',
        'name': 'Servicios',
        'subcategories': ['Limpieza', 'Mantenimiento', 'Reparaciones'],
      },
      {
        'icon': '🚗',
        'name': 'Transporte',
        'subcategories': ['Taxi', 'Bus', 'Gasolina'],
      },
      {
        'icon': '🏠',
        'name': 'Hogar',
        'subcategories': ['Alquiler', 'Servicios', 'Muebles'],
      },
      {
        'icon': '💊',
        'name': 'Salud',
        'subcategories': ['Medicinas', 'Doctor', 'Seguro'],
      },
      {
        'icon': '🎮',
        'name': 'Entretenimiento',
        'subcategories': ['Cine', 'Streaming', 'Juegos'],
      },
      {
        'icon': '🛍️',
        'name': 'Compras',
        'subcategories': ['Ropa', 'Tecnología', 'Varios'],
      },
      {'icon': '📁', 'name': 'Otro', 'subcategories': []},
    ];
  }

  Widget _buildDescriptionField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notas adicionales',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.camera_alt, color: Colors.grey[600], size: 20),
                tooltip: 'Adjuntar foto',
                onPressed: () {
                  // TODO: Abrir cámara
                },
              ),
            ],
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
            child: TextField(
              controller: _descriptionController,
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                isDense: true,
              ),
              onTap: () {
                setState(() {
                  _showKeyboard = false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton(
              onPressed: () async {
                if (_validateForm()) {
                  try {
                    await _saveTransaction();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✓ Transacción guardada'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      Navigator.pop(context); // Volver a la pantalla anterior
                    }
                  } catch (_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'No pudimos guardar la transacción. Revisa los datos e inténtalo nuevamente.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.grey[400]!, width: 1.5),
              ),
              child: const Text(
                'Continuar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomKeyboard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header con selector de moneda y botón de cerrar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              children: [
                Text(
                  'Dinero',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                // Selector de moneda con Flexible para evitar overflow
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _currencies.map((currency) {
                      final isSelected = currency == _selectedCurrency;
                      return Semantics(
                        button: true,
                        selected: isSelected,
                        label: 'Moneda $currency',
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCurrency = currency;
                            });
                          },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.grey[800]
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currency,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.grey[700],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.keyboard_hide,
                    color: Colors.grey[700],
                    size: 20,
                  ),
                  tooltip: 'Ocultar teclado numérico',
                  onPressed: () {
                    setState(() {
                      _showKeyboard = false;
                    });
                  },
                ),
              ],
            ),
          ),

          // Teclado numérico
          Column(
            children: [
              _buildKeyboardRow(['1', '2', '3']),
              _buildKeyboardRow(['4', '5', '6']),
              _buildKeyboardRow(['7', '8', '9']),
              _buildKeyboardRow(['.', '0', 'backspace']),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyboardRow(List<String> keys) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: InkWell(
            onTap: () => _handleKeyPress(key),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!, width: 0.5),
                  right: BorderSide(color: Colors.grey[200]!, width: 0.5),
                ),
              ),
              child: Center(child: _buildKeyContent(key)),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyContent(String key) {
    if (key == 'backspace') {
      return const Icon(
        Icons.backspace_outlined,
        color: Colors.black87,
        size: 20,
      );
    } else {
      return Text(
        key,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w400,
        ),
      );
    }
  }

  void _handleKeyPress(String key) {
    setState(() {
      if (key == 'backspace') {
        if (_amount.isNotEmpty) {
          _amount = _amount.substring(0, _amount.length - 1);
        }
      } else if (key == '.') {
        if (!_amount.contains('.')) {
          _amount = _amount.isEmpty ? '0.' : '$_amount.';
        }
      } else {
        // Limitar a 2 decimales
        if (_amount.contains('.')) {
          final parts = _amount.split('.');
          if (parts[1].length < 2) {
            _amount += key;
          }
        } else {
          _amount += key;
        }
      }
    });
  }

  String _formatDateShort(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _validateForm() {
    // Validar que el importe no sea cero
    if (_amount.isEmpty || double.tryParse(_amount) == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El importe no puede ser cero')),
      );
      return false;
    }

    // Validar categoría
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una categoría')),
      );
      return false;
    }

    // Validar cuenta
    if (_accountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor seleccione una cuenta')),
      );
      return false;
    }

    // Validar nota
    if (_noteController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingrese una nota')),
      );
      return false;
    }

    return true;
  }

  Future<void> _saveTransaction() async {
    // Debug: verificar que la base de datos esté disponible
    print('DEBUG: widget.db = ${widget.db}');
    if (widget.db == null) {
      throw Exception('Base de datos no disponible');
    }

    // Generar ID único
    const uuid = Uuid();
    final id = uuid.v4();

    // Combinar fecha y hora
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    // Convertir monto a centavos
    final amount = double.parse(_amount);
    final amountCents = (amount * 100).round();

    // Determinar el signo según el tipo
    final finalAmountCents = _selectedTypeIndex == 0
        ? amountCents
        : -amountCents;

    // Guardar en la base de datos
    await widget.db.insertExpenseFromParser(
      id: id,
      dateEpochMs: dateTime.millisecondsSinceEpoch,
      amountCents: finalAmountCents,
      currency: _selectedCurrency,
      account: _accountController.text,
      vendor: _selectedCategory,
      description: _noteController.text, // La nota es el título/detalle
      notes: _descriptionController.text.isNotEmpty
          ? _descriptionController.text
          : null, // La descripción va en notes
      sourceApp: 'Manual',
    );
  }
}
