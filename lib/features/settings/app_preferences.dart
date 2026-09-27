import '../../data/app_database.dart';

/// Toggles of Ajustes → Coach e IA, persisted in the `app_settings` table.
enum Preference {
  autoCategorize('auto_categorize', true),
  saveOcrWithoutReview('ocr_auto_save', true),
  weeklyCoachSummary('coach_weekly', true);

  const Preference(this.key, this.defaultValue);

  final String key;
  final bool defaultValue;
}

class AppPreferences {
  AppPreferences(this._db);

  final AppDatabase _db;

  Stream<Map<Preference, bool>> watch() =>
      _db.select(_db.appSettings).watch().map((rows) {
        final stored = {for (final r in rows) r.key: r.value};
        return {
          for (final p in Preference.values)
            p: switch (stored[p.key]) {
              'true' => true,
              'false' => false,
              _ => p.defaultValue,
            },
        };
      });

  Future<void> set(Preference preference, bool value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: preference.key, value: '$value'),
      );

  Future<bool> get(Preference preference) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(preference.key))).getSingleOrNull();
    return row == null ? preference.defaultValue : row.value == 'true';
  }

  static const _dismissedKey = 'dismissed_notices';

  /// Notices of Movimientos the user closed with ×.
  Stream<Set<String>> watchDismissedNotices() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(_dismissedKey)))
          .watchSingleOrNull()
          .map((row) => _split(row?.value));

  Future<void> dismissNotice(String key) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(_dismissedKey))).getSingleOrNull();
    final keys = _split(row?.value)..add(key);
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: _dismissedKey,
            value: keys.join('\n'),
          ),
        );
  }

  static Set<String> _split(String? value) =>
      {...?value?.split('\n')}..remove('');
}
