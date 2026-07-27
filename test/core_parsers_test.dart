import 'package:el_ahorrador/core/banco_parser.dart' as banco;
import 'package:el_ahorrador/core/binance_parser.dart' as binance;
import 'package:el_ahorrador/core/capture_validator.dart';
import 'package:el_ahorrador/core/parser.dart';
import 'package:el_ahorrador/core/yape_parser.dart' as yape;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CaptureValidator', () {
    test('clasifica proveedores conocidos sin depender de mayusculas', () {
      expect(
        CaptureValidator.validateCapture('YAPE - pago realizado'),
        CaptureType.yape,
      );
      expect(
        CaptureValidator.validateCapture('BINANCE wallet'),
        CaptureType.binance,
      );
      expect(
        CaptureValidator.validateCapture('Transferencia BBVA'),
        CaptureType.banco,
      );
    });

    test('contenido invalido prevalece sobre un proveedor reconocido', () {
      expect(
        CaptureValidator.validateCapture('Yape captura con contenido xxx'),
        CaptureType.invalid,
      );
    });

    test('solo permite procesar tipos financieros reconocidos', () {
      for (final type in [
        CaptureType.yape,
        CaptureType.binance,
        CaptureType.banco,
      ]) {
        expect(CaptureValidator.isProcessable(type), isTrue);
      }
      expect(CaptureValidator.isProcessable(CaptureType.invalid), isFalse);
      expect(CaptureValidator.isProcessable(CaptureType.unknown), isFalse);
    });
  });

  group('parsers especializados', () {
    test('Yape extrae monto, destinatario, fecha y metadatos OCR', () {
      const text = '''
Â¡Yapeaste!
S/ 27.50
Mercado Central
12 jul. 2026 | 12:05 a. m.
C\u00f3digo de seguridad: 731
Nro. de operaci\u00f3n: 987654
Nro. de celular: 999 888 777
''';

      final result = yape.YapeParser.parseYapeTransaction(text);

      expect(result, isNotNull);
      expect(result!.amount, 27.50);
      expect(result.recipient, 'Mercado Central');
      expect(result.date, DateTime(2026, 7, 12, 0, 5));
      expect(result.securityCode, '731');
      expect(result.operationNumber, '987654');
      expect(result.phoneNumber, '999 888 777');
    });

    test('Banco normaliza anio corto y conserva banco, monto y moneda', () {
      final result = banco.BancoParser.parseBancoTransaction(
        'Comprobante BCP\nTransferencia S/ 123.45\n08/07/26',
      );

      expect(result, isNotNull);
      expect(result!.amount, 123.45);
      expect(result.currency, 'PEN');
      expect(result.bankName, 'BCP');
      expect(result.date, DateTime(2026, 7, 8));
    });

    test('Binance extrae cripto y timestamp con precision de segundos', () {
      final result = binance.BinanceParser.parseBinanceTransaction(
        'Binance wallet\n0.015 BTC\n2026-07-08 14:03:59',
      );

      expect(result, isNotNull);
      expect(result!.amount, 0.015);
      expect(result.currency, 'BTC');
      expect(result.date, DateTime(2026, 7, 8, 14, 3, 59));
    });

    test('rechazan texto ajeno al proveedor', () {
      expect(yape.YapeParser.parseYapeTransaction('recibo generico'), isNull);
      expect(
        banco.BancoParser.parseBancoTransaction('recibo generico'),
        isNull,
      );
      expect(
        binance.BinanceParser.parseBinanceTransaction('recibo generico'),
        isNull,
      );
    });
  });

  group('Parser integrado', () {
    test(
      'texto desconocido produce resultado seguro y respeta fallback',
      () async {
        const fallback = 1700000000000;

        final result = await Parser.fromOcr(
          'texto sin origen financiero reconocido',
          fallbackDateEpoch: fallback,
          ocrConfidence: '82',
        );

        expect(result.amountCents, 0);
        expect(result.currency, 'PEN');
        expect(result.dateEpochMs, fallback);
        expect(result.sourceApp, 'Unknown');
        expect(result.ocrConfidence, isNull);
      },
    );

    test('propaga el resultado especializado de Binance', () async {
      final result = await Parser.fromOcr(
        'Binance wallet\n1.25 ETH\n2026-07-08 14:03:59',
      );

      expect(result.amountCents, 125);
      expect(result.currency, 'ETH');
      expect(
        result.dateEpochMs,
        DateTime(2026, 7, 8, 14, 3, 59).millisecondsSinceEpoch,
      );
      expect(result.vendor, 'Binance');
      expect(result.sourceApp, 'Binance');
    });
  });
}
