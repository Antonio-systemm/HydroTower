import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class RiconoscimentoVocaleService {
  final SpeechToText _speech = SpeechToText();
  bool _inizializzato = false;

  Future<bool> inizializza() async {
    if (_inizializzato) return true;
    _inizializzato = await _speech.initialize();
    return _inizializzato;
  }

  Future<String?> ascolta({
    Duration durata = const Duration(seconds: 8),
  }) async {
    if (!await inizializza()) return null;
    final completer = Completer<String?>();
    String riconosciuto = '';

    await _speech.listen(
      localeId: 'it_IT',
      listenFor: durata,
      pauseFor: const Duration(seconds: 3),
      onResult: (risultato) {
        riconosciuto = risultato.recognizedWords.trim();
        if (risultato.finalResult && !completer.isCompleted) {
          completer.complete(riconosciuto.isEmpty ? null : riconosciuto);
        }
      },
    );

    Future.delayed(durata + const Duration(seconds: 1), () async {
      await _speech.stop();
      if (!completer.isCompleted) {
        completer.complete(riconosciuto.isEmpty ? null : riconosciuto);
      }
    });

    return completer.future;
  }

  Future<void> ferma() => _speech.stop();
}
