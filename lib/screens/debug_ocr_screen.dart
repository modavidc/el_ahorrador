import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_database.dart';
import '../data/daos.dart';

class DebugOcrScreen extends StatefulWidget {
  final AppDatabase db;

  const DebugOcrScreen({super.key, required this.db});

  @override
  State<DebugOcrScreen> createState() => _DebugOcrScreenState();
}

class _DebugOcrScreenState extends State<DebugOcrScreen> {
  List<CaptureWithOcr> _captures = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCaptures();
  }

  Future<void> _loadCaptures() async {
    setState(() => _isLoading = true);
    try {
      final captures = await widget.db.getAllCapturesWithOcr();
      setState(() {
        _captures = captures;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('No pudimos cargar las capturas.'), action: SnackBarAction(label: 'Reintentar', onPressed: _loadCaptures)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug OCRs'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Actualizar capturas',
            icon: const Icon(Icons.refresh),
            onPressed: _loadCaptures,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: Semantics(label: 'Cargando capturas OCR', liveRegion: true, child: const CircularProgressIndicator()))
          : _captures.isEmpty
              ? const Center(
                  child: Text('No hay capturas para mostrar'),
                )
              : ListView.builder(
                  itemCount: _captures.length,
                  itemBuilder: (context, index) {
                    final capture = _captures[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ExpansionTile(
                        title: Text('Captura ${index + 1}'),
                        subtitle: Text(
                          'Fecha: ${DateTime.fromMillisecondsSinceEpoch(capture.createdAtEpochMs).toString()}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Información básica
                                _buildInfoRow('ID', capture.id),
                                _buildInfoRow('Estado', capture.status),
                                _buildInfoRow('Imagen', capture.imagePath),
                                if (capture.ocrConfidence != null)
                                  _buildInfoRow('Confianza OCR', '${capture.ocrConfidence}%'),
                                
                                const SizedBox(height: 16),
                                
                                // Texto OCR completo
                                const Text(
                                  'Texto OCR Completo:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: SelectableText(
                                    capture.ocrText ?? 'Sin texto OCR',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // Botones de acción
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: capture.ocrText ?? ''),
                                        );
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Texto copiado al portapapeles'),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.copy),
                                      label: const Text('Copiar'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        _showFullTextDialog(capture.ocrText ?? '');
                                      },
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('Ver Completo'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullTextDialog(String text) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Texto OCR Completo'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Texto copiado al portapapeles'),
                ),
              );
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
