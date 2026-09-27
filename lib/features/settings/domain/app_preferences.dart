/// Toggles of Ajustes and small per-user flags.
enum Preference {
  autoCategorize('auto_categorize', true),
  saveOcrWithoutReview('ocr_auto_save', true),
  weeklyCoachSummary('coach_weekly', true);

  const Preference(this.key, this.defaultValue);

  final String key;
  final bool defaultValue;
}

abstract interface class AppPreferences {
  Stream<Map<Preference, bool>> watch();
  Future<bool> get(Preference preference);
  Future<void> set(Preference preference, bool value);

  /// Notices of Movimientos the user closed with ×.
  Stream<Set<String>> watchDismissedNotices();
  Future<void> dismissNotice(String key);
}
