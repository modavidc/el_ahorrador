import 'dart:convert';

import '../../data/app_database.dart';
import '../ledger/ledger.dart';
import 'receipt_reader.dart';

/// "Si llega de {from} con {match}": sets the type, account and category of
/// captured payments (Ajustes → Captura → Reglas de captura).
final class CaptureRule {
  const CaptureRule({
    required this.id,
    required this.from,
    required this.keywords,
    required this.type,
    required this.account,
    required this.category,
    required this.enabled,
  });

  final String id;

  /// Source the receipt must come from: "Yape", "BCP"… or "Comercio" for
  /// merchant rules, which match any source.
  final String from;

  /// Any of these words in the receipt triggers the rule.
  final List<String> keywords;
  final MovementType type;
  final String account;

  /// A category name, or [automatic] to guess it from the merchant.
  final String category;
  final bool enabled;

  static const automatic = 'Auto';

  bool get isMerchant => from == ReceiptSource.other.label;

  /// "“Yapeaste”" or "Tambo, Oxxo, Listo".
  String get matchLabel => keywords.length == 1 && !isMerchant
      ? '“${keywords.single}”'
      : keywords.join(', ');

  bool matches(ReceiptReading r) {
    if (!enabled) return false;
    if (!isMerchant && r.source.label != from) return false;
    // Merchant rules look at who was paid only: words like "Listo" also
    // appear as buttons in receipts.
    final haystack = isMerchant ? (r.counterpart ?? '').toLowerCase() : r.text;
    return keywords.any((k) => haystack.contains(k.toLowerCase()));
  }

  CaptureRule copyWith({
    MovementType? type,
    String? account,
    String? category,
    bool? enabled,
  }) => CaptureRule(
    id: id,
    from: from,
    keywords: keywords,
    type: type ?? this.type,
    account: account ?? this.account,
    category: category ?? this.category,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'from': from,
    'keywords': keywords,
    'type': type.name,
    'account': account,
    'category': category,
    'enabled': enabled,
  };

  static CaptureRule fromJson(Map<String, dynamic> j) => CaptureRule(
    id: j['id'] as String,
    from: j['from'] as String,
    keywords: [for (final k in j['keywords'] as List) k as String],
    type: MovementType.values.byName(j['type'] as String),
    account: j['account'] as String,
    category: j['category'] as String,
    enabled: j['enabled'] as bool,
  );

  /// The prototype's five rules.
  static const defaults = [
    CaptureRule(
      id: 'r1',
      from: 'Yape',
      keywords: ['Yapeaste'],
      type: MovementType.expense,
      account: 'Yape',
      category: automatic,
      enabled: true,
    ),
    CaptureRule(
      id: 'r2',
      from: 'Yape',
      keywords: ['Te yapearon'],
      type: MovementType.income,
      account: 'Yape',
      category: 'Extra',
      enabled: true,
    ),
    CaptureRule(
      id: 'r3',
      from: 'BCP',
      keywords: ['Consumo con tu tarjeta'],
      type: MovementType.expense,
      account: 'BCP',
      category: automatic,
      enabled: true,
    ),
    CaptureRule(
      id: 'r4',
      from: 'Comercio',
      keywords: ['Tambo', 'Oxxo', 'Listo'],
      type: MovementType.expense,
      account: 'Yape',
      category: 'Comida',
      enabled: true,
    ),
    CaptureRule(
      id: 'r5',
      from: 'Comercio',
      keywords: ['Uber', 'Cabify', 'InDrive'],
      type: MovementType.expense,
      account: 'BBVA Visa',
      category: 'Transporte',
      enabled: false,
    ),
  ];
}

/// Rules persisted as JSON in `app_settings`.
class CaptureRuleStore {
  CaptureRuleStore(this._db);

  final AppDatabase _db;

  static const _key = 'capture_rules';

  Stream<List<CaptureRule>> watch() =>
      (_db.select(_db.appSettings)..where((s) => s.key.equals(_key)))
          .watchSingleOrNull()
          .map((row) => _decode(row?.value));

  Future<List<CaptureRule>> load() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((s) => s.key.equals(_key))).getSingleOrNull();
    return _decode(row?.value);
  }

  Future<void> save(List<CaptureRule> rules) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: _key,
          value: jsonEncode([for (final r in rules) r.toJson()]),
        ),
      );

  Future<void> update(CaptureRule rule) async {
    final rules = await load();
    await save([for (final r in rules) r.id == rule.id ? rule : r]);
  }

  static List<CaptureRule> _decode(String? json) {
    if (json == null) return CaptureRule.defaults;
    try {
      return [
        for (final j in jsonDecode(json) as List)
          CaptureRule.fromJson(j as Map<String, dynamic>),
      ];
    } on Object {
      return CaptureRule.defaults;
    }
  }
}

/// Category guessed from the merchant when a rule says "Automática (IA)".
/// Null when nothing is recognised: the payment goes to Por revisar.
String? guessCategory(ReceiptReading r) {
  if (r.direction == ReceiptDirection.received) return 'Extra';
  final text = '${r.counterpart ?? ''} ${r.text}'.toLowerCase();
  const words = <String, List<String>>{
    'Mercado': [
      'bodega',
      'tambo',
      'oxxo',
      'listo',
      'plaza vea',
      'tottus',
      'wong',
      'vivanda',
      'metro ',
      'mass',
      'makro',
      'mercado',
      'minimarket',
    ],
    'Comida': [
      'poller',
      'restaurant',
      'chifa',
      'cevich',
      'menú',
      'menu',
      'café',
      'cafe',
      'pizza',
      'rappi',
      'pedidosya',
      'kfc',
      'bembos',
      'starbucks',
      'panader',
    ],
    'Transporte': [
      'uber',
      'cabify',
      'indrive',
      'didi',
      'taxi',
      'metropolitano',
      'grifo',
      'repsol',
      'primax',
    ],
    'Salud': [
      'farmacia',
      'inkafarma',
      'mifarma',
      'botica',
      'clínica',
      'clinica',
    ],
    'Servicios': [
      'luz del sur',
      'enel',
      'sedapal',
      'claro',
      'movistar',
      'entel',
      'bitel',
      'internet',
    ],
    'Ocio': ['cine', 'netflix', 'spotify', 'disney', 'teleticket', 'joinnus'],
    'Compras': [
      'saga',
      'ripley',
      'falabella',
      'oechsle',
      'zara',
      'promart',
      'sodimac',
    ],
  };
  for (final MapEntry(key: category, value: list) in words.entries) {
    if (list.any(text.contains)) return category;
  }
  return null;
}
