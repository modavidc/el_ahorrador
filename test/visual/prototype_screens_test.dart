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
import 'package:el_ahorrador/features/capture/capture_controller.dart';
import 'package:el_ahorrador/features/capture/capture_service.dart';
import 'package:el_ahorrador/features/ledger/demo_seed_v3.dart';
import 'package:el_ahorrador/theme/design_tokens.dart';
import 'package:el_ahorrador/ui/app_home.dart';

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

  late CaptureController capture;

  Future<void> render(
    WidgetTester tester,
    String name,
    Future<void> Function(WidgetTester tester)? steps,
  ) async {
    tester.view
      ..physicalSize = const Size(740, 1648)
      ..devicePixelRatio = 2
      ..padding = const FakeViewPadding(top: 72, bottom: 36)
      ..viewPadding = const FakeViewPadding(top: 72, bottom: 36);
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() => DemoSeedV3.load(db));
    capture = CaptureController(
      CaptureService(
        db: db,
        ocr: FakeOcr(),
        storage: FakeStorage(),
        now: AppClock.now,
      ),
    );

    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildDesignTheme(),
          home: AppHome(db: db, capture: capture),
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
    capture.dispose();
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

  final screens = <String, Future<void> Function(WidgetTester)?>{
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
      await tap(t, find.text('Reglas de captura'));
    },
  };

  for (final entry in screens.entries) {
    testWidgets(entry.key, (tester) async {
      await render(tester, entry.key, entry.value);
    }, skip: out == null);
  }
}
