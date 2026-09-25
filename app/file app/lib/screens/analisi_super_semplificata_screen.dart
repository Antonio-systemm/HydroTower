import 'package:flutter/material.dart';

import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'analisi_semplificata_screen.dart';

class AnalisiSuperSemplificataScreen extends StatelessWidget {
  const AnalisiSuperSemplificataScreen({super.key});

  Future<void> _apriAnalisi(BuildContext context, String annuncio) async {
    await TtsService.leggi(annuncio);

    if (!context.mounted) {
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => const AnalisiSemplificataScreen(),
      ),
    );
  }

  Future<bool> _gestisciComando(BuildContext context, String comando) async {
    if (ComandiVocali.contiene(comando, <String>[
      'menù',
      'indietro',
      'torna indietro',
      'torna al menù',
    ])) {
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'dati sensori',
      'sensori',
      'leggi sensori',
      'valori sensori',
    ])) {
      await _apriAnalisi(context, 'Apro la gestione dei dati dei sensori.');
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'cancella foto',
      'elimina foto',
      'rimuovi foto',
      'cancella fotografia',
    ])) {
      await _apriAnalisi(
        context,
        'Apro la gestione della fotografia. Seleziona Cancella foto.',
      );
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'galleria',
      'apri galleria',
      'scegli dalla galleria',
      'seleziona foto',
    ])) {
      await _apriAnalisi(
        context,
        'Apro la gestione della fotografia. Seleziona Galleria.',
      );
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'fai una foto',
      'scatta una foto',
      'scatta foto',
      'fotocamera',
      'camera',
    ])) {
      await _apriAnalisi(
        context,
        'Apro la gestione della fotografia. Seleziona Fai una foto.',
      );
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'invia analisi',
      'avvia analisi',
      'analizza',
      'analizza la pianta',
      'invia',
    ])) {
      await _apriAnalisi(
        context,
        'Apro la schermata di analisi. Seleziona Invia analisi.',
      );
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'aiuto',
      'comandi',
      'cosa posso dire',
      'ripeti comandi',
    ])) {
      await TtsService.leggi(
        'Puoi dire: Dati sensori, Fai una foto, Galleria, '
        'Invia analisi, Cancella foto oppure Menù.',
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Analisi con intelligenza artificiale. '
              'In alto a sinistra Dati sensori. '
              'In alto a destra Fai una foto. '
              'Al centro Menù e controllo del microfono. '
              'In basso a sinistra Invia analisi. '
              'In basso a destra Cancella foto.',
          domandaVocale:
              'Puoi dire: Dati sensori, Fai una foto, Galleria, '
              'Invia analisi, Cancella foto, Aiuto oppure Menù.',
          altoSinistra: ZoneAction(
            etichetta: 'Dati\nsensori',
            onTocco: () {
              TtsService.leggi('Dati sensori.');
            },
            onAttiva: () {
              _apriAnalisi(context, 'Apro la gestione dei dati dei sensori.');
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Fai una\nfoto',
            onTocco: () {
              TtsService.leggi('Fai una foto.');
            },
            onAttiva: () {
              _apriAnalisi(context, 'Apro la gestione della fotografia.');
            },
          ),
          centro: ZoneAction(
            etichetta: 'Menù',
            onTocco: () {
              TtsService.leggi(
                'Torna al menù principale. '
                'Il pulsante rotondo controlla il microfono.',
              );
            },
            onAttiva: () {
              Navigator.of(context).pop();
            },
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Invia\nanalisi',
            onTocco: () {
              TtsService.leggi('Invia analisi.');
            },
            onAttiva: () {
              _apriAnalisi(context, 'Apro la schermata per inviare l’analisi.');
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Cancella\nfoto',
            onTocco: () {
              TtsService.leggi('Cancella foto.');
            },
            onAttiva: () {
              _apriAnalisi(context, 'Apro la gestione della fotografia.');
            },
          ),
          onComando: (String comando) {
            return _gestisciComando(context, comando);
          },
        ),
      ),
    );
  }
}
