import 'package:el_ahorrador/features/ledger/domain/category.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

/// What a sentence like "almuerzo 18 soles con yape" means (Dictar and
/// natural-language entry), resolved against the user's accounts.
final class InterpretedEntry {
  const InterpretedEntry({
    required this.type,
    required this.amount,
    required this.category,
    required this.account,
    required this.note,
    required this.yape,
  });

  final MovementType type;
  final String? amount;
  final Category category;
  final String account;
  final String note;
  final bool yape;

  String get hint =>
      '${type == MovementType.income ? 'Ingreso' : 'Gasto'} · ${category.label} · '
      '$account${yape ? ' · Yape' : ''}. Revisa y guarda.';
}

InterpretedEntry interpretEntry(
  String text, {
  required List<LedgerAccount> accounts,
}) {
  final low = text.toLowerCase();
  final amount = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(low)?.group(1);

  const keywords = <(Category, List<String>)>[
    (
      Category.comida,
      [
        'almuerzo',
        'menu',
        'menú',
        'cena',
        'desayuno',
        'rappi',
        'pizza',
        'café',
        'cafe',
        'pollo',
      ],
    ),
    (Category.mercado, ['mercado', 'bodega', 'plaza vea', 'tottus', 'tambo']),
    (
      Category.transporte,
      ['uber', 'taxi', 'indrive', 'bus', 'metro', 'pasaje'],
    ),
    (Category.ocio, ['cine', 'bar', 'cerveza', 'concierto']),
    (Category.salud, ['farmacia', 'inkafarma', 'doctor']),
    (Category.compras, ['ropa', 'zapatillas', 'saga']),
    (Category.servicios, ['luz', 'agua', 'internet', 'plan']),
    (Category.casa, ['alquiler', 'casa']),
    (Category.sueldo, ['sueldo', 'quincena', 'salario']),
    (Category.extra, ['freelance', 'cliente', 'proyecto', 'me pagaron']),
  ];
  // Whole words only: "quincena" must not match "cena".
  bool mentions(String word) => RegExp(
    '(^|[^a-z0-9áéíóúñ])${RegExp.escape(word)}(\$|[^a-z0-9áéíóúñ])',
  ).hasMatch(low);
  var category = Category.otros;
  for (final (c, words) in keywords) {
    if (words.any(mentions)) {
      category = c;
      break;
    }
  }

  LedgerAccount? byName(bool Function(LedgerAccount a) test) {
    for (final a in accounts) {
      if (test(a)) return a;
    }
    return null;
  }

  final account =
      byName((a) => low.contains(a.name.toLowerCase())) ??
      (low.contains('visa') || low.contains('tarjeta')
          ? byName((a) => a.isLiability)
          : null) ??
      (low.contains('efectivo')
          ? byName((a) => a.name.toLowerCase().contains('efectivo'))
          : null) ??
      (accounts.isEmpty ? null : accounts.first);

  var note = text
      .replaceFirst(RegExp(r'\d+(?:[.,]\d{1,2})?'), '')
      .replaceAll(
        RegExp(
          r'soles|s\/\.?|con (la )?visa|con yape|en efectivo|con tarjeta',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (note.isNotEmpty) note = note[0].toUpperCase() + note.substring(1);

  return InterpretedEntry(
    type: category.isIncome ? MovementType.income : MovementType.expense,
    amount: amount?.replaceAll(',', '.'),
    category: category,
    account: account?.name ?? '',
    note: note,
    yape: low.contains('yape'),
  );
}
