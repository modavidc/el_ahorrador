import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Design handoff v1 (`design/`): `tokens.json` plus the exact values used by
/// the HTML prototype. Screens must take every color, text style, spacing,
/// radius, shadow and icon from here; `test/design_tokens_usage_test.dart`
/// fails on hex colors or font sizes written directly in the new UI.
abstract final class DesignColors {
  // brand
  static const primary = Color(0xFFF0523C);
  static const primaryPressed = Color(0xFFD33F2B);
  static const primarySoft = Color(0xFFFBE0DA);
  static const onPrimary = Color(0xFFFFFFFF);

  // semantic
  static const income = Color(0xFF2F80ED);
  static const expense = Color(0xFFF0523C);
  static const neutralAmount = Color(0xFF8A8A8A);
  static const success = Color(0xFF2EA862);
  static const successSoft = Color(0xFFE3F7EA);
  static const ai = Color(0xFF8A4FD6);
  static const aiSoft = Color(0xFFEFE3FC);
  static const warning = Color(0xFFF2994A);

  // text
  static const textPrimary = Color(0xFF222222);
  static const textSecondary = Color(0xFF555555);
  static const textTertiary = Color(0xFF8A8A8A);
  static const textDisabled = Color(0xFFB0B0B0);
  static const textInverse = Color(0xFFFFFFFF);

  // surface
  static const background = Color(0xFFF4F4F6);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const inputFill = Color(0xFFF7F7F8);
  static const inverse = Color(0xFF3A3A3A);
  static const scrim = Color(0x6B000000); // rgba(0,0,0,0.42)

  // border
  static const border = Color(0xFFEEEEEE);
  static const borderSubtle = Color(0xFFF2F2F2);
  static const borderInput = Color(0xFFE2E2E2);

  // prototype-specific
  /// Selected calendar day and the "Todas" subcategory row.
  static const selectedSoft = Color(0xFFFFF6F4);

  /// Off state of the settings toggle track.
  static const toggleTrackOff = Color(0xFFD5D5D8);

  /// Label pill next to each FAB menu action: rgba(0,0,0,0.55).
  static const fabLabel = Color(0x8C000000);

  /// Check icon inside the dark toast.
  static const toastIcon = Color(0xFF6FDC9C);

  /// Camera background of the scan screen.
  static const cameraBackground = Color(0xFF1A1A1A);
}

/// Every text style of the prototype: Roboto with tabular figures.
abstract final class DesignText {
  static const _numbers = [FontFeature.tabularFigures()];

  static TextStyle _style(double size, FontWeight weight) => TextStyle(
    fontFamily: 'Roboto',
    fontSize: size,
    fontWeight: weight,
    height: normalLineHeight(size),
    color: DesignColors.textPrimary,
    fontFeatures: _numbers,
  );

  /// The browser's `line-height: normal` for Roboto: hhea ascender (1900)
  /// and descender (500) over 2048 units, each rounded to whole pixels as
  /// Chromium does (14px → 16px line). Flutter's default is taller.
  static double normalLineHeight(double size) =>
      ((1900 / 2048 * size).round() + (500 / 2048 * size).round()) / size;

  static final display = _style(28, FontWeight.w700);
  static final title = _style(20, FontWeight.w700);
  static final sheetTitle = _style(18, FontWeight.w600);
  static final headlineBold = _style(16, FontWeight.w700);
  static final headline = _style(16, FontWeight.w600);
  static final body = _style(14, FontWeight.w400);
  static final bodyMedium = _style(14, FontWeight.w500);
  static final bodyStrong = _style(14, FontWeight.w600);
  static final label = _style(13, FontWeight.w400);
  static final labelMedium = _style(13, FontWeight.w500);
  static final labelStrong = _style(13, FontWeight.w600);
  static final caption = _style(12, FontWeight.w400);
  static final captionMedium = _style(12, FontWeight.w500);
  static final captionStrong = _style(12, FontWeight.w600);
  static final micro = _style(11, FontWeight.w500);
  static final microRegular = _style(11, FontWeight.w400);
  static final microStrong = _style(11, FontWeight.w600);

  /// Chart axis and point labels.
  static final axis = _style(10, FontWeight.w400);
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
  static const tile = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const sheet = 20.0;
  static const pill = 999.0;
}

abstract final class DesignShadows {
  /// elevation.card: 0 1px 3px rgba(0,0,0,0.05)
  static final card = [css(const Color(0x0D000000), 1, 3)];

  /// elevation.fab: 0 6px 16px rgba(240,82,60,0.45)
  static final fab = [css(const Color(0x73F0523C), 6, 16)];

  /// FAB menu action buttons: 0 4px 12px rgba(0,0,0,0.3)
  static final fabAction = [css(const Color(0x4D000000), 4, 12)];

  /// Settings toggle knob: 0 1px 2px rgba(0,0,0,0.2)
  static final knob = [css(const Color(0x33000000), 1, 2)];

  /// Chat bubbles: 0 1px 2px rgba(0,0,0,0.05)
  static final bubble = [css(const Color(0x0D000000), 1, 2)];

  /// Scan receipt: 0 10px 40px rgba(0,0,0,0.5)
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

/// Material Symbols Rounded (opsz 24, wght 400, FILL 0), bundled in
/// `assets/fonts`. Code points from Google's `.codepoints` file.
abstract final class DesignIcons {
  static const _family = 'MaterialSymbolsRounded';
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

/// Foreground/background/icon of each category (tokens.json → color.category).
final class CategoryStyle {
  const CategoryStyle(this.foreground, this.background, this.icon);

  final Color foreground;
  final Color background;
  final IconData icon;

  static const comida = CategoryStyle(
    Color(0xFFF0523C),
    Color(0xFFFBE0DA),
    DesignIcons.restaurant,
  );
  static const hogar = CategoryStyle(
    Color(0xFFA1674A),
    Color(0xFFF3E4DC),
    DesignIcons.home,
  );
  static const transporte = CategoryStyle(
    Color(0xFF2F80ED),
    Color(0xFFDBE8FB),
    DesignIcons.localTaxi,
  );
  static const servicios = CategoryStyle(
    Color(0xFFF2994A),
    Color(0xFFFDEED9),
    DesignIcons.wifi,
  );
  static const suscripciones = CategoryStyle(
    Color(0xFFD6457A),
    Color(0xFFFADDE8),
    DesignIcons.subscriptions,
  );
  static const familia = CategoryStyle(
    Color(0xFF9B51E0),
    Color(0xFFEFE3FC),
    DesignIcons.familyRestroom,
  );
  static const ocio = CategoryStyle(
    Color(0xFFE0A800),
    Color(0xFFFFF3C9),
    DesignIcons.sportsEsports,
  );
  static const compras = CategoryStyle(
    Color(0xFF00A3A3),
    Color(0xFFD7F2F2),
    DesignIcons.shoppingBag,
  );
  static const salud = CategoryStyle(
    Color(0xFF27AE60),
    Color(0xFFDBF3E5),
    DesignIcons.medication,
  );
  static const educacion = CategoryStyle(
    Color(0xFF4F5BD5),
    Color(0xFFE1E4F6),
    DesignIcons.school,
  );
  static const otros = CategoryStyle(
    Color(0xFF828282),
    Color(0xFFECECEC),
    DesignIcons.category,
  );
  static const salario = CategoryStyle(
    Color(0xFF2F80ED),
    Color(0xFFDBE8FB),
    DesignIcons.payments,
  );
  static const freelance = CategoryStyle(
    Color(0xFF27AE60),
    Color(0xFFDBF3E5),
    DesignIcons.work,
  );
  static const inversiones = CategoryStyle(
    Color(0xFFF2994A),
    Color(0xFFFDEED9),
    DesignIcons.trendingUp,
  );
  static const transferencia = CategoryStyle(
    Color(0xFF8A8A8A),
    Color(0xFFECECEC),
    DesignIcons.swapHoriz,
  );

  /// Maps the prototype's categories and the Money Manager taxonomy stored in
  /// the database to one of the 15 designed styles.
  static CategoryStyle forName(String? name) {
    final key = _normalize(name ?? '');
    for (final (keywords, style) in _rules) {
      if (keywords.any(key.contains)) return style;
    }
    return otros;
  }

  static const _rules = <(List<String>, CategoryStyle)>[
    (['transfer'], transferencia),
    (['suscrip'], suscripciones),
    (['comida', 'aliment', 'restaur'], comida),
    (['hogar', 'vivienda', 'electrodom', 'alquiler'], hogar),
    (['transporte', 'taxi', 'movilidad'], transporte),
    (['servicio', 'internet', 'luz', 'agua'], servicios),
    (['familia', 'mascota'], familia),
    (['ocio', 'entreten', 'deporte', 'cultura'], ocio),
    (['compras', 'ropa', 'electronic', 'oficina', 'regalo'], compras),
    (['salud', 'cuidado personal', 'farmacia'], salud),
    (['educacion', 'curso'], educacion),
    (['salario', 'sueldo', 't-cuida'], salario),
    (
      ['freelance', 'upwork', 'mantenimiento web', 'tecnico', 'afiliado'],
      freelance,
    ),
    (['inversion', 'binance', 'p2p'], inversiones),
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
    primary: DesignColors.primary,
    onPrimary: DesignColors.onPrimary,
    secondary: DesignColors.primary,
    surface: DesignColors.surfaceCard,
    onSurface: DesignColors.textPrimary,
    error: DesignColors.expense,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: DesignColors.background,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: TextTheme(
      bodyMedium: DesignText.body,
      bodyLarge: DesignText.body,
      titleMedium: DesignText.headline,
      labelLarge: DesignText.bodyMedium,
    ),
  );
}
