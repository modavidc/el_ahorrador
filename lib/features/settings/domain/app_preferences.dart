/// Toggles of Ajustes and small per-user flags.
enum Preference {
  autoCategorize('auto_categorize', true),

  /// Presupuestos → "Usar presupuesto mensual".
  useMonthlyBudget('budget_on', true),

  /// Recordatorios: daily reminder, recaps and notices.
  dailyReminder('reminder_daily', true),
  weeklyRecap('recap_weekly', true),
  monthlyRecap('recap_monthly', true),
  coachTips('coach_tips', true),
  budgetAlert('budget_alert', true),

  /// Personalizar Coach.
  detectUnusual('coach_unusual', true),
  coachMemory('coach_memory', true),

  /// The welcome was shown once.
  onboardingDone('onboarding_done', false);

  const Preference(this.key, this.defaultValue);

  final String key;
  final bool defaultValue;
}

/// Choices of Ajustes stored as text.
enum TextPreference {
  /// Personalizar Coach → Tono.
  coachTone('coach_tone', 'Amable'),

  /// Recordatorios → Hora del aviso.
  reminderTime('reminder_time', '21:00');

  const TextPreference(this.key, this.defaultValue);

  final String key;
  final String defaultValue;
}

abstract interface class AppPreferences {
  Stream<Map<Preference, bool>> watch();
  Future<bool> get(Preference preference);
  Future<void> set(Preference preference, bool value);

  Stream<String> watchText(TextPreference preference);
  Future<void> setText(TextPreference preference, String value);

  /// Notices of Movimientos the user closed with ×.
  Stream<Set<String>> watchDismissedNotices();
  Future<void> dismissNotice(String key);
}
