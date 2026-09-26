@Tags(['visual'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/app_clock.dart';
import 'package:el_ahorrador/data/app_database.dart';
import 'package:el_ahorrador/features/ledger/demo_seed.dart';
import 'package:el_ahorrador/theme/design_tokens.dart';
import 'package:el_ahorrador/ui/app_home.dart';

/// Renders the v1 screens with the prototype's data, fonts and phone size
/// (370×824 viewport, 32px status bar, 30px gesture bar) and writes PNGs to
/// `$VISUAL_OUT` for side-by-side comparison with the design captures.
///
///     VISUAL_OUT=/tmp/visual flutter test test/visual
///
/// Skipped when VISUAL_OUT is not set (CI).
void main() {
  final out = Platform.environment['VISUAL_OUT'];

  setUpAll(() async {
    if (out == null) return;
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }

    await load('Roboto', [
      for (final w in [400, 500, 600, 700]) 'Roboto-$w.ttf',
    ]);
    await load('MaterialSymbolsRounded', ['MaterialSymbolsRounded.ttf']);
    AppClock.pin(DemoSeed.today);
  });

  Future<void> capture(
    WidgetTester tester,
    String name,
    Future<void> Function(WidgetTester tester)? steps,
  ) async {
    tester.view
      ..physicalSize = const Size(740, 1648)
      ..devicePixelRatio = 2
      ..padding = const FakeViewPadding(top: 64, bottom: 60)
      ..viewPadding = const FakeViewPadding(top: 64, bottom: 60);
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() => DemoSeed.load(db));

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDesignTheme(),
          home: AppHome(db: db),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (steps != null) await steps(tester);

    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.runAsync(db.close);
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  final screens = <String, Future<void> Function(WidgetTester)?>{
    '01_trans_diario': null,
    '02_trans_calendario': (t) => tap(t, 'Calendario'),
    '03_trans_mensual': (t) => tap(t, 'Mensual'),
    '04_trans_total': (t) => tap(t, 'Total'),
    '05_fab_menu': (t) async {
      await t.tap(find.bySemanticsLabel('Añadir'));
      await t.pumpAndSettle();
    },
    '06_stats': (t) => tap(t, 'Estad.'),
    '07_cat_detail': (t) async {
      await tap(t, 'Estad.');
      await tap(t, 'Comida');
    },
    '08_coach': (t) => tap(t, 'Coach'),
    '09_cuentas': (t) => tap(t, 'Cuentas'),
    '10_ajustes': (t) => tap(t, 'Ajustes'),
    '11_add': (t) async {
      await t.tap(find.bySemanticsLabel('Añadir'));
      await t.pumpAndSettle();
      await tap(t, 'Añadir manual');
    },
  };

  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      await capture(tester, entry.key, entry.value);
    }, skip: out == null);
  }
}
