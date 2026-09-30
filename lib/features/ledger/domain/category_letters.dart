import 'package:el_ahorrador/features/ledger/domain/category.dart';

/// One letter per category ("C" → Comida) to register without choosing:
/// "C 15" when writing or dictating, or "C" as the message of a Yape.
final class CategoryLetters {
  const CategoryLetters(this.byLetter);

  /// Letters of a new install, editable in Ajustes → Categorías.
  static const defaults = CategoryLetters({
    'C': Category.comida,
    'M': Category.mercado,
    'T': Category.transporte,
    'H': Category.casa,
    'L': Category.servicios,
    'S': Category.salud,
    'O': Category.ocio,
    'R': Category.compras,
  });

  /// Upper-case letter → category.
  final Map<String, Category> byLetter;

  Category? operator [](String letter) => byLetter[letter.toUpperCase()];

  String? letterOf(Category category) {
    for (final MapEntry(:key, :value) in byLetter.entries) {
      if (value == category) return key;
    }
    return null;
  }

  /// [category] with [letter], or without one when [letter] is null. A
  /// letter belongs to one category: taking it frees its previous owner.
  CategoryLetters assign(Category category, String? letter) => CategoryLetters({
    for (final MapEntry(:key, :value) in byLetter.entries)
      if (value != category && key != letter?.toUpperCase()) key: value,
    if (letter != null) letter.toUpperCase(): category,
  });

  /// The category of a payment message that starts with a letter on its
  /// own: "C", "c", "T pasaje", "M - bodega". Words ("Carla", "a mi mamá")
  /// and letters without a category give null.
  Category? fromMessage(String? message) {
    final m = RegExp(
      r'^\s*([a-zA-Z])(?:$|[\s.,:;\-]+)',
    ).firstMatch(message ?? '');
    return m == null ? null : this[m.group(1)!];
  }

  /// "C 15", "c15.50 menú": a letter with a category, the amount and an
  /// optional note.
  LetterEntry? parse(String text) {
    final m = RegExp(
      r'^\s*([a-zA-Z])\s*(\d+(?:[.,]\d{1,2})?)(?:\s+(.+?))?\s*$',
    ).firstMatch(text);
    if (m == null) return null;
    final category = this[m.group(1)!];
    final amount = double.tryParse(m.group(2)!.replaceAll(',', '.'));
    if (category == null || amount == null || amount <= 0) return null;
    return LetterEntry(
      category: category,
      amountCents: (amount * 100).round(),
      note: m.group(3),
    );
  }

  /// "C=Comida" lines, as stored.
  String encode() => [
    for (final MapEntry(:key, :value) in byLetter.entries) '$key=${value.name}',
  ].join('\n');

  static CategoryLetters decode(String? stored) {
    if (stored == null) return defaults;
    final letters = <String, Category>{};
    for (final line in stored.split('\n')) {
      final [letter, name] = line
          .split('=')
          .followedBy(['', ''])
          .take(2)
          .toList();
      final category = Category.values.where((c) => c.name == name).firstOrNull;
      if (letter.length == 1 && category != null) {
        letters[letter.toUpperCase()] = category;
      }
    }
    return CategoryLetters(letters);
  }
}

/// What "C 15 menú" means.
final class LetterEntry {
  const LetterEntry({
    required this.category,
    required this.amountCents,
    this.note,
  });

  final Category category;
  final int amountCents;
  final String? note;
}
