import 'package:flutter/material.dart';

import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/capture/domain/background_capture.dart';

/// Dark "Captura activa" card of Ajustes: the switch and how many HyperOS
/// permissions are ready.
class CaptureStatusCard extends StatelessWidget {
  const CaptureStatusCard({
    super.key,
    required this.state,
    required this.onToggle,
  });

  final BackgroundCaptureState state;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final ready = CapturePermission.values.where(state.granted.contains).length;
    final total = CapturePermission.values.length;
    final (label, dot) = !state.supported
        ? ('Captura al compartir', DesignColors.green)
        : state.active
        ? ('Captura activa', DesignColors.green)
        : state.enabled
        ? ('Faltan permisos', DesignColors.amber)
        : ('Captura en pausa', DesignColors.inkFaint);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: DesignColors.ink,
        borderRadius: BorderRadius.circular(DesignRadius.bigCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: DesignText.subTitle.copyWith(color: DesignColors.card),
                ),
              ),
              if (state.supported)
                DsToggle(value: state.enabled, onTap: onToggle),
            ],
          ),
          const SizedBox(height: 14),
          if (state.supported) ...[
            Container(
              height: 6,
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: DesignColors.onDarkTile,
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                widthFactor: ready / total,
                child: Container(
                  decoration: BoxDecoration(
                    color: DesignColors.red,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Permisos HyperOS',
                    style: DesignText.label13.copyWith(
                      color: DesignColors.onDarkText,
                    ),
                  ),
                ),
                Text(
                  '$ready de $total listos',
                  style: DesignText.label13.copyWith(
                    color: DesignColors.onDarkText,
                  ),
                ),
              ],
            ),
          ] else
            Text(
              'Comparte comprobantes desde Yape o tu banco y se registran '
              'solos.',
              style: DesignText.label13.copyWith(
                color: DesignColors.onDarkText,
              ),
            ),
        ],
      ),
    );
  }
}

/// Captura → the capture functions: share, background, Por revisar,
/// permissions and rules.
class CaptureHubScreen extends StatelessWidget {
  const CaptureHubScreen({
    super.key,
    required this.capture,
    required this.inboxCount,
    required this.onTryShare,
    required this.onOpenInbox,
    required this.onOpenRules,
    required this.onOpenPermissions,
  });

  final BackgroundCapture capture;
  final Stream<int> inboxCount;
  final VoidCallback onTryShare;
  final VoidCallback onOpenInbox;
  final VoidCallback onOpenRules;
  final VoidCallback onOpenPermissions;

  @override
  Widget build(BuildContext context) => StreamBuilder<BackgroundCaptureState>(
    stream: capture.watch(),
    builder: (context, snapshot) {
      final state = snapshot.data ?? BackgroundCaptureState.unsupported;
      return StreamBuilder<int>(
        stream: inboxCount,
        builder: (context, inbox) {
          final pending = inbox.data ?? 0;
          final rows = [
            (
              DesignIcons.share,
              'Compartir comprobante',
              'Desde Yape o tu banco · una o varias imágenes',
              false,
              true,
              onTryShare,
            ),
            if (state.supported)
              (
                DesignIcons.screenshotMonitor,
                'Captura en segundo plano',
                state.ready
                    ? 'Detecta tus capturas de pantalla de pagos'
                    : 'Requiere permisos de HyperOS',
                !state.ready,
                true,
                onOpenPermissions,
              ),
            (
              DesignIcons.inbox,
              'Bandeja Por revisar',
              '$pending ${pending == 1 ? 'pendiente' : 'pendientes'}',
              pending > 0,
              false,
              onOpenInbox,
            ),
            if (state.supported)
              (
                DesignIcons.verifiedUser,
                'Permisos HyperOS',
                '${state.granted.length} de ${CapturePermission.values.length} listos',
                !state.ready,
                false,
                onOpenPermissions,
              ),
            (
              DesignIcons.rule,
              'Reglas de captura',
              'Ingreso/gasto, cuenta, categoría',
              false,
              false,
              onOpenRules,
            ),
          ];
          return SubPage(
            title: 'Captura',
            children: [
              CaptureStatusCard(
                state: state,
                onToggle: () => capture.setEnabled(!state.enabled),
              ),
              const SizedBox(height: 10),
              PaperCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Column(
                  children: [
                    for (final (i, (icon, title, sub, warn, accent, onTap))
                        in rows.indexed)
                      FeatureRow(
                        icon: icon,
                        title: title,
                        subtitle: sub,
                        warn: warn,
                        accent: accent,
                        first: i == 0,
                        onTap: onTap,
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Row with a colored tile, title, subtitle (amber when [warn]) and a red
/// dot when something needs attention.
class FeatureRow extends StatelessWidget {
  const FeatureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.warn = false,
    this.accent = false,
    this.first = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool warn;

  /// Red tile (main functions); beige otherwise.
  final bool accent;
  final bool first;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.lineSoft)),
        ),
        child: Row(
          children: [
            IconTile(
              icon: icon,
              color: accent ? DesignColors.red : DesignColors.ink,
              background: accent ? DesignColors.blush : DesignColors.tile,
              size: 38,
              iconSize: 20,
              radius: 13,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: DesignText.rowAmount),
                    Text(
                      subtitle,
                      style: DesignText.small.copyWith(
                        color: warn
                            ? DesignColors.amberDeep
                            : DesignColors.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (warn)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: const BoxDecoration(
                  color: DesignColors.red,
                  shape: BoxShape.circle,
                ),
              ),
            const Sym(
              DesignIcons.chevronRight,
              size: 20,
              color: DesignColors.inkFaint,
            ),
          ],
        ),
      ),
    ),
  );
}

/// Permisos HyperOS: each permission opens its system page; the state is
/// checked again on return.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, required this.capture});

  final BackgroundCapture capture;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.capture.refresh();
  }

  static IconData _icon(CapturePermission p) => switch (p) {
    CapturePermission.autostart => DesignIcons.rocketLaunch,
    CapturePermission.notifications => DesignIcons.notificationsActive,
    CapturePermission.battery => DesignIcons.batterySaver,
    CapturePermission.overlay => DesignIcons.pictureInPicture,
    CapturePermission.recents => DesignIcons.lock,
  };

  @override
  Widget build(BuildContext context) => StreamBuilder<BackgroundCaptureState>(
    stream: widget.capture.watch(),
    builder: (context, snapshot) {
      final state = snapshot.data ?? BackgroundCaptureState.unsupported;
      final total = CapturePermission.values.length;
      final ready = state.granted.length;
      return SubPage(
        title: 'Permisos HyperOS',
        trailing: '$ready de $total listos',
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(
              state.ready
                  ? 'Captura lista'
                  : 'Faltan ${state.missingRequired} '
                        '${state.missingRequired == 1 ? 'permiso obligatorio' : 'permisos obligatorios'}',
              style: DesignText.style(
                24,
                FontWeight.w800,
                letterSpacing: -.02,
                height: 1.15,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 16),
            child: ProgressLine(
              ratio: ready / total,
              color: state.ready ? DesignColors.green : DesignColors.amber,
            ),
          ),
          PaperCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Column(
              children: [
                for (final (i, p) in CapturePermission.values.indexed)
                  _PermissionRow(
                    icon: _icon(p),
                    permission: p,
                    granted: state.granted.contains(p),
                    first: i == 0,
                    onTap: () => widget.capture.openSettings(p),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 0),
            child: Text(
              'Cada permiso abre su pantalla de ajustes del teléfono. Al '
              'volver, revisamos si quedó activo.',
              style: DesignText.label13.copyWith(
                color: DesignColors.ink2,
                height: 1.45,
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.permission,
    required this.granted,
    required this.first,
    required this.onTap,
  });

  final IconData icon;
  final CapturePermission permission;
  final bool granted;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = granted
        ? DesignColors.green
        : permission.required
        ? DesignColors.amber
        : DesignColors.inkFaint;
    return Semantics(
      button: true,
      toggled: granted,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 70),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: DesignColors.lineSoft)),
          ),
          child: Row(
            children: [
              IconTile(icon: icon, color: color, background: DesignColors.tile),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(permission.title, style: DesignText.rowAmount),
                      Text(
                        '${permission.required ? 'Obligatorio' : 'Opcional'} · '
                        '${permission.subtitle}',
                        style: DesignText.small.copyWith(
                          color: DesignColors.ink2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              IgnorePointer(
                child: DsToggle(value: granted, onTap: onTap),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Faltan permisos": background capture needs HyperOS permissions first.
class MissingPermissionsSheet extends StatelessWidget {
  const MissingPermissionsSheet({
    super.key,
    required this.missing,
    required this.onOpenPermissions,
  });

  final int missing;
  final VoidCallback onOpenPermissions;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Faltan permisos',
        style: DesignText.style(
          26,
          FontWeight.w800,
          letterSpacing: -.03,
          height: 1.1,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Para capturar en segundo plano, HyperOS necesita $missing '
        '${missing == 1 ? 'permiso más' : 'permisos más'}.',
        style: DesignText.row.copyWith(
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: DesignColors.ink2,
        ),
      ),
      const SizedBox(height: 16),
      SheetButton(label: 'Ir a permisos', onTap: onOpenPermissions),
    ],
  );
}
