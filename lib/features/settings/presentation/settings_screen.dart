import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/format/fmt.dart';
import 'package:el_ahorrador/core/security/app_lock_settings.dart';
import 'package:el_ahorrador/core/security/local_auth_service.dart';
import 'package:el_ahorrador/design_system/kit.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/capture/domain/background_capture.dart';
import 'package:el_ahorrador/features/capture/presentation/capture_hub_screen.dart';
import 'package:el_ahorrador/features/ledger/domain/month_summary.dart';
import 'package:el_ahorrador/features/ledger/presentation/ledger_scope.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';
import 'package:el_ahorrador/features/stats/domain/stats.dart';

/// Where Ajustes leads outside itself; the app shell decides how to open
/// each place.
final class SettingsLinks {
  const SettingsLinks({
    required this.openCapture,
    required this.openStreak,
    required this.openBudgets,
    required this.openAccounts,
    required this.openCategory,
    required this.openCoachHistory,
    required this.showWelcome,
    this.coachModel,
    this.testReminder,
    this.runImport,
  });

  final VoidCallback openCapture;
  final VoidCallback openStreak;
  final VoidCallback openBudgets;
  final VoidCallback openAccounts;
  final ValueChanged<Category> openCategory;
  final VoidCallback openCoachHistory;
  final VoidCallback showWelcome;

  /// Personalizar Coach → Modelo de IA (OpenAI key); null hides the row.
  final VoidCallback? coachModel;

  /// Recordatorios → Probar recordatorio.
  final VoidCallback? testReminder;

  /// Debug builds: historical import from assets/import.
  final VoidCallback? runImport;
}

/// Ajustes (v3): capture card, Hábito, Finanzas, Coach e IA, App, Soporte.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.preferences,
    required this.capture,
    required this.links,
    this.lockAuthenticator,
    this.version = '',
  });

  final AppPreferences preferences;
  final BackgroundCapture capture;
  final SettingsLinks links;

  /// Confirms changes to the fingerprint lock; the system prompt by default.
  final LocalAuthenticator? lockAuthenticator;
  final String version;

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final data = LedgerScope.of(context);
    final today = AppClock.now();
    final streak = streakDays(data.movements, today);
    final appLock = AppLockScope.maybeOf(context);
    return StreamBuilder<Map<Preference, bool>>(
      stream: preferences.watch(),
      builder: (context, prefs) {
        bool on(Preference p) => prefs.data?[p] ?? p.defaultValue;
        return StreamBuilder<String>(
          stream: preferences.watchText(TextPreference.reminderTime),
          builder: (context, time) => StreamBuilder<String>(
            stream: preferences.watchText(TextPreference.coachTone),
            builder: (context, tone) => ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ajustes', style: DesignText.tabTitle),
                  ),
                ),
                _ProfileCard(streak: streak),
                const SectionHeader(title: 'Captura'),
                StreamBuilder<BackgroundCaptureState>(
                  stream: capture.watch(),
                  builder: (context, state) => CaptureStatusCard(
                    state: state.data ?? BackgroundCaptureState.unsupported,
                    onToggle: () =>
                        capture.setEnabled(!(state.data?.enabled ?? false)),
                  ),
                ),
                const SizedBox(height: 10),
                PaperCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 2,
                  ),
                  child: FeatureRow(
                    icon: DesignIcons.bolt,
                    title: 'Funciones de captura',
                    subtitle: 'Por revisar, permisos y reglas',
                    accent: true,
                    first: true,
                    onTap: links.openCapture,
                  ),
                ),
                SettingsGroup(
                  title: 'Hábito',
                  rows: [
                    SettingRow(
                      first: true,
                      icon: DesignIcons.notificationsActive,
                      label: 'Recordatorios y recaps',
                      value: on(Preference.dailyReminder)
                          ? 'Diario ${time.data ?? TextPreference.reminderTime.defaultValue}'
                          : 'Apagado',
                      onTap: () => _push(
                        context,
                        RemindersScreen(
                          preferences: preferences,
                          onTest: links.testReminder,
                        ),
                      ),
                    ),
                    SettingRow(
                      icon: DesignIcons.localFireDepartment,
                      label: 'Mi racha',
                      value: '$streak ${streak == 1 ? 'día' : 'días'}',
                      onTap: links.openStreak,
                    ),
                  ],
                ),
                SettingsGroup(
                  title: 'Finanzas',
                  rows: [
                    SettingRow(
                      first: true,
                      icon: DesignIcons.category,
                      label: 'Categorías',
                      value:
                          '${Category.expenses.length + 1} + ${Category.incomes.length - 1}',
                      onTap: () => _push(
                        context,
                        LedgerScope.forward(
                          context,
                          child: CategoriesScreen(onOpen: links.openCategory),
                        ),
                      ),
                    ),
                    SettingRow(
                      icon: DesignIcons.savings,
                      label: 'Presupuestos',
                      value: on(Preference.useMonthlyBudget)
                          ? Fmt.money0(data.monthlyBudgetCents / 100)
                          : 'Apagado',
                      onTap: links.openBudgets,
                    ),
                    SettingRow(
                      icon: DesignIcons.accountBalanceWallet,
                      label: 'Cuentas',
                      value:
                          '${data.accounts.length} '
                          '${data.accounts.length == 1 ? 'cuenta' : 'cuentas'}',
                      onTap: links.openAccounts,
                    ),
                  ],
                ),
                SettingsGroup(
                  title: 'Coach e IA',
                  rows: [
                    SettingRow(
                      first: true,
                      icon: DesignIcons.tune,
                      label: 'Personalizar Coach',
                      value:
                          'Coach · ${tone.data ?? TextPreference.coachTone.defaultValue}',
                      onTap: () => _push(
                        context,
                        CoachSettingsScreen(
                          preferences: preferences,
                          onOpenHistory: links.openCoachHistory,
                          onOpenModel: links.coachModel,
                        ),
                      ),
                    ),
                    ToggleRow(
                      icon: DesignIcons.autoAwesome,
                      label: 'Categorizar automáticamente',
                      subtitle: 'Sugiere la categoría de cada captura',
                      value: on(Preference.autoCategorize),
                      onTap: () => preferences.set(
                        Preference.autoCategorize,
                        !on(Preference.autoCategorize),
                      ),
                    ),
                  ],
                ),
                SettingsGroup(
                  title: 'App',
                  rows: [
                    SettingRow(
                      first: true,
                      icon: appLock?.enabled ?? false
                          ? DesignIcons.lock
                          : DesignIcons.lockOpen,
                      label: 'Seguridad',
                      value: appLock?.enabled ?? false
                          ? 'Huella'
                          : 'Sin bloqueo',
                      onTap: () => _push(
                        context,
                        AppLockScope(
                          settings: appLock ?? AppLockSettings.disabled(),
                          child: SecurityScreen(
                            authenticator: lockAuthenticator,
                          ),
                        ),
                      ),
                    ),
                    SettingRow(
                      icon: DesignIcons.replay,
                      label: 'Ver bienvenida',
                      onTap: links.showWelcome,
                    ),
                  ],
                ),
                SettingsGroup(
                  title: 'Soporte',
                  rows: [
                    SettingRow(
                      first: true,
                      icon: DesignIcons.info,
                      label: 'Acerca de',
                      value: version.isEmpty ? '' : 'v$version',
                      onTap: () => showUndoToast(
                        context,
                        'El Ahorrador${version.isEmpty ? '' : ' v$version'}'
                        ' · datos en este dispositivo',
                      ),
                    ),
                    if (kDebugMode && links.runImport != null)
                      SettingRow(
                        icon: DesignIcons.download,
                        label: 'Import histórico (debug)',
                        onTap: links.runImport,
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Text(
                    'El Ahorrador${version.isEmpty ? '' : ' · v$version'} · '
                    'datos en este dispositivo',
                    textAlign: TextAlign.center,
                    style: DesignText.small.copyWith(color: DesignColors.ink2),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) => PaperCard(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            color: DesignColors.red,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Sym(DesignIcons.savings, size: 24, color: DesignColors.card),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('El Ahorrador', style: DesignText.headlineBold),
              Text(
                'Datos en este dispositivo · racha de $streak '
                '${streak == 1 ? 'día' : 'días'}',
                style: DesignText.label13.copyWith(color: DesignColors.ink2),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Recordatorios: daily reminder and its hour, recaps and notices.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, required this.preferences, this.onTest});

  final AppPreferences preferences;

  /// "Probar recordatorio": shows the daily reminder now.
  final VoidCallback? onTest;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<Preference, bool>>(
    stream: preferences.watch(),
    builder: (context, prefs) {
      bool on(Preference p) => prefs.data?[p] ?? p.defaultValue;
      ToggleRow toggle(
        Preference p,
        String label, {
        IconData? icon,
        String? subtitle,
        bool first = false,
      }) => ToggleRow(
        icon: icon,
        label: label,
        subtitle: subtitle,
        first: first,
        value: on(p),
        onTap: () => preferences.set(p, !on(p)),
      );
      return StreamBuilder<String>(
        stream: preferences.watchText(TextPreference.reminderTime),
        builder: (context, time) => SubPage(
          title: 'Recordatorios',
          children: [
            SettingsGroup(
              title: 'Recordatorio diario',
              rows: [
                toggle(
                  Preference.dailyReminder,
                  'Recordarme registrar mis gastos',
                  icon: DesignIcons.notifications,
                  first: true,
                ),
                ChoiceRow(
                  label: 'Hora del aviso',
                  options: const ['20:00', '21:00', '22:00'],
                  selected:
                      time.data ?? TextPreference.reminderTime.defaultValue,
                  onSelected: (v) =>
                      preferences.setText(TextPreference.reminderTime, v),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Resúmenes',
              rows: [
                toggle(
                  Preference.weeklyRecap,
                  'Recap semanal',
                  icon: DesignIcons.calendarViewWeek,
                  subtitle: 'Lunes 09:00',
                  first: true,
                ),
                toggle(
                  Preference.monthlyRecap,
                  'Recap mensual',
                  icon: DesignIcons.calendarMonth,
                  subtitle: 'Día 1 · 09:00',
                ),
              ],
            ),
            SettingsGroup(
              title: 'Avisos',
              rows: [
                toggle(
                  Preference.coachTips,
                  'Avisos del Coach',
                  icon: DesignIcons.autoAwesome,
                  first: true,
                ),
                toggle(
                  Preference.budgetAlert,
                  'Alerta al 80% del presupuesto',
                  icon: DesignIcons.warning,
                ),
              ],
            ),
            if (onTest != null) ...[
              const SizedBox(height: 8),
              OutlineAction(
                icon: DesignIcons.notificationsActive,
                label: 'Probar recordatorio',
                onTap: onTest!,
              ),
            ],
          ],
        ),
      );
    },
  );
}

/// Personalizar Coach: tone, unusual spending and memory.
class CoachSettingsScreen extends StatelessWidget {
  const CoachSettingsScreen({
    super.key,
    required this.preferences,
    required this.onOpenHistory,
    this.onOpenModel,
  });

  final AppPreferences preferences;
  final VoidCallback onOpenHistory;
  final VoidCallback? onOpenModel;

  @override
  Widget build(BuildContext context) => StreamBuilder<Map<Preference, bool>>(
    stream: preferences.watch(),
    builder: (context, prefs) {
      bool on(Preference p) => prefs.data?[p] ?? p.defaultValue;
      return StreamBuilder<String>(
        stream: preferences.watchText(TextPreference.coachTone),
        builder: (context, tone) => SubPage(
          title: 'Personalizar Coach',
          children: [
            SettingsGroup(
              title: 'Identidad',
              rows: [
                ChoiceRow(
                  first: true,
                  label: 'Tono',
                  options: const ['Directo', 'Amable', 'Motivador'],
                  selected: tone.data ?? TextPreference.coachTone.defaultValue,
                  onSelected: (v) =>
                      preferences.setText(TextPreference.coachTone, v),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Avisos proactivos',
              rows: [
                ToggleRow(
                  first: true,
                  icon: DesignIcons.error,
                  label: 'Detectar gastos inusuales',
                  value: on(Preference.detectUnusual),
                  onTap: () => preferences.set(
                    Preference.detectUnusual,
                    !on(Preference.detectUnusual),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: 'Memoria',
              rows: [
                ToggleRow(
                  first: true,
                  icon: DesignIcons.history,
                  label: 'Recordar conversaciones anteriores',
                  subtitle: 'Guarda tus chats en este dispositivo',
                  value: on(Preference.coachMemory),
                  onTap: () => preferences.set(
                    Preference.coachMemory,
                    !on(Preference.coachMemory),
                  ),
                ),
                SettingRow(
                  icon: DesignIcons.forum,
                  label: 'Historial de conversaciones',
                  onTap: onOpenHistory,
                ),
              ],
            ),
            if (onOpenModel != null)
              SettingsGroup(
                title: 'Inteligencia artificial',
                rows: [
                  SettingRow(
                    first: true,
                    icon: DesignIcons.memory,
                    label: 'Modelo de IA',
                    subtitle: 'OpenAI con tu propia clave',
                    onTap: onOpenModel,
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

/// Seguridad: lock the app with the fingerprint or the phone's lock.
class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, this.authenticator});

  final LocalAuthenticator? authenticator;

  Future<void> _toggle(BuildContext context, AppLockSettings appLock) async {
    // Both turning the lock on and off require the device owner, so a
    // borrowed unlocked phone cannot change it and enabling it proves the
    // device can actually unlock the app afterwards.
    final result = await (authenticator ?? SystemLocalAuthenticator())
        .authenticate();
    if (!context.mounted) return;
    switch (result) {
      case LocalAuthenticationResult.authenticated:
        await appLock.setEnabled(!appLock.enabled);
      case LocalAuthenticationResult.unavailable:
        showUndoToast(
          context,
          'Configura una huella o un bloqueo de pantalla en tu teléfono primero.',
        );
      case LocalAuthenticationResult.rejected:
      case LocalAuthenticationResult.error:
        showUndoToast(context, 'No se pudo confirmar tu identidad.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appLock = AppLockScope.maybeOf(context);
    return SubPage(
      title: 'Seguridad',
      children: [
        SettingsGroup(
          title: 'Bloqueo',
          rows: [
            ToggleRow(
              first: true,
              icon: DesignIcons.lock,
              label: 'Bloqueo con huella',
              subtitle: 'Pide tu huella o el bloqueo del teléfono al abrir',
              value: appLock?.enabled ?? false,
              onTap: appLock == null ? () {} : () => _toggle(context, appLock),
            ),
          ],
        ),
      ],
    );
  }
}

/// Categorías: expenses and incomes with their caps; each opens its detail.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key, required this.onOpen});

  final ValueChanged<Category> onOpen;

  @override
  Widget build(BuildContext context) {
    final budgets = LedgerScope.of(context).budgets;
    SettingRow row(Category c, bool first, {bool cap = true}) {
      final limit = budgetFor(c, budgets);
      return SettingRow(
        first: first,
        icon: CategoryStyle.of(c).icon,
        label: c.label,
        value: !cap
            ? ''
            : limit == null
            ? 'Sin tope'
            : 'Tope ${Fmt.money0(limit / 100)}',
        onTap: () => onOpen(c),
      );
    }

    final expenses = [...Category.expenses, Category.otros];
    final incomes = [Category.sueldo, Category.extra];
    return SubPage(
      title: 'Categorías',
      children: [
        SettingsGroup(
          title: 'Gastos',
          rows: [for (final (i, c) in expenses.indexed) row(c, i == 0)],
        ),
        SettingsGroup(
          title: 'Ingresos',
          rows: [
            for (final (i, c) in incomes.indexed) row(c, i == 0, cap: false),
          ],
        ),
      ],
    );
  }
}
