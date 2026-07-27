import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';

class InboxPage extends StatefulWidget {
  final AppDatabase db;
  const InboxPage({super.key, required this.db});

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  late Stream<List<CaptureModel>> _captures;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _captures = widget.db.watchCaptures();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Ahorrador 💸')),
      body: StreamBuilder<List<CaptureModel>>(
        stream: _captures,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _errorState();
          if (!snapshot.hasData) {
            return Center(
              child: Semantics(
                label: 'Cargando capturas',
                liveRegion: true,
                child: CircularProgressIndicator(),
              ),
            );
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(
              child: Text('Comparte una captura para empezar'),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final capture = list[i];
              return ListTile(
                leading: const Icon(Icons.image),
                title: Text(
                  '${capture.status} • ${DateTime.fromMillisecondsSinceEpoch(capture.createdAt)}',
                ),
                subtitle: Text((capture.ocrText ?? '').take(2)),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            const Text(
              'No se pudieron cargar las capturas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

extension _Str on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}
