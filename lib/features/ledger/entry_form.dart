import '../../data/money_manager_taxonomy.dart';
import '../../theme/design_tokens.dart';
import 'ledger.dart';

/// Whether a category name belongs to the income side. In the Money Manager
/// taxonomy every category from "Salario" onwards is income; other names are
/// classified by their designed style (Salario, Freelance, Inversiones).
bool isIncomeCategory(String name) {
  final index = moneyManagerCategorySeeds.indexWhere((s) => s.name == name);
  final firstIncome = moneyManagerCategorySeeds.indexWhere(
    (s) => s.name == 'Salario',
  );
  if (index >= 0) return index >= firstIncome;
  final style = CategoryStyle.forName(name);
  return identical(style, CategoryStyle.salario) ||
      identical(style, CategoryStyle.freelance) ||
      identical(style, CategoryStyle.inversiones);
}

/// Result of "Escribe en lenguaje natural" (prototype `interpret()`),
/// resolved against the user's own categories and accounts.
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
  final String category;
  final String account;
  final String note;
  final bool yape;

  String get hint =>
      '${type == MovementType.income ? 'Ingreso' : 'Gasto'} · $category · '
      '$account${yape ? ' · Yape' : ''}. Revisa y guarda.';
}

InterpretedEntry interpretEntry(
  String text, {
  required List<String> categories,
  required List<LedgerAccount> accounts,
}) {
  final low = text.toLowerCase();
  final amount = RegExp(r'(\d+(?:[.,]\d{1,2})?)').firstMatch(low)?.group(1);

  const keywords = <(CategoryStyle, List<String>)>[
    (
      CategoryStyle.comida,
      [
        'almuerzo',
        'menu',
        'menú',
        'cena',
        'rappi',
        'pizza',
        'café',
        'cafe',
        'plaza vea',
        'tottus',
        'pollo',
      ],
    ),
    (CategoryStyle.transporte, ['uber', 'taxi', 'indrive', 'bus', 'metro']),
    (CategoryStyle.ocio, ['cine', 'bar', 'cerveza', 'concierto']),
    (CategoryStyle.salud, ['farmacia', 'inkafarma', 'doctor']),
    (CategoryStyle.compras, ['ropa', 'zapatillas', 'saga']),
    (CategoryStyle.servicios, ['luz', 'agua', 'internet', 'plan']),
    (CategoryStyle.salario, ['sueldo', 'quincena', 'salario']),
    (CategoryStyle.freelance, ['freelance', 'cliente', 'proyecto']),
  ];
  var category = categories.firstWhere(
    (c) => identical(CategoryStyle.forName(c), CategoryStyle.otros),
    orElse: () => categories.isEmpty ? 'Otros' : categories.last,
  );
  // Whole words only: "quincena" must not match "cena".
  bool mentions(String word) => RegExp(
    '(^|[^a-z0-9áéíóúñ])${RegExp.escape(word)}(\$|[^a-z0-9áéíóúñ])',
  ).hasMatch(low);
  for (final (style, words) in keywords) {
    if (!words.any(mentions)) continue;
    final match = categories.where(
      (c) => identical(CategoryStyle.forName(c), style),
    );
    if (match.isNotEmpty) {
      category = match.first;
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
    type: isIncomeCategory(category)
        ? MovementType.income
        : MovementType.expense,
    amount: amount?.replaceAll(',', '.'),
    category: category,
    account: account?.name ?? '',
    note: note,
    yape: low.contains('yape'),
  );
}
