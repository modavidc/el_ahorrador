import 'package:flutter/material.dart';

import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/coach/domain/coach_model.dart';

/// Personalizar Coach → Modelo de IA: connect OpenAI with the user's own
/// key, or keep the answers computed on the phone.
class CoachModelScreen extends StatefulWidget {
  const CoachModelScreen({super.key, required this.access});

  final CoachModelAccess access;

  @override
  State<CoachModelScreen> createState() => _CoachModelScreenState();
}

class _CoachModelScreenState extends State<CoachModelScreen> {
  final _key = TextEditingController();
  bool? _connected;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.access.isConnected().then((c) {
      if (mounted) setState(() => _connected = c);
    });
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.access.connect(_key.text);
      _key.clear();
      if (!mounted) return;
      setState(() => _connected = true);
      showUndoToast(context, 'Coach conectado a OpenAI');
    } on CoachModelException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    await widget.access.disconnect();
    if (!mounted) return;
    setState(() => _connected = false);
    showUndoToast(context, 'Clave eliminada del teléfono');
  }

  @override
  Widget build(BuildContext context) {
    final connected = _connected ?? false;
    return SubPage(
      title: 'Modelo de IA',
      children: [
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: DesignIcons.autoAwesome,
                    color: DesignColors.red,
                    background: DesignColors.blush,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      connected ? 'OpenAI' : 'En tu teléfono',
                      style: DesignText.cardTitle,
                    ),
                  ),
                  StatusPill(
                    label: connected ? 'Conectado' : 'Sin conectar',
                    background: connected
                        ? DesignColors.greenSoft
                        : DesignColors.chip,
                    color: connected ? DesignColors.green : DesignColors.ink2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                connected
                    ? 'El Coach responde con OpenAI usando tu clave. Si no hay '
                          'internet, responde con cálculos en tu teléfono.'
                    : 'El Coach responde con cálculos hechos en tu teléfono. '
                          'Conecta OpenAI para respuestas más conversadas.',
                style: DesignText.body14.copyWith(color: DesignColors.ink2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PaperCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Sym(
                DesignIcons.verifiedUser,
                size: 20,
                color: DesignColors.green,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Solo se envían los totales del mes (presupuesto, gastado y '
                  'por categoría). Nunca tus movimientos, notas, cuentas ni '
                  'comprobantes. La clave se guarda cifrada en este teléfono.',
                  style: DesignText.label13.copyWith(color: DesignColors.ink3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (connected)
          SheetButton.secondary(
            key: const ValueKey('coach-model-disconnect'),
            label: 'Quitar clave',
            onTap: _disconnect,
          )
        else ...[
          const FieldLabel('Clave de API de OpenAI'),
          FieldBox(
            key: const ValueKey('coach-model-key'),
            controller: _key,
            hint: 'sk-…',
            obscure: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ErrorText(_error!),
          const SizedBox(height: 16),
          SheetButton(
            key: const ValueKey('coach-model-connect'),
            label: _busy ? 'Verificando…' : 'Conectar',
            onTap: _busy || _key.text.trim().isEmpty ? null : _connect,
            color: _busy || _key.text.trim().isEmpty
                ? DesignColors.disabled
                : DesignColors.red,
          ),
        ],
      ],
    );
  }
}
