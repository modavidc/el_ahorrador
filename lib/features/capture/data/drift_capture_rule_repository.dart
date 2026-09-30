import 'dart:convert';

import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/domain/capture_ports.dart';
import 'package:el_ahorrador/features/capture/domain/capture_rule.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// [CaptureRuleRepository] stored as JSON in `app_settings`.
class DriftCaptureRuleRepository implements CaptureRuleRepository {
  DriftCaptureRuleRepository(this._db);

  final AppDatabase _db;

  static const _key = 'capture_rules';

  @override
  Stream<List<CaptureRule>> watch() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(_key)))
          .watchSingleOrNull()
          .map((row) => _decode(row?.value));

  @override
  Future<List<CaptureRule>> load() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(_key))).getSingleOrNull();
    return _decode(row?.value);
  }

  @override
  Future<void> save(List<CaptureRule> rules) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: _key,
          value: jsonEncode([for (final r in rules) _toJson(r)]),
        ),
      );

  @override
  Future<void> update(CaptureRule rule) async {
    final rules = await load();
    await save([for (final r in rules) r.id == rule.id ? rule : r]);
  }

  static List<CaptureRule> _decode(String? json) {
    if (json == null) return CaptureRule.defaults;
    try {
      return [
        for (final j in jsonDecode(json) as List)
          _fromJson(j as Map<String, dynamic>),
      ];
    } on Object {
      return CaptureRule.defaults;
    }
  }

  static Map<String, Object> _toJson(CaptureRule r) => {
    'id': r.id,
    'from': r.from,
    'keywords': r.keywords,
    'type': r.type.name,
    'account': r.account,
    'category': r.category,
    'enabled': r.enabled,
  };

  static CaptureRule _fromJson(Map<String, dynamic> j) => CaptureRule(
    id: j['id'] as String,
    from: j['from'] as String,
    keywords: [for (final k in j['keywords'] as List) k as String],
    type: MovementType.values.byName(j['type'] as String),
    account: j['account'] as String,
    category: j['category'] as String,
    enabled: j['enabled'] as bool,
  );
}
