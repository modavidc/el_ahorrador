import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:el_ahorrador/design_system/tokens.dart';
import 'package:el_ahorrador/features/onboarding/presentation/share_demo.dart';

void main() {
  // The real fonts: the test font is wider and would overflow on its own.
  setUpAll(() async {
    final text = FontLoader(DesignText.family);
    for (final w in [400, 500, 600, 700, 800]) {
      text.addFont(rootBundle.load('assets/fonts/SchibstedGrotesk-$w.ttf'));
    }
    await text.load();
    for (final family in [
      'MaterialSymbolsRounded',
      'MaterialSymbolsRoundedFilled',
    ]) {
      await (FontLoader(
        family,
      )..addFont(rootBundle.load('assets/fonts/$family.ttf'))).load();
    }
  });

  testWidgets('every scene of the onboarding demo fits its phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildDesignTheme(),
        home: const Scaffold(body: Center(child: ShareDemo())),
      ),
    );
    // One full loop, a frame every 300 ms: pay, share sheet, reading, list.
    for (var ms = 0; ms <= 12600; ms += 300) {
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: 'at $ms ms');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
