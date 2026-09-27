import 'package:flutter/material.dart';

/// Design handoff v3 (`design/README.md` and `Tema El Ahorrador v3.dc.html`).
/// Screens must take every color, text style, spacing, radius, shadow and
/// icon from here; `test/design_tokens_usage_test.dart` fails on hex colors or
/// font sizes written directly in the UI.
abstract final class DesignColors {
  // v3 palette: paper, ink and brand red.
  static const paper = Color(0xFFFAF6F1);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C1917);
  static const ink2 = Color(0xFF6E6660);

  /// Calendar expense figures (#4A433D).
  static const ink3 = Color(0xFF4A433D);

  /// Placeholder amount "0" and disabled text (#C9BFB5).
  static const inkFaint = Color(0xFFC9BFB5);

  /// Days outside the month in the calendar (#D3C9BF).
  static const inkOut = Color(0xFFD3C9BF);
  static const red = Color(0xFFD33F2B);
  static const redDeep = Color(0xFFA82E1E);
  static const blush = Color(0xFFFBEAE5);

  /// Unselected chip, segment track and secondary button.
  static const chip = Color(0xFFF1EAE2);

  /// Neutral icon tiles and source pills.
  static const tile = Color(0xFFF5EFE8);
  static const line = Color(0xFFEDE6DE);
  static const lineSoft = Color(0xFFF1EAE2);
  static const lineStrong = Color(0xFFE3D9CF);

  /// Disabled "Guardar" button.
  static const disabled = Color(0xFFD8CEC4);
  static const green = Color(0xFF1E7D47);
  static const greenSoft = Color(0xFFE6F3EA);
  static const amber = Color(0xFFC77A12);
  static const amberDeep = Color(0xFFA15F00);
  static const amberSoft = Color(0xFFFDF1DC);

  /// Icon of the dark "Prueba la función principal" notice.
  static const onDarkAccent = Color(0xFFFF9C8C);
  static const onDarkText = Color(0xFFE6DED5);
  static const onDarkClose = Color(0xFFCFC6BC);

  /// rgba(255,255,255,.12): icon tile over ink.
  static const onDarkTile = Color(0x1FFFFFFF);

  /// rgba(28,25,23,.45): scrim behind sheets and the + menu.
  static const scrim = Color(0x731C1917);

  // Names used by screens not yet redrawn for v3, mapped onto its palette.
  static const primary = red;
  static const primaryPressed = redDeep;
  static const primarySoft = blush;
  static const onPrimary = card;
  static const income = green;
  static const expense = ink;
  static const neutralAmount = ink2;
  static const success = green;
  static const successSoft = greenSoft;
  static const ai = red;
  static const aiSoft = blush;
  static const warning = amber;
  static const textPrimary = ink;
  static const textSecondary = ink2;
  static const textTertiary = ink2;
  static const textDisabled = inkFaint;
  static const textInverse = card;
  static const background = paper;
  static const surfaceCard = card;
  static const inputFill = tile;
  static const inverse = ink;
  static const border = line;
  static const borderSubtle = lineSoft;
  static const borderInput = lineStrong;
  static const selectedSoft = blush;
  static const toggleTrackOff = lineStrong;
  static const fabLabel = ink;
  static const toastIcon = Color(0xFF7FD6A0);
  static const cameraBackground = ink;
}

/// Schibsted Grotesk, the only family of v3 (proportional figures, as the
/// prototype renders them).
abstract final class DesignText {
  static const family = 'SchibstedGrotesk';

  static TextStyle style(
    double size,
    FontWeight weight, {
    double? letterSpacing,
    double? height,
  }) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    height: height ?? normalLineHeight(size),
    letterSpacing: letterSpacing == null ? null : letterSpacing * size,
    color: DesignColors.ink,
  );

  /// The browser's `line-height: normal` for Schibsted Grotesk: typo
  /// ascender (2000) and descender (528) over 2048 units, each rounded to
  /// whole pixels as Chromium does.
  static double normalLineHeight(double size) =>
      ((2000 / 2048 * size).round() + (528 / 2048 * size).round()) / size;

  // v3 scale
  /// Tab title: 28/800, -0.03em, line-height 1.
  static final tabTitle = style(
    28,
    FontWeight.w800,
    letterSpacing: -.03,
    height: 1,
  );

  /// Onboarding headline.
  static final hero = style(
    40,
    FontWeight.w800,
    letterSpacing: -.03,
    height: 1.05,
  );

  /// Amount typed in the manual entry sheet.
  static final amountInput = style(
    52,
    FontWeight.w800,
    letterSpacing: -.03,
    height: 1,
  );

  /// "Puedes gastar hoy" figure.
  static final figure = style(
    30,
    FontWeight.w800,
    letterSpacing: -.03,
    height: 1.05,
  );
  static final currency = style(24, FontWeight.w700);
  static final dayNumber = style(
    22,
    FontWeight.w800,
    letterSpacing: -.02,
    height: 1,
  );
  static final keypad = style(22, FontWeight.w700);
  static final cardTitle = style(17, FontWeight.w800);
  static final subTitle = style(17, FontWeight.w700);
  static final button = style(16, FontWeight.w700);
  static final row = style(15, FontWeight.w600);
  static final rowAmount = style(15, FontWeight.w700);
  static final rowAmountStrong = style(15, FontWeight.w800);
  static final input = style(15, FontWeight.w400);
  static final body14 = style(14, FontWeight.w400);
  static final body14Semi = style(14, FontWeight.w600);
  static final body14Bold = style(14, FontWeight.w700);
  static final label13 = style(13, FontWeight.w400);
  static final label13Semi = style(13, FontWeight.w600);
  static final label13Bold = style(13, FontWeight.w700);
  static final small = style(12, FontWeight.w400);
  static final smallSemi = style(12, FontWeight.w600);
  static final smallBold = style(12, FontWeight.w700);

  /// Section label: 12/700, uppercase, +0.04em.
  static final section = style(12, FontWeight.w700, letterSpacing: .04);

  /// + menu group title: 12/700, +0.06em.
  static final menuGroup = style(12, FontWeight.w700, letterSpacing: .06);
  static final tiny = style(11, FontWeight.w600);
  static final tinyBold = style(11, FontWeight.w700);
  static final nav = style(12, FontWeight.w700);

  // Names used by screens not yet redrawn for v3.
  static final display = style(28, FontWeight.w800, letterSpacing: -.03);
  static final title = style(20, FontWeight.w700);
  static final sheetTitle = style(18, FontWeight.w700);
  static final headlineBold = style(16, FontWeight.w700);
  static final headline = style(16, FontWeight.w600);
  static final body = style(14, FontWeight.w400);
  static final bodyMedium = style(14, FontWeight.w500);
  static final bodyStrong = style(14, FontWeight.w600);
  static final label = style(13, FontWeight.w400);
  static final labelMedium = style(13, FontWeight.w500);
  static final labelStrong = style(13, FontWeight.w600);
  static final caption = style(12, FontWeight.w400);
  static final captionMedium = style(12, FontWeight.w500);
  static final captionStrong = style(12, FontWeight.w600);
  static final micro = style(11, FontWeight.w500);
  static final microRegular = style(11, FontWeight.w400);
  static final microStrong = style(11, FontWeight.w600);
  static final axis = style(11, FontWeight.w400);
}

abstract final class DesignSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
}

abstract final class DesignRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const tile = 14.0;
  static const segment = 10.0;
  static const md = 12.0;
  static const button = 14.0;
  static const lg = 16.0;
  static const cta = 18.0;
  static const notice = 20.0;
  static const card = 22.0;
  static const menu = 24.0;
  static const bigCard = 26.0;
  static const sheet = 32.0;
  static const pill = 999.0;
}

abstract final class DesignShadows {
  /// Card: 0 1px 2px rgba(60,30,10,.06)
  static final card = [css(const Color(0x0F3C1E0A), 1, 2)];

  /// Frequent-entry chip: 0 1px 2px rgba(60,30,10,.08)
  static final chip = [css(const Color(0x143C1E0A), 1, 2)];

  /// Selected segment: 0 1px 3px rgba(60,30,10,.12)
  static final segment = [css(const Color(0x1F3C1E0A), 1, 3)];

  /// + button: 0 10px 24px rgba(211,63,43,.4)
  static final fab = [css(const Color(0x66D33F2B), 10, 24)];

  /// + menu: 0 14px 40px rgba(28,25,23,.25)
  static final menu = [css(const Color(0x401C1917), 14, 40)];

  /// Coach input bar: 0 8px 24px rgba(60,30,10,.12)
  static final floating = [css(const Color(0x1F3C1E0A), 8, 24)];

  /// "Guardar" fixed at the bottom of a sheet: 0 -12px 16px paper.
  static final stickyPaper = [css(DesignColors.paper, -12, 16)];

  static final fabAction = menu;
  static final knob = [css(const Color(0x33000000), 1, 2)];
  static final bubble = card;
  static final receipt = [css(const Color(0x80000000), 10, 40)];

  /// CSS `box-shadow: 0 <dy>px <blur>px <color>`. CSS blurs with
  /// sigma = blur / 2, Flutter's BoxShadow with sigma = r * 0.57735 + 0.5,
  /// so the radius is converted to render the same shadow.
  static BoxShadow css(Color color, double dy, double blur) => BoxShadow(
    color: color,
    offset: Offset(0, dy),
    blurRadius: blur <= 1 ? 0 : (blur / 2 - 0.5) / 0.57735,
  );
}

/// Material Symbols Rounded (opsz 24, wght 400), bundled in `assets/fonts`
/// with FILL 0 and FILL 1. Code points from Google's `.codepoints` file.
abstract final class DesignIcons {
  static const _family = 'MaterialSymbolsRounded';
  static const _filledFamily = 'MaterialSymbolsRoundedFilled';

  /// The same symbol with FILL 1: active navigation icon and streak flame.
  /// Only the constants below exist, so release builds can still tree-shake
  /// both icon fonts.
  static IconData filled(IconData icon) => _filled[icon.codePoint] ?? icon;

  static const _filled = <int, IconData>{
    0xef6e: IconData(0xef6e, fontFamily: _filledFamily),
    0xe26b: IconData(0xe26b, fontFamily: _filledFamily),
    0xe65f: IconData(0xe65f, fontFamily: _filledFamily),
    0xe850: IconData(0xe850, fontFamily: _filledFamily),
    0xe8b8: IconData(0xe8b8, fontFamily: _filledFamily),
    0xef55: IconData(0xef55, fontFamily: _filledFamily),
  };

  static const backspace = IconData(0xe14a, fontFamily: _family);
  static const bolt = IconData(0xea0b, fontFamily: _family);
  static const burstMode = IconData(0xe43c, fontFamily: _family);
  static const check = IconData(0xe668, fontFamily: _family);
  static const contentCopy = IconData(0xe14d, fontFamily: _family);
  static const delete = IconData(0xe92e, fontFamily: _family);
  static const directionsCar = IconData(0xeff7, fontFamily: _family);
  static const editNote = IconData(0xe745, fontFamily: _family);
  static const event = IconData(0xe878, fontFamily: _family);
  static const favorite = IconData(0xe87e, fontFamily: _family);
  static const history = IconData(0xe8b3, fontFamily: _family);
  static const inbox = IconData(0xe156, fontFamily: _family);
  static const info = IconData(0xe88e, fontFamily: _family);
  static const photoLibrary = IconData(0xe413, fontFamily: _family);
  static const rule = IconData(0xf1c2, fontFamily: _family);
  static const localActivity = IconData(0xe553, fontFamily: _family);
  static const localFireDepartment = IconData(0xef55, fontFamily: _family);
  static const mic = IconData(0xe31d, fontFamily: _family);
  static const moreHoriz = IconData(0xe5d3, fontFamily: _family);
  static const nightlight = IconData(0xf03d, fontFamily: _family);
  static const qrCode2 = IconData(0xe00a, fontFamily: _family);
  static const replay = IconData(0xe042, fontFamily: _family);
  static const screenshotMonitor = IconData(0xec08, fontFamily: _family);
  static const share = IconData(0xe80d, fontFamily: _family);
  static const shoppingCart = IconData(0xe8cc, fontFamily: _family);
  static const trendingDown = IconData(0xe8e3, fontFamily: _family);
  static const verifiedUser = IconData(0xf013, fontFamily: _family);
  static const accountBalance = IconData(0xe84f, fontFamily: _family);
  static const accountBalanceWallet = IconData(0xe850, fontFamily: _family);
  static const add = IconData(0xe145, fontFamily: _family);
  static const arrowBack = IconData(0xe5c4, fontFamily: _family);
  static const arrowUpward = IconData(0xe5d8, fontFamily: _family);
  static const autoAwesome = IconData(0xe65f, fontFamily: _family);
  static const backup = IconData(0xe864, fontFamily: _family);
  static const barChart = IconData(0xe26b, fontFamily: _family);
  static const calendarMonth = IconData(0xebcc, fontFamily: _family);
  static const category = IconData(0xe72c, fontFamily: _family);
  static const checkCircle = IconData(0xf0be, fontFamily: _family);
  static const chevronLeft = IconData(0xe5cb, fontFamily: _family);
  static const chevronRight = IconData(0xe5cc, fontFamily: _family);
  static const close = IconData(0xe5cd, fontFamily: _family);
  static const creditCard = IconData(0xe8a1, fontFamily: _family);
  static const darkMode = IconData(0xe51c, fontFamily: _family);
  static const dateRange = IconData(0xe916, fontFamily: _family);
  static const deliveryDining = IconData(0xeb28, fontFamily: _family);
  static const documentScanner = IconData(0xe5fa, fontFamily: _family);
  static const edit = IconData(0xf097, fontFamily: _family);
  static const error = IconData(0xf8b6, fontFamily: _family);
  static const expandLess = IconData(0xe5ce, fontFamily: _family);
  static const expandMore = IconData(0xe5cf, fontFamily: _family);
  static const familyRestroom = IconData(0xf1a2, fontFamily: _family);
  static const home = IconData(0xe9b2, fontFamily: _family);
  static const localTaxi = IconData(0xe559, fontFamily: _family);
  static const lock = IconData(0xe899, fontFamily: _family);
  static const medication = IconData(0xf033, fontFamily: _family);
  static const memory = IconData(0xe322, fontFamily: _family);
  static const notifications = IconData(0xe7f5, fontFamily: _family);
  static const payments = IconData(0xef63, fontFamily: _family);
  static const photoCamera = IconData(0xe412, fontFamily: _family);
  static const receiptLong = IconData(0xef6e, fontFamily: _family);
  static const restaurant = IconData(0xe56c, fontFamily: _family);
  static const savings = IconData(0xe2eb, fontFamily: _family);
  static const school = IconData(0xe80c, fontFamily: _family);
  static const search = IconData(0xef7a, fontFamily: _family);
  static const settings = IconData(0xe8b8, fontFamily: _family);
  static const shoppingBag = IconData(0xf1cc, fontFamily: _family);
  static const smartphone = IconData(0xe7ba, fontFamily: _family);
  static const speed = IconData(0xe9e4, fontFamily: _family);
  static const sportsEsports = IconData(0xea28, fontFamily: _family);
  static const star = IconData(0xf09a, fontFamily: _family);
  static const subscriptions = IconData(0xe064, fontFamily: _family);
  static const swapHoriz = IconData(0xe8d4, fontFamily: _family);
  static const tableView = IconData(0xf1be, fontFamily: _family);
  static const trendingUp = IconData(0xe8e5, fontFamily: _family);
  static const tune = IconData(0xe429, fontFamily: _family);
  static const uploadFile = IconData(0xe9fc, fontFamily: _family);
  static const wifi = IconData(0xe63e, fontFamily: _family);
  static const work = IconData(0xe943, fontFamily: _family);
}

/// Color and icon of each category. The icon sits over the same color at
/// 13% opacity (`color + '22'` in the prototype).
final class CategoryStyle {
  const CategoryStyle(this.foreground, this.icon);

  final Color foreground;
  final IconData icon;

  Color get background => foreground.withAlpha(0x22);

  // The 11 categories of v3.
  static const comida = CategoryStyle(
    Color(0xFFF59E0B),
    DesignIcons.restaurant,
  );
  static const mercado = CategoryStyle(
    Color(0xFF22C55E),
    DesignIcons.shoppingCart,
  );
  static const transporte = CategoryStyle(
    Color(0xFF8B5CF6),
    DesignIcons.directionsCar,
  );
  static const casa = CategoryStyle(Color(0xFF3B82F6), DesignIcons.home);
  static const servicios = CategoryStyle(Color(0xFFEAB308), DesignIcons.bolt);
  static const salud = CategoryStyle(Color(0xFFEC4899), DesignIcons.favorite);
  static const ocio = CategoryStyle(
    Color(0xFF06B6D4),
    DesignIcons.localActivity,
  );
  static const compras = CategoryStyle(
    Color(0xFFEF4444),
    DesignIcons.shoppingBag,
  );
  static const sueldo = CategoryStyle(Color(0xFF10B981), DesignIcons.payments);
  static const extra = CategoryStyle(Color(0xFF14B8A6), DesignIcons.savings);
  static const otros = CategoryStyle(Color(0xFF94A3B8), DesignIcons.moreHoriz);
  static const transferencia = CategoryStyle(
    DesignColors.ink2,
    DesignIcons.swapHoriz,
  );

  // Older taxonomy names, drawn with the closest v3 category.
  static const hogar = casa;
  static const suscripciones = ocio;
  static const familia = casa;
  static const educacion = transporte;
  static const salario = sueldo;
  static const freelance = extra;
  static const inversiones = extra;

  /// Expense and income categories offered by the manual entry sheet, in
  /// the prototype's order.
  static const expenseNames = [
    'Comida',
    'Mercado',
    'Transporte',
    'Casa',
    'Servicios',
    'Salud',
    'Ocio',
    'Compras',
  ];
  static const incomeNames = ['Sueldo', 'Extra', 'Otros'];

  /// Maps v3 category names and the older taxonomy stored in the database
  /// to one of the designed styles.
  static CategoryStyle forName(String? name) {
    final key = _normalize(name ?? '');
    for (final (keywords, style) in _rules) {
      if (keywords.any(key.contains)) return style;
    }
    return otros;
  }

  static const _rules = <(List<String>, CategoryStyle)>[
    (['transfer'], transferencia),
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
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');
}

/// App-wide Material theme built from the tokens.
ThemeData buildDesignTheme() {
  const scheme = ColorScheme.light(
    primary: DesignColors.red,
    onPrimary: DesignColors.card,
    secondary: DesignColors.red,
    surface: DesignColors.card,
    onSurface: DesignColors.ink,
    error: DesignColors.red,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: DesignText.family,
    scaffoldBackgroundColor: DesignColors.paper,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: DesignColors.ink,
    ),
    textTheme: TextTheme(
      bodyMedium: DesignText.body,
      bodyLarge: DesignText.body,
      titleMedium: DesignText.headline,
      labelLarge: DesignText.bodyMedium,
    ),
  );
}
