import 'riconoscimento_vocale_service.dart';
import 'tts_service.dart';

class VoiceCommandController {
  final RiconoscimentoVocaleService _speech = RiconoscimentoVocaleService();

  bool microfonoAttivo = true;
  bool inAscolto = false;
  bool _chiuso = false;

  bool get disponibile => _speech.disponibile;

  bool get staAscoltando => inAscolto || _speech.staAscoltando;

  Future<bool> inizializza() async {
    if (_chiuso) {
      return false;
    }

    return _speech.inizializza();
  }

  Future<void> impostaMicrofono(bool attivo) async {
    if (_chiuso) {
      return;
    }

    microfonoAttivo = attivo;

    if (!attivo) {
      await _speech.annulla();
      inAscolto = false;
    }
  }

  Future<RisultatoAscolto> ascolta() async {
    if (_chiuso) {
      return const RisultatoAscolto(
        errore: 'Il servizio vocale è stato chiuso.',
      );
    }

    if (!microfonoAttivo) {
      return const RisultatoAscolto(errore: 'Microfono disattivato.');
    }

    if (inAscolto || _speech.staAscoltando) {
      return const RisultatoAscolto(errore: 'Ascolto già in corso.');
    }

    inAscolto = true;

    try {
      // Ferma qualsiasi messaggio vocale prima di aprire il microfono.
      await TtsService.ferma();

      // Un'unica attesa breve. Non aggiungere altri ritardi nel widget.
      await Future<void>.delayed(const Duration(milliseconds: 120));

      if (_chiuso) {
        return const RisultatoAscolto(
          errore: 'Il servizio vocale è stato chiuso.',
        );
      }

      if (!microfonoAttivo) {
        return const RisultatoAscolto(errore: 'Microfono disattivato.');
      }

      return await _speech.ascoltaRapido(
        durataMassima: const Duration(seconds: 8),
        pausa: const Duration(seconds: 2),
      );
    } catch (errore) {
      return RisultatoAscolto(
        errore: 'Errore durante il riconoscimento vocale: $errore',
      );
    } finally {
      inAscolto = false;
    }
  }

  Future<void> fermaAscolto() async {
    if (_chiuso) {
      return;
    }

    try {
      await _speech.ferma();
    } finally {
      inAscolto = false;
    }
  }

  Future<void> annullaAscolto() async {
    if (_chiuso) {
      return;
    }

    try {
      await _speech.annulla();
    } finally {
      inAscolto = false;
    }
  }

  Future<void> dispose() async {
    if (_chiuso) {
      return;
    }

    _chiuso = true;
    microfonoAttivo = false;

    try {
      await _speech.annulla();
    } finally {
      inAscolto = false;
    }
  }
}
