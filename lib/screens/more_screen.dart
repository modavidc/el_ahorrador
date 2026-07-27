import 'package:flutter/material.dart';

import 'automation_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _accent = Color(0xFFFF625D);
  static const _ink = Color(0xFF25252B);

  @override
  Widget build(BuildContext context) {
    const options = [
      _MoreOption('Configuración', Icons.settings_outlined),
      _MoreOption(
        'Automatización',
        Icons.auto_awesome_outlined,
        available: true,
      ),
      _MoreOption('Respaldo', Icons.settings_backup_restore_outlined),
      _MoreOption('Apariencia', Icons.palette_outlined),
      _MoreOption('Ayuda', Icons.help_outline),
      _MoreOption('Opina', Icons.mark_email_read_outlined),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        title: const Text('Más'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                'El Ahorrador',
                style: TextStyle(color: Color(0xFF8D8D95)),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
            child: const Text(
              'La automatización tiene una vista informativa. Las demás opciones son maquetas y todavía no guardan cambios.',
              style: TextStyle(color: Color(0xFF707078), height: 1.35),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 26,
                crossAxisSpacing: 12,
                childAspectRatio: .88,
              ),
              itemCount: options.length,
              itemBuilder: (context, index) => _OptionButton(
                option: options[index],
                onTap: () => _openOption(context, options[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openOption(BuildContext context, _MoreOption option) {
    if (option.available) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const AutomationScreen()));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _ComingSoonScreen(title: option.label, icon: option.icon),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.option, required this.onTap});

  final _MoreOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            option.icon,
            size: 43,
            color: option.available
                ? MoreScreen._accent
                : const Color(0xFF494951),
          ),
          const SizedBox(height: 12),
          Text(
            option.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          Text(
            option.available ? 'Vista previa' : 'Próximamente',
            style: TextStyle(
              color: option.available
                  ? MoreScreen._accent
                  : const Color(0xFF9999A0),
              fontSize: 11,
            ),
          ),
        ],
      ),
    ),
  );
}

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7F7F9),
    appBar: AppBar(
      title: Text(title),
      backgroundColor: Colors.white,
      foregroundColor: MoreScreen._ink,
    ),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFF777780)),
            const SizedBox(height: 18),
            Text(
              '$title está en maqueta',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            const Text(
              'Esta pantalla todavía no modifica ni guarda información.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF707078), height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MoreOption {
  const _MoreOption(this.label, this.icon, {this.available = false});

  final String label;
  final IconData icon;
  final bool available;
}
