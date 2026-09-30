import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:el_ahorrador/features/coach/data/openai_coach.dart';
import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/coach/domain/coach_model.dart';
import 'package:el_ahorrador/features/ledger/domain/entities.dart';

Movement _m(String note, int cents, {String category = 'Comida'}) => Movement(
  id: note,
  at: DateTime(2026, 9, 20),
  type: MovementType.expense,
  category: category,
  subcategory: '',
  note: note,
  account: 'BCP Soles',
  amountCents: cents,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final context = CoachContext(
    movements: [
      _m('Cumpleaños de Rosa Quispe', 12000),
      _m('Uber a la clínica', 3000, category: 'Transporte'),
    ],
    budgetCents: 240000,
    today: DateTime(2026, 9, 27),
  );

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('the brief has month totals and no movement, note or account', () {
    final brief = coachBrief(context);
    expect(brief, contains('Presupuesto mensual: S/ 2,400.00'));
    expect(brief, contains('Comida S/ 120.00, Transporte S/ 30.00'));
    expect(brief, isNot(contains('Rosa')));
    expect(brief, isNot(contains('clínica')));
    expect(brief, isNot(contains('BCP')));
  });

  test('without a key the Coach answers on the phone', () async {
    var calls = 0;
    final coach = OpenAiCoach(
      client: MockClient((_) async {
        calls++;
        return http.Response('', 500);
      }),
    );
    final answer = await coach.reply('¿Cuánto gasté en Comida?', context);
    expect(answer, LocalCoach.answer('¿Cuánto gasté en Comida?', context));
    expect(calls, 0);
  });

  test('with a key it asks OpenAI with the brief only', () async {
    late Map<String, Object?> sent;
    late String auth;
    final coach = OpenAiCoach(
      client: MockClient((request) async {
        if (request.method == 'GET') return http.Response('{}', 200);
        auth = request.headers['Authorization']!;
        sent = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {'content': ' Vas bien este mes. '},
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    await coach.connect('sk-test-123');
    expect(await coach.isConnected(), isTrue);

    final answer = await coach.reply('¿Cómo voy?', context);
    expect(answer, 'Vas bien este mes.');
    expect(auth, 'Bearer sk-test-123');
    final body = jsonEncode(sent);
    expect(body, contains('¿Cómo voy?'));
    expect(body, isNot(contains('Rosa')));
    expect(body, isNot(contains('BCP')));
  });

  test('a failing call falls back to the phone', () async {
    FlutterSecureStorage.setMockInitialValues({'coach.openai.key.v1': 'sk-x'});
    final coach = OpenAiCoach(
      client: MockClient((_) async => http.Response('down', 503)),
    );
    expect(
      await coach.reply('¿Me alcanza hasta fin de mes?', context),
      LocalCoach.answer('¿Me alcanza hasta fin de mes?', context),
    );
  });

  test('a rejected key is not kept', () async {
    final coach = OpenAiCoach(
      client: MockClient((_) async => http.Response('', 401)),
    );
    await expectLater(
      coach.connect('sk-wrong'),
      throwsA(
        isA<CoachModelException>().having(
          (e) => e.message,
          'message',
          'OpenAI rechazó la clave.',
        ),
      ),
    );
    await expectLater(
      coach.connect('not-a-key'),
      throwsA(isA<CoachModelException>()),
    );
    expect(await coach.isConnected(), isFalse);
  });

  test('disconnect removes the key', () async {
    FlutterSecureStorage.setMockInitialValues({'coach.openai.key.v1': 'sk-x'});
    final coach = OpenAiCoach(
      client: MockClient((_) async => http.Response('', 200)),
    );
    await coach.disconnect();
    expect(await coach.isConnected(), isFalse);
  });
}
