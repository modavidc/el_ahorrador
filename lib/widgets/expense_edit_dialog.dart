import 'package:flutter/material.dart';
import '../core/parser.dart';
import '../core/categories.dart';
import '../core/ai_notes_generator.dart';

class ExpenseEditDialog extends StatefulWidget {
  final ParsedExpense expense;
  final Function(ParsedExpense) onSave;

  const ExpenseEditDialog({
    super.key,
    required this.expense,
    required this.onSave,
  });

  @override
  State<ExpenseEditDialog> createState() => _ExpenseEditDialogState();
}

class _ExpenseEditDialogState extends State<ExpenseEditDialog> {
  late TextEditingController _vendorController;
  late TextEditingController _notesController;
  late TextEditingController _descriptionController;
  late double _amount;
  late DateTime _date;
  String? _selectedCategory;
  String? _selectedSubcategory;
  String? _selectedAccount;
  List<Category> _categories = [];
  List<String> _subcategories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _vendorController = TextEditingController(text: widget.expense.vendor ?? '');
    _notesController = TextEditingController(text: widget.expense.notes ?? '');
    _descriptionController = TextEditingController(text: widget.expense.description ?? '');
    _amount = widget.expense.amountCents / 100.0;
    _date = DateTime.fromMillisecondsSinceEpoch(widget.expense.dateEpochMs);
    _selectedCategory = widget.expense.category;
    _selectedSubcategory = widget.expense.subcategory;
    _selectedAccount = widget.expense.account;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await CategoryManager.getAllCategories();
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
    
    // Cargar subcategorías si hay una categoría seleccionada
    if (_selectedCategory != null) {
      await _loadSubcategories(_selectedCategory!);
    }
  }

  Future<void> _loadSubcategories(String categoryName) async {
    final subcategories = await CategoryManager.getSubcategories(categoryName);
    setState(() {
      _subcategories = subcategories;
    });
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _notesController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar Transacción'),
      content: SingleChildScrollView(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Monto
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Monto (S/)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) {
                  _amount = double.tryParse(value) ?? 0.0;
                },
                controller: TextEditingController(text: _amount.toString()),
              ),
              const SizedBox(height: 16),
              
              // Categoría
              _isLoading 
                ? const CircularProgressIndicator()
                : DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedCategory,
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category.name,
                        child: Row(
                          children: [
                            Text(category.icon),
                            const SizedBox(width: 8),
                            Text(category.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) async {
                      setState(() {
                        _selectedCategory = value;
                        _selectedSubcategory = null; // Reset subcategory
                      });
                      if (value != null) {
                        await _loadSubcategories(value);
                      }
                    },
                  ),
              const SizedBox(height: 16),
              
              // Subcategoría
              if (_selectedCategory != null && _subcategories.isNotEmpty)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Subcategoría',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedSubcategory,
                  items: _subcategories.map((sub) {
                    return DropdownMenuItem(
                      value: sub,
                      child: Text(sub),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSubcategory = value;
                    });
                  },
                ),
              const SizedBox(height: 16),
              
              // Cuenta
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Cuenta',
                  border: OutlineInputBorder(),
                ),
                value: _selectedAccount,
                items: const [
                  DropdownMenuItem(value: 'BCP Soles', child: Text('BCP Soles')),
                  DropdownMenuItem(value: 'Visa Light', child: Text('Visa Light')),
                  DropdownMenuItem(value: 'Yape', child: Text('Yape')),
                  DropdownMenuItem(value: 'Binance', child: Text('Binance')),
                  DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedAccount = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Destinatario/Vendor
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Destinatario/Proveedor',
                  border: OutlineInputBorder(),
                ),
                controller: _vendorController,
              ),
              const SizedBox(height: 16),
              
              // Descripción
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                controller: _descriptionController,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Notas
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Notas',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.auto_awesome),
                          tooltip: 'Generar nota automática',
                          onPressed: _generateAINote,
                        ),
                      ),
                      controller: _notesController,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.format_list_bulleted),
                    tooltip: 'Estructurar notas',
                    onPressed: _structureNotes,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Fecha
              ListTile(
                title: const Text('Fecha'),
                subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selectedDate = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (selectedDate != null) {
                    setState(() {
                      _date = selectedDate;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final updatedExpense = ParsedExpense(
              amountCents: (_amount * 100).round(),
              currency: widget.expense.currency,
              dateEpochMs: _date.millisecondsSinceEpoch,
              category: _selectedCategory,
              subcategory: _selectedSubcategory,
              account: _selectedAccount,
              vendor: _vendorController.text.trim().isEmpty ? null : _vendorController.text.trim(),
              description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
              notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
              sourceApp: widget.expense.sourceApp,
            );
            widget.onSave(updatedExpense);
            Navigator.of(context).pop();
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  /// Genera una nota automática con IA
  void _generateAINote() {
    final aiNote = AINotesGenerator.generateSmartNote(
      category: _selectedCategory ?? 'Otros',
      subcategory: _selectedSubcategory,
      vendor: _vendorController.text.trim(),
      description: _descriptionController.text.trim(),
      amount: _amount,
      sourceApp: widget.expense.sourceApp,
    );
    
    setState(() {
      _notesController.text = aiNote;
    });
    
    // Mostrar feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Nota generada automáticamente 🤖'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Estructura las notas con formato organizado
  void _structureNotes() {
    final currentNotes = _notesController.text.trim();
    if (currentNotes.isEmpty) return;

    // Estructura las notas con formato organizado
    final structuredNotes = _formatStructuredNotes(currentNotes);
    
    setState(() {
      _notesController.text = structuredNotes;
    });
    
    // Mostrar feedback visual
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notas estructuradas 📝'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Formatea las notas con estructura organizada
  String _formatStructuredNotes(String notes) {
    final lines = notes.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    if (lines.length <= 1) {
      // Si es una sola línea, agregar estructura básica
      return '• $notes';
    }
    
    // Si ya tiene múltiples líneas, estructurar mejor
    final structured = lines.map((line) {
      final trimmed = line.trim();
      if (trimmed.startsWith('•') || trimmed.startsWith('-') || trimmed.startsWith('*')) {
        return trimmed; // Ya está estructurado
      }
      return '• $trimmed';
    }).join('\n');
    
    return structured;
  }
}
