import 'package:el_ahorrador/widgets/immediate_loading_overlay.dart';
import 'package:el_ahorrador/widgets/processing_animation.dart';
import 'package:el_ahorrador/widgets/transaction_tags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TransactionTags regressions', () {
    testWidgets('renders nothing when no metadata is available', (tester) async {
      await tester.pumpWidget(_host(const TransactionTags()));

      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('renders source, OCR confidence, and verification together', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TransactionTags(
            sourceApp: 'YAPE',
            sourceType: 'OCR',
            ocrConfidence: '80',
            isVerified: true,
          ),
        ),
      );

      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('Verificado'), findsOneWidget);
      expect(find.byIcon(Icons.phone_android), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('invalid confidence is displayed safely as zero', (tester) async {
      await tester.pumpWidget(
        _host(
          const TransactionTags(
            sourceType: 'OCR',
            ocrConfidence: 'not-a-number',
          ),
        ),
      );

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('confidence indicator honors thresholds and requested size', (
      tester,
    ) async {
      for (final entry in <(String, Color)>[
        ('59', Colors.red),
        ('60', Colors.orange),
        ('80', Colors.green),
      ]) {
        await tester.pumpWidget(
          _host(OcrConfidenceIndicator(ocrConfidence: entry.$1, size: 32)),
        );

        final decoration = tester
            .widget<Container>(find.byType(Container).last)
            .decoration! as BoxDecoration;
        expect(decoration.color, entry.$2);
        expect(tester.getSize(find.byType(Container).last), const Size(32, 32));
        expect(find.text(entry.$1), findsOneWidget);
      }
    });

    testWidgets('zero and absent confidence indicators stay hidden', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const OcrConfidenceIndicator()));
      expect(find.text('0'), findsNothing);

      await tester.pumpWidget(
        _host(const OcrConfidenceIndicator(ocrConfidence: '0')),
      );
      expect(find.text('0'), findsNothing);
    });
  });

  group('animated feedback regressions', () {
    testWidgets('processing callback fires once after its configured duration', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          ProcessingAnimation(
            message: 'Leyendo comprobante',
            duration: const Duration(milliseconds: 100),
            onComplete: () => calls++,
          ),
        ),
      );

      expect(find.text('Leyendo comprobante'), findsOneWidget);
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 99));
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 1));
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
    });

    testWidgets('disposed processing animation does not invoke callback', (
      tester,
    ) async {
      var calls = 0;
      await tester.pumpWidget(
        _host(
          ProcessingAnimation(
            message: 'Procesando',
            duration: const Duration(milliseconds: 100),
            onComplete: () => calls++,
          ),
        ),
      );
      await tester.pumpWidget(_host(const SizedBox.shrink()));
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, 0);
    });

    testWidgets('loading screen exposes its message and progress state', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ImmediateLoadingScreen(message: 'Importando datos'),
        ),
      );

      expect(find.text('Importando datos'), findsOneWidget);
      expect(find.text('Procesando...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });

  test('CheckPainter only repaints when progress changes', () {
    final painter = CheckPainter(progress: 0.5);
    expect(painter.shouldRepaint(CheckPainter(progress: 0.5)), isFalse);
    expect(painter.shouldRepaint(CheckPainter(progress: 0.75)), isTrue);
  });
}
