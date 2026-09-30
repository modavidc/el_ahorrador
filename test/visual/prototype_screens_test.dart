@Tags(['visual'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/core/clock/app_clock.dart';
import 'package:el_ahorrador/core/database/app_database.dart';
import 'package:el_ahorrador/features/capture/application/capture_controller.dart';
import 'package:el_ahorrador/app/dependencies.dart';
import 'package:el_ahorrador/features/ledger/data/demo_seed.dart';
import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/app/home/app_home.dart';

import '../support/capture_fakes.dart';

/// Renders the v3 screens with the prototype's data, fonts and phone size
/// (370×824 inside the 10px frame; 36px status bar, 18px gesture area) and
/// writes PNGs to `$VISUAL_OUT` for side-by-side comparison with the design
/// captures.
///
///     VISUAL_OUT=/tmp/visual flutter test test/visual
///
/// Skipped when VISUAL_OUT is not set (CI).
void main() {
  final out = Platform.environment['VISUAL_OUT'];
  // VISUAL_SCALE=3 renders sharper images (store screenshots).
  final scale =
      double.tryParse(Platform.environment['VISUAL_SCALE'] ?? '') ?? 2;

  setUpAll(() async {
    if (out == null) return;
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final file in files) {
        loader.addFont(rootBundle.load('assets/fonts/$file'));
      }
      await loader.load();
    }

    await load(DesignText.family, [
      for (final w in [400, 500, 600, 700, 800]) 'SchibstedGrotesk-$w.ttf',
    ]);
    await load('MaterialSymbolsRounded', ['MaterialSymbolsRounded.ttf']);
    await load('MaterialSymbolsRoundedFilled', [
      'MaterialSymbolsRoundedFilled.ttf',
    ]);
    AppClock.pin(DemoSeedV3.today);
  });

  late AppDependencies dependencies;
  late CaptureController capture;

  Future<void> render(
    WidgetTester tester,
    String name,
    Future<void> Function(WidgetTester tester)? steps,
  ) async {
    tester.view
      ..physicalSize = Size(370 * scale, 824 * scale)
      ..devicePixelRatio = scale
      ..padding = FakeViewPadding(top: 36 * scale, bottom: 18 * scale)
      ..viewPadding = FakeViewPadding(top: 36 * scale, bottom: 18 * scale);
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() => DemoSeedV3.load(db));
    dependencies = fakeDependencies(db);
    capture = dependencies.capture;

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDesignTheme(),
          home: AppHome(dependencies: dependencies),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (steps != null) await steps(tester);

    final render =
        boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await render.toImage(pixelRatio: scale);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$out/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1));
    dependencies.dispose();
    await tester.runAsync(db.close);
  }

  Future<void> share(WidgetTester tester, List<String> paths) async {
    var finished = false;
    capture.start(paths).whenComplete(() => finished = true);
    for (var i = 0; i < 200 && !finished; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> fab(WidgetTester t) => tap(t, find.byKey(const ValueKey('fab')));

  Future<void> welcome(WidgetTester t, {int steps = 0}) async {
    await tap(t, find.text('Ajustes'));
    await t.scrollUntilVisible(find.text('Ver bienvenida'), 300);
    await t.drag(find.text('Ver bienvenida'), const Offset(0, -200));
    await t.pumpAndSettle();
    await tap(t, find.text('Ver bienvenida'));
    // The welcome reads the budget from the database first.
    for (var i = 0; i < 40 && find.text('Continuar').evaluate().isEmpty; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pumpAndSettle();
    for (var i = 0; i < steps; i++) {
      await t.tap(find.byKey(const ValueKey('onboarding-next')));
      // The demo of the last step loops: pump instead of settling.
      await t.pump();
      await t.pump(const Duration(milliseconds: 300));
    }
  }

  final screens = <String, Future<void> Function(WidgetTester)?>{
    '00_onb1': welcome,
    '01_onb2': (t) => welcome(t, steps: 1),
    '02_onb3': (t) async {
      await welcome(t, steps: 2);
      // Same moment as the prototype capture: "Compartir" highlighted.
      await t.pump(const Duration(milliseconds: 2500));
    },
    '03_mov': null,
    '11_cal': (t) => tap(t, find.text('Calendario')),
    '12_mensual': (t) => tap(t, find.text('Mensual')),
    '13_fab': fab,
    '14_manual': (t) async {
      await fab(t);
      await tap(t, find.text('Manual'));
    },
    'streak': (t) => tap(t, find.bySemanticsLabel(RegExp('^Racha'))),
    'search': (t) => tap(t, find.bySemanticsLabel('Buscar')),
    'detail': (t) => tap(t, find.text('Menú').first),
    '72_done': (t) => share(t, ['sent']),
    '76_batch_done': (t) => share(t, [
      'sent',
      'person',
      'sent#copy',
      'bcp',
      'selfie',
      'received',
      'blurry',
    ]),
    'inbox': (t) async {
      await share(t, ['person', 'blurry']);
      await tap(t, find.text('Ver Por revisar'));
    },
    'rules': (t) async {
      await tap(t, find.text('Ajustes'));
      await tap(t, find.text('Funciones de captura'));
      await tap(t, find.text('Reglas de captura'));
    },
    '20_stats': (t) => tap(t, find.text('Estadísticas')),
    '21_dona': (t) async {
      await tap(t, find.text('Estadísticas'));
      await tap(t, find.bySemanticsLabel('Ver categorías'));
    },
    '22_budgets': (t) async {
      await tap(t, find.text('Estadísticas'));
      await tap(t, find.text('Presupuestos'));
    },
    '23_cat_detail': (t) async {
      await tap(t, find.text('Estadísticas'));
      await tap(t, find.text('Casa').first);
    },
    '30_coach': (t) => tap(t, find.text('Coach')),
    '31_coach_chat': (t) async {
      await tap(t, find.text('Coach'));
      await tap(t, find.text('¿Cuánto gasté en Comida?'));
    },
    '40_cuentas': (t) => tap(t, find.text('Cuentas')),
    '41_cuenta_edit': (t) async {
      await tap(t, find.text('Cuentas'));
      await tap(t, find.text('Yape').last);
    },
    '50_ajustes': (t) => tap(t, find.text('Ajustes')),
    '51_captura_fn': (t) async {
      await tap(t, find.text('Ajustes'));
      await tap(t, find.text('Funciones de captura'));
    },
  };

  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      await render(tester, entry.key, entry.value);
    }, skip: out == null);
  }
}
