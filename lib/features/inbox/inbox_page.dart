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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Ahorrador 💸')),
      body: StreamBuilder(
        stream: widget.db.watchCaptures(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(onRetry: () => setState(() {}));
          }
          if (!snapshot.hasData) {
            return Center(child: Semantics(label: 'Cargando capturas', liveRegion: true, child: const CircularProgressIndicator()));
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(child: Text('Comparte una captura para empezar'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final c = list[i];
              return ListTile(
                leading: const Icon(Icons.image),
                title: Text('${c.status} • ${DateTime.fromMillisecondsSinceEpoch(c.createdAt)}'),
                subtitle: Text((c.ocrText ?? '').take(2)),
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(child: Semantics(
    liveRegion: true,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('No pudimos cargar tus capturas.'),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
    ]),
  ));
}

extension _Str on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}
