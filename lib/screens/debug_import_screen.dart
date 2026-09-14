import 'dart:developer' as developer;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/historical_import.dart';

// Pantalla de debug temporal: importa las transacciones históricas
// de assets/import/importar.csv. Ver Z:\el_ahorrador\IMPORT_MASIVO_SPEC.md.
// Es idempotente (corre historical_import.dart), así que presionar el botón
// más de una vez no duplica registros.
class DebugImportScreen extends StatefulWidget {
  final AppDatabase db;

  const DebugImportScreen({super.key, required this.db});

  @override
  State<DebugImportScreen> createState() => _DebugImportScreenState();
}

class _DebugImportScreenState extends State<DebugImportScreen> {
  final List<String> _log = [];
  bool _running = false;

  void _addLog(String line) {
    if (!mounted) return;
    setState(() => _log.add(line));
  }

  Future<void> _runImport() async {
    setState(() {
      _running = true;
      _log.clear();
    });
    try {
      await runHistoricalImport(widget.db, _addLog);
    } catch (e, st) {
      developer.log('Historical import failed', error: e, stackTrace: st);
      _addLog('ERROR FATAL: $e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug: Import histórico')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Importa gastos e ingresos históricos desde '
              'assets/import/importar.csv. '
              'Se puede correr más de una vez sin duplicar (chequea por '
              'fecha+monto+descripción+sourceApp).',
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _running ? null : _runImport,
              child: Text(_running ? 'Importando...' : 'Ejecutar import'),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (context, i) => Text(
                    _log[i],
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
