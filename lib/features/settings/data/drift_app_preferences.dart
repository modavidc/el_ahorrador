import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/settings/domain/app_preferences.dart';

/// Toggles of Ajustes → Coach e IA, persisted in the `app_settings` table.
/// [AppPreferences] in the `app_settings` table.
class DriftAppPreferences implements AppPreferences {
  DriftAppPreferences(this._db);

  final AppDatabase _db;

  @override
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

  @override
  Future<void> set(Preference preference, bool value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: preference.key, value: '$value'),
      );

  @override
  Future<bool> get(Preference preference) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(preference.key))).getSingleOrNull();
    return row == null ? preference.defaultValue : row.value == 'true';
  }

  @override
  Stream<String> watchText(TextPreference preference) =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(preference.key)))
          .watchSingleOrNull()
          .map((row) => row?.value ?? preference.defaultValue);

  @override
  Future<void> setText(TextPreference preference, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: preference.key, value: value),
      );

  static const _dismissedKey = 'dismissed_notices';

  @override
  Stream<Set<String>> watchDismissedNotices() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(_dismissedKey)))
          .watchSingleOrNull()
          .map((row) => _split(row?.value));

  @override
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
