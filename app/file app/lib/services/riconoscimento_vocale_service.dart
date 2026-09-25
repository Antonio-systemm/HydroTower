import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class RisultatoAscolto {
  final String? testo;
  final String? errore;

  const RisultatoAscolto({this.testo, this.errore});

  bool get riuscito => testo != null && testo!.trim().isNotEmpty;
}

class RiconoscimentoVocaleService {
  static final SpeechToText _speech = SpeechToText();

  static bool _inizializzato = false;
  static bool _disponibile = false;
  static String? _ultimoErrore;
  static String? _localeItaliano;

  bool get disponibile => _disponibile;
  bool get staAscoltando => _speech.isListening;

  Future<bool> inizializza() async {
    if (_inizializzato) {
      return _disponibile;
    }

    try {
      _disponibile = await _speech.initialize(
        debugLogging: kDebugMode,
        onStatus: (String stato) {
          debugPrint('STATO VOCE: $stato');
        },
        onError: (SpeechRecognitionError errore) {
          debugPrint(
            'ERRORE VOCE: ${errore.errorMsg}; '
                'permanente=${errore.permanent}',
          );

          if (_erroreIgnorabile(errore.errorMsg)) {
            _ultimoErrore = null;
          } else {
            _ultimoErrore = errore.errorMsg;
          }
        },
      );

      if (_disponibile) {
        _localeItaliano = await _trovaLocaleItaliano();
        debugPrint(
          'LOCALE VOCE: ${_localeItaliano ?? 'predefinito di sistema'}',
        );
      }
    } catch (errore) {
      _ultimoErrore = errore.toString();
      _disponibile = false;
      debugPrint('INIZIALIZZAZIONE VOCE FALLITA: $_ultimoErrore');
    }

    _inizializzato = true;
    return _disponibile;
  }

  static bool _erroreIgnorabile(String errore) {
    return errore == 'error_speech_timeout' ||
        errore == 'error_no_match' ||
        errore.contains('error_speech_timeout') ||
        errore.contains('error_no_match');
  }

  Future<String?> _trovaLocaleItaliano() async {
    try {
      final locali = await _speech.locales();

      for (final locale in locali) {
        final idNormalizzato = locale.localeId.toLowerCase().replaceAll(
          '-',
          '_',
        );

        if (idNormalizzato == 'it_it') {
          return locale.localeId;
        }
      }

      for (final locale in locali) {
        if (locale.localeId.toLowerCase().startsWith('it')) {
          return locale.localeId;
        }
      }
    } catch (errore) {
      debugPrint('LETTURA LOCALI VOCE FALLITA: $errore');
    }

    return null;
  }

  Future<RisultatoAscolto> ascoltaRapido({
    Duration durataMassima = const Duration(seconds: 8),
    Duration pausa = const Duration(seconds: 2),
  }) async {
    _ultimoErrore = null;

    if (!await inizializza()) {
      return RisultatoAscolto(
        errore:
        _ultimoErrore ??
            'Riconoscimento vocale non disponibile. '
                'Controlla il permesso del microfono.',
      );
    }

    if (_speech.isListening) {
      await _speech.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    final completer = Completer<RisultatoAscolto>();
    Timer? timerSicurezza;
    String parole = '';
    double confidenzaMigliore = 0;

    void completa({String? errore}) {
      if (completer.isCompleted) {
        return;
      }

      timerSicurezza?.cancel();
      final testo = parole.trim();

      if (testo.isNotEmpty) {
        debugPrint(
          'COMANDO VOCALE FINALE: "$testo"; '
              'confidenza=$confidenzaMigliore',
        );
        completer.complete(RisultatoAscolto(testo: testo));
      } else {
        completer.complete(
          RisultatoAscolto(
            errore:
            errore ??
                'Non ho riconosciuto le parole. '
                    'Attendi il segnale e riprova parlando chiaramente.',
          ),
        );
      }
    }

    void gestisciRisultato(SpeechRecognitionResult risultato) {
      final nuovoTesto = risultato.recognizedWords.trim();

      debugPrint(
        'RICONOSCIUTO: "$nuovoTesto"; '
            'finale=${risultato.finalResult}; '
            'confidenza=${risultato.confidence}',
      );

      if (nuovoTesto.isNotEmpty) {
        // Conserva sempre l'ipotesi più recente, normalmente più completa.
        parole = nuovoTesto;

        if (risultato.confidence > confidenzaMigliore) {
          confidenzaMigliore = risultato.confidence;
        }
      }

      if (risultato.finalResult) {
        completa();
      }
    }

    try {
      await _speech.listen(
        onResult: gestisciRisultato,
        listenOptions: SpeechListenOptions(
          localeId: _localeItaliano,
          listenFor: durataMassima,
          pauseFor: pausa,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );

      timerSicurezza = Timer(
        durataMassima + const Duration(seconds: 2),
            () async {
          if (_speech.isListening) {
            await _speech.stop();
          }

          // Android può inviare l'ultimo risultato subito dopo stop().
          await Future<void>.delayed(const Duration(milliseconds: 650));
          completa();
        },
      );
    } catch (errore) {
      final messaggio = errore.toString();
      debugPrint('ECCEZIONE ASCOLTO: $messaggio');

      if (_erroreIgnorabile(messaggio)) {
        completa();
      } else {
        completa(errore: 'Errore durante il riconoscimento vocale: $messaggio');
      }
    }

    final risultato = await completer.future;
    timerSicurezza?.cancel();
    return risultato;
  }

  Future<void> ferma() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  Future<void> annulla() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}