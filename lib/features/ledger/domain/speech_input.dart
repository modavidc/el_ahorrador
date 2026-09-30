/// Dictar: the device's speech recognition.
abstract interface class SpeechInput {
  /// Listens once in Spanish. Emits the transcript as it grows; the last
  /// event has [SpeechText.done]. Fails with [SpeechUnavailable] when there
  /// is no recognizer or the microphone was denied.
  Stream<SpeechText> listen();

  /// Stops listening; the transcript so far becomes final.
  Future<void> stop();
}

final class SpeechText {
  const SpeechText(this.text, {this.done = false});

  final String text;
  final bool done;
}

final class SpeechUnavailable implements Exception {
  const SpeechUnavailable(this.message);

  /// Shown to the user as is.
  final String message;

  @override
  String toString() => message;
}
