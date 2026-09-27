import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/app_database.dart';
import '../../features/settings/app_preferences.dart';
import '../../screens/debug_import_screen.dart';
import '../../security/app_lock_settings.dart';
import '../../security/local_auth_service.dart';
import '../../theme/design_tokens.dart';
import '../widgets.dart';
import 'budgets_screen.dart';

/// Ajustes of the v1 prototype: Coach e IA, General, Datos, Seguridad.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db, this.lockAuthenticator});

  final AppDatabase db;

  /// Confirms changes to the fingerprint lock; the system prompt by default.
  final LocalAuthenticator? lockAuthenticator;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _preferences = AppPreferences(widget.db);
  late final StreamSubscription<Map<Preference, bool>> _subscription;
  Map<Preference, bool> _values = {
    for (final p in Preference.values) p: p.defaultValue,
  };
  String _version = '';

  @override
  void initState() {
    super.initState();
    _subscription = _preferences.watch().listen(
      (values) => setState(() => _values = values),
    );
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((Object _) {});
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _soon() => showDsToast(context, 'Próximamente');

  Future<void> _toggleLock(AppLockSettings appLock) async {
    // Both turning the lock on and off require the device owner, so a
    // borrowed unlocked phone cannot change it and enabling it proves the
    // device can actually unlock the app afterwards.
    final result =
        await (widget.lockAuthenticator ?? SystemLocalAuthenticator())
            .authenticate();
    if (!mounted) return;
    switch (result) {
      case LocalAuthenticationResult.authenticated:
        await appLock.setEnabled(!appLock.enabled);
      case LocalAuthenticationResult.unavailable:
        showDsToast(
          context,
          'Configura una huella o un bloqueo de pantalla en tu teléfono primero.',
        );
      case LocalAuthenticationResult.rejected:
      case LocalAuthenticationResult.error:
        showDsToast(context, 'No se pudo confirmar tu identidad.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLock = AppLockScope.maybeOf(context);
    _SettingRow toggle(IconData icon, String label, Preference p) =>
        _SettingRow.toggle(
          icon: icon,
          label: label,
          value: _values[p]!,
          onTap: () => _preferences.set(p, !_values[p]!),
        );

    final groups = <(String, List<_SettingRow>)>[
      (
        'Coach e IA',
        [
          toggle(
            DesignIcons.autoAwesome,
            'Categorizar automáticamente',
            Preference.autoCategorize,
          ),
          toggle(
            DesignIcons.documentScanner,
            'Guardar recibos OCR sin revisar',
            Preference.saveOcrWithoutReview,
          ),
          toggle(
            DesignIcons.notifications,
            'Resumen semanal del Coach',
            Preference.weeklyCoachSummary,
          ),
          _SettingRow.link(
            icon: DesignIcons.memory,
            label: 'Modelo',
            value: 'OpenAI',
            onTap: _soon,
          ),
        ],
      ),
      (
        'General',
        [
          _SettingRow.link(
            icon: DesignIcons.payments,
            label: 'Moneda principal',
            value: 'PEN · S/',
            onTap: _soon,
          ),
          _SettingRow.link(
            icon: DesignIcons.calendarMonth,
            label: 'Inicio de mes',
            value: 'Día 1',
            onTap: _soon,
          ),
          _SettingRow.link(
            icon: DesignIcons.dateRange,
            label: 'Inicio de semana',
            value: 'Domingo',
            onTap: _soon,
          ),
          _SettingRow.link(
            icon: DesignIcons.category,
            label: 'Categorías',
            onTap: _soon,
          ),
          _SettingRow.link(
            icon: DesignIcons.savings,
            label: 'Presupuestos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BudgetsScreen(db: widget.db),
              ),
            ),
          ),
        ],
      ),
      (
        'Datos',
        [
          _SettingRow.link(
            icon: DesignIcons.tableView,
            label: 'Exportar a Excel',
            onTap: _soon,
          ),
          _SettingRow.link(
            icon: DesignIcons.uploadFile,
            label: 'Importar desde Money Manager',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DebugImportScreen(db: widget.db),
              ),
            ),
          ),
          _SettingRow.link(
            icon: DesignIcons.backup,
            label: 'Copia de seguridad',
            onTap: _soon,
          ),
        ],
      ),
      (
        'Seguridad',
        [
          if (appLock != null)
            _SettingRow.toggle(
              icon: DesignIcons.lock,
              label: 'Bloqueo con huella',
              value: appLock.enabled,
              onTap: () => _toggleLock(appLock),
            ),
          _SettingRow.link(
            icon: DesignIcons.darkMode,
            label: 'Tema',
            value: 'Claro',
            onTap: _soon,
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
            color: DesignColors.surfaceCard,
            border: Border(bottom: BorderSide(color: DesignColors.border)),
          ),
          child: Text('Ajustes', style: DesignText.title),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final (i, (title, rows)) in groups.indexed) ...[
                if (i > 0) const SizedBox(height: DesignSpacing.lg),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                  child: Text(
                    title.toUpperCase(),
                    style: DesignText.captionMedium.copyWith(
                      color: DesignColors.textTertiary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                DsCard(
                  child: Column(
                    children: [
                      for (final (j, row) in rows.indexed)
                        row.build(first: j == 0),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: DesignSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 84),
                child: Text(
                  [
                    'El Ahorrador',
                    if (_version.isNotEmpty) 'v$_version',
                    'datos locales',
                  ].join(' · '),
                  textAlign: TextAlign.center,
                  style: DesignText.caption.copyWith(
                    color: DesignColors.textDisabled,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 52px settings row: icon, label, then a value + chevron or a toggle.
final class _SettingRow {
  const _SettingRow.link({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value = '',
  }) : toggle = null;

  const _SettingRow.toggle({
    required this.icon,
    required this.label,
    required this.onTap,
    required bool value,
  }) : toggle = value,
       value = '';

  final IconData icon;
  final String label;
  final String value;
  final bool? toggle;
  final VoidCallback onTap;

  Widget build({required bool first}) => Semantics(
    button: true,
    toggled: toggle,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: DesignColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Sym(icon, size: 20, color: DesignColors.textSecondary),
            const SizedBox(width: DesignSpacing.md),
            Expanded(child: Text(label, style: DesignText.body)),
            if (value.isNotEmpty) ...[
              const SizedBox(width: DesignSpacing.md),
              Text(
                value,
                style: DesignText.label.copyWith(
                  color: DesignColors.textTertiary,
                ),
              ),
            ],
            if (toggle case final on?) ...[
              const SizedBox(width: DesignSpacing.md),
              _Toggle(value: on),
            ] else ...[
              const SizedBox(width: DesignSpacing.md),
              const Sym(
                DesignIcons.chevronRight,
                size: 18,
                color: DesignColors.textDisabled,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 40×24 toggle: primary track when on, grey when off.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    width: 40,
    height: 24,
    padding: const EdgeInsets.all(3),
    alignment: value ? Alignment.centerRight : Alignment.centerLeft,
    decoration: BoxDecoration(
      color: value ? DesignColors.primary : DesignColors.toggleTrackOff,
      borderRadius: BorderRadius.circular(DesignRadius.pill),
    ),
    child: Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: DesignColors.onPrimary,
        shape: BoxShape.circle,
        boxShadow: DesignShadows.knob,
      ),
    ),
  );
}
