/// The 11 categories of the v3 design. Stored category names (including the
/// older Money Manager taxonomy of existing installs) map onto them by
/// keyword, so every screen and rule speaks the same categories.
enum Category {
  comida('Comida'),
  mercado('Mercado'),
  transporte('Transporte'),
  casa('Casa'),
  servicios('Servicios'),
  salud('Salud'),
  ocio('Ocio'),
  compras('Compras'),
  sueldo('Sueldo'),
  extra('Extra'),
  otros('Otros');

  const Category(this.label);

  final String label;

  bool get isIncome => this == sueldo || this == extra;

  /// Offered when registering an expense, in the prototype's order.
  static const expenses = [
    comida,
    mercado,
    transporte,
    casa,
    servicios,
    salud,
    ocio,
    compras,
  ];

  /// Offered when registering an income.
  static const incomes = [sueldo, extra, otros];

  /// The v3 category a stored name belongs to; [otros] when unknown.
  static Category of(String? name) {
    final key = _normalize(name ?? '');
    for (final c in values) {
      if (key == _normalize(c.label)) return c;
    }
    for (final (words, category) in _keywords) {
      if (words.any(key.contains)) return category;
    }
    return otros;
  }

  static const _keywords = <(List<String>, Category)>[
    (['suscrip'], ocio),
    (['mercado', 'supermerc', 'bodega'], mercado),
    (['comida', 'aliment', 'restaur'], comida),
    (['casa', 'hogar', 'vivienda', 'electrodom', 'alquiler', 'familia'], casa),
    (['transporte', 'taxi', 'movilidad', 'educacion', 'curso'], transporte),
    (['servicio', 'internet', 'luz', 'agua'], servicios),
    (['ocio', 'entreten', 'deporte', 'cultura', 'mascota'], ocio),
    (['compras', 'ropa', 'electronic', 'oficina', 'regalo'], compras),
    (['salud', 'cuidado personal', 'farmacia'], salud),
    (['salario', 'sueldo', 't-cuida'], sueldo),
    (
      [
        'extra',
        'freelance',
        'upwork',
        'mantenimiento web',
        'tecnico',
        'afiliado',
        'inversion',
        'binance',
        'p2p',
      ],
      extra,
    ),
  ];

  static String _normalize(String value) => value
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}
