import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../../data/daos.dart';

class InboxPage extends StatelessWidget {
  final AppDatabase db;
  const InboxPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('El Ahorrador 💸')),
      body: StreamBuilder(
        stream: db.watchCaptures(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
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

extension _Str on String {
  String take(int n) => length <= n ? this : '${substring(0, n)}…';
}
