import 'dart:async';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:el_ahorrador/features/ledger/domain/speech_input.dart';

/// [SpeechInput] with the platform recognizer (`speech_to_text`). Audio is
/// handled by the system; the app only receives the text.
class SpeechToTextInput implements SpeechInput {
  SpeechToTextInput({SpeechToText? speech})
    : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  StreamController<SpeechText>? _out;
  String _last = '';

  @override
  Stream<SpeechText> listen() {
    _out?.close();
    final out = _out = StreamController<SpeechText>();
    _last = '';
    _start(out);
    return out.stream;
  }

  Future<void> _start(StreamController<SpeechText> out) async {
    try {
      final ready = await _speech.initialize(
        onError: (SpeechRecognitionError e) => _finish(
          out,
          e.errorMsg == 'error_no_match' || e.errorMsg == 'error_speech_timeout'
              ? null
              : const SpeechUnavailable(
                  'No se pudo escuchar. Intenta otra vez.',
                ),
        ),
        onStatus: (status) {
          if (status == SpeechToText.doneStatus) _finish(out, null);
        },
      );
      if (!ready) {
        return _finish(
          out,
          const SpeechUnavailable(
            'Activa el micrófono y el reconocimiento de voz para dictar.',
          ),
        );
      }
      final locale = await _spanish();
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          partialResults: true,
          localeId: locale,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
        ),
        onResult: (SpeechRecognitionResult r) {
          _last = r.recognizedWords;
          if (out.isClosed) return;
          out.add(SpeechText(_last, done: r.finalResult));
          if (r.finalResult) out.close();
        },
      );
    } on Object {
      _finish(out, const SpeechUnavailable('Este teléfono no permite dictar.'));
    }
  }

  /// es-PE when installed, else any Spanish, else the system default.
  Future<String?> _spanish() async {
    final locales = await _speech.locales();
    String? find(bool Function(String id) test) =>
        locales.map((l) => l.localeId).where(test).firstOrNull;
    return find((id) => id.replaceAll('-', '_') == 'es_PE') ??
        find((id) => id.startsWith('es'));
  }

  void _finish(StreamController<SpeechText> out, SpeechUnavailable? error) {
    if (out.isClosed) return;
    if (error != null) {
      out.addError(error);
    } else {
      out.add(SpeechText(_last, done: true));
    }
    out.close();
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
    final out = _out;
    if (out != null) _finish(out, null);
  }
}
