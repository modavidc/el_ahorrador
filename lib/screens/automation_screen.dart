import 'package:flutter/material.dart';

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

  static const _accent = Color(0xFFFF625D);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F5F7),
    appBar: AppBar(
      title: const Text('Automatización'),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF25252B),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        _statusCard(),
        const SizedBox(height: 22),
        const _SectionTitle('Flujo funcional actual'),
        const _InfoTile(
          icon: Icons.share_outlined,
          title: 'Capturas compartidas',
          subtitle:
              'Comparte una captura desde otra app para procesarla con OCR.',
          badge: 'FUNCIONAL',
          highlighted: true,
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Opciones planificadas'),
        const _InfoTile(
          icon: Icons.notifications_active_outlined,
          title: 'Notificaciones de pago',
          subtitle: 'Detección automática de bancos y billeteras.',
          badge: 'MAQUETA',
        ),
        const _InfoTile(
          icon: Icons.fact_check_outlined,
          title: 'Confirmación antes de guardar',
          subtitle: 'Revisión de importe, cuenta y categoría.',
          badge: 'MAQUETA',
        ),
        const SizedBox(height: 22),
        const _SectionTitle('Reglas planificadas'),
        _actionTile(
          context,
          icon: Icons.account_tree_outlined,
          title: 'Reglas de categorización',
          subtitle: 'Relacionar comercios con categorías.',
        ),
        _actionTile(
          context,
          icon: Icons.route_outlined,
          title: 'Rutas de supertransferencia',
          subtitle: 'Guardar recorridos frecuentes entre cuentas.',
        ),
      ],
    ),
  );

  Widget _statusCard() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEB),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _accent.withValues(alpha: .25)),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: _accent,
          foregroundColor: Colors.white,
          child: Icon(Icons.auto_awesome_outlined),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Centro de automatización',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 5),
              Text(
                'Esta vista informa qué funciona hoy y qué está planificado. No contiene ajustes persistentes.',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) => Card(
    margin: const EdgeInsets.only(top: 8),
    elevation: 0,
    child: ListTile(
      leading: Icon(icon, color: _accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const _StatusBadge(text: 'MAQUETA'),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title todavía no guarda información.')),
      ),
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    elevation: 0,
    child: ListTile(
      leading: Icon(
        icon,
        color: highlighted ? AutomationScreen._accent : const Color(0xFF777780),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: _StatusBadge(text: badge, highlighted: highlighted),
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text, this.highlighted = false});

  final String text;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: highlighted ? const Color(0xFFFFECEB) : const Color(0xFFEDEDF0),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: highlighted ? AutomationScreen._accent : const Color(0xFF777780),
        fontSize: 9,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Color(0xFF777780),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    ),
  );
}
