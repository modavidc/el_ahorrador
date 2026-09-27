import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:el_ahorrador/features/coach/domain/coach.dart';
import 'package:el_ahorrador/features/coach/domain/coach_model.dart';

/// Coach answered by OpenAI with the user's own key.
///
/// The key is read from secure storage on each question and is never part
/// of the app package. The model receives [coachBrief] (month totals) and
/// the question; without a key, or when the call fails, the answer comes
/// from [LocalCoach].
class OpenAiCoach implements CoachAssistant, CoachModelAccess {
  OpenAiCoach({
    http.Client? client,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    this.model = defaultModel,
  }) : _client = client ?? http.Client(),
       _storage = storage;

  static const defaultModel = 'gpt-4o-mini';
  static const _keyName = 'coach.openai.key.v1';
  static final _endpoint = Uri.parse(
    'https://api.openai.com/v1/chat/completions',
  );

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final String model;

  @override
  Future<bool> isConnected() async =>
      (await _storage.read(key: _keyName))?.isNotEmpty ?? false;

  @override
  Future<void> connect(String apiKey) async {
    final key = apiKey.trim();
    if (!key.startsWith('sk-')) {
      throw const CoachModelException('La clave de OpenAI empieza con "sk-".');
    }
    final http.Response response;
    try {
      response = await _client
          .get(
            Uri.parse('https://api.openai.com/v1/models/$model'),
            headers: {'Authorization': 'Bearer $key'},
          )
          .timeout(const Duration(seconds: 15));
    } on Object {
      throw const CoachModelException(
        'No se pudo conectar con OpenAI. Revisa tu internet.',
      );
    }
    if (response.statusCode == 401) {
      throw const CoachModelException('OpenAI rechazó la clave.');
    }
    if (response.statusCode != 200) {
      throw CoachModelException(
        'OpenAI respondió ${response.statusCode}. Intenta más tarde.',
      );
    }
    await _storage.write(key: _keyName, value: key);
  }

  @override
  Future<void> disconnect() => _storage.delete(key: _keyName);

  @override
  Future<String> reply(String question, CoachContext context) async {
    final key = await _storage.read(key: _keyName);
    if (key == null || key.isEmpty) return LocalCoach.answer(question, context);
    try {
      final response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': 'Bearer $key',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody(question, context, model: model)),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        return LocalCoach.answer(question, context);
      }
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      final text =
          ((json['choices'] as List).first as Map)['message']['content']
              as String?;
      return text == null || text.trim().isEmpty
          ? LocalCoach.answer(question, context)
          : text.trim();
    } on Object {
      return LocalCoach.answer(question, context);
    }
  }

  /// What is sent: instructions, the month totals and the question.
  static Map<String, Object> requestBody(
    String question,
    CoachContext context, {
    String model = defaultModel,
  }) => {
    'model': model,
    'temperature': 0.4,
    'max_tokens': 300,
    'messages': [
      {
        'role': 'system',
        'content':
            'Eres el Coach de El Ahorrador, una app de gastos en Perú. '
            'Responde en español peruano, en 2 a 4 oraciones, con cifras en '
            'soles (S/). Tono: ${context.tone.label.toLowerCase()}. Usa solo '
            'estos datos del usuario; si falta algo, dilo.\n\n'
            '${coachBrief(context)}',
      },
      {'role': 'user', 'content': question},
    ],
  };
}
