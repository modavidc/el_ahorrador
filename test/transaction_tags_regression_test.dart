import 'package:el_ahorrador/widgets/transaction_tags.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('TransactionTags', () {
    testWidgets('renders no layout when no metadata is available', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const TransactionTags()));

      expect(find.byType(Wrap), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    for (final source in <String, (String, IconData)>{
      'YAPE': ('Yape', Icons.phone_android),
      'binance': ('Binance', Icons.currency_bitcoin),
      'banco': ('Banco', Icons.account_balance),
      'manual': ('Manual', Icons.edit),
      'Importado': ('Importado', Icons.receipt),
    }.entries) {
      testWidgets('renders the ${source.key} source variant', (tester) async {
        await tester.pumpWidget(_host(TransactionTags(sourceApp: source.key)));

        expect(find.text(source.value.$1), findsOneWidget);
        expect(find.byIcon(source.value.$2), findsOneWidget);
      });
    }

    testWidgets('combines source, OCR confidence, and verification tags', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const TransactionTags(
            sourceApp: 'yape',
            sourceType: 'OCR',
            ocrConfidence: '92',
            isVerified: true,
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('Yape'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
      expect(find.text('Verificado'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('only shows confidence for OCR and normalizes invalid values', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              TransactionTags(sourceType: 'manual', ocrConfidence: '75'),
              TransactionTags(sourceType: 'OCR', ocrConfidence: 'invalid'),
            ],
          ),
        ),
      );

      expect(find.text('75%'), findsNothing);
      expect(find.text('0%'), findsOneWidget);
    });

    for (final value in <String, Color>{
      '95': Colors.green,
      '65': Colors.orange,
      '40': Colors.red,
    }.entries) {
      testWidgets('colors confidence ${value.key} with its risk band', (
        tester,
      ) async {
        await tester.pumpWidget(
          _host(OcrConfidenceIndicator(ocrConfidence: value.key, size: 30)),
        );

        expect(find.text(value.key), findsOneWidget);
        final container = tester.widget<Container>(find.byType(Container));
        final decoration = container.decoration! as BoxDecoration;
        expect(decoration.color, value.value);
        expect(decoration.shape, BoxShape.circle);
        expect(container.constraints!.maxWidth, 30);
        expect(container.constraints!.maxHeight, 30);
      });
    }

    testWidgets('hides zero, null, and invalid confidence indicators', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const Column(
            children: [
              OcrConfidenceIndicator(),
              OcrConfidenceIndicator(ocrConfidence: '0'),
              OcrConfidenceIndicator(ocrConfidence: 'not-a-number'),
            ],
          ),
        ),
      );

      expect(find.byType(Container), findsNothing);
      expect(find.byType(SizedBox), findsNWidgets(3));
    });
  });
}
