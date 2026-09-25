import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../services/vibration_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class AccessibilitaSuperSemplificataScreen extends StatelessWidget {
  const AccessibilitaSuperSemplificataScreen({super.key});

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _tornaIndietro(BuildContext context) {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Impostazioni di accessibilità. '
              'Puoi ascoltare le istruzioni, '
              'provare la vibrazione, '
              'ascoltare la guida ai gesti '
              'oppure tornare indietro.',
          domandaVocale:
              'Puoi dire istruzioni, vibrazione, '
              'gesti oppure indietro.',
          altoSinistra: ZoneAction(
            etichetta: 'Istruzioni\nvocali',
            onTocco: () {
              _leggi(
                'Istruzioni vocali. '
                'Tocca una volta per ascoltare '
                'il nome di una funzione. '
                'Tocca due volte per confermare.',
              );
            },
            onAttiva: () {
              _leggi('La guida vocale è attiva.');
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Prova\nvibrazione',
            onTocco: () {
              unawaited(VibrationService.tocco());

              _leggi('Vibrazione breve.');
            },
            onAttiva: () {
              unawaited(VibrationService.pressioneProlungata());

              _leggi('Vibrazione forte.');
            },
          ),
          centro: ZoneAction(
            etichetta: 'Indietro',
            onTocco: () {
              _leggi(
                'Tocca due volte per tornare '
                'alle impostazioni.',
              );
            },
            onAttiva: () {
              _tornaIndietro(context);
            },
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Guida ai\ngesti',
            onTocco: () {
              _leggi(
                'Tocco singolo: ascolta il nome. '
                'Doppio tocco: apre o conferma. '
                'Tocco sul microfono: avvia '
                'il riconoscimento vocale. '
                'Pressione prolungata sul microfono: '
                'torna indietro.',
              );
            },
            onAttiva: () {
              _leggi('Guida ai gesti completata.');
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Stato\naccessibilità',
            onTocco: () {
              _leggi(
                'Navigazione vocale e feedback '
                'tramite vibrazione disponibili.',
              );
            },
            onAttiva: () {
              _leggi(
                'Le funzioni di accessibilità '
                'della modalità super semplificata '
                'sono attive.',
              );
            },
          ),
          onComando: (comando) async {
            final testo = comando.toLowerCase().trim();

            if (testo.contains('indietro') ||
                testo.contains('menu') ||
                testo.contains('menù')) {
              if (context.mounted) {
                Navigator.of(context).pop();
              }

              return true;
            }

            if (testo.contains('vibrazione')) {
              unawaited(VibrationService.pressioneProlungata());

              await TtsService.leggi('Prova vibrazione completata.');

              return true;
            }

            if (testo.contains('istruzioni')) {
              await TtsService.leggi(
                'Tocca una volta per ascoltare. '
                'Tocca due volte per confermare.',
              );

              return true;
            }

            if (testo.contains('gesti') || testo.contains('guida')) {
              await TtsService.leggi(
                'Tocco singolo per ascoltare. '
                'Doppio tocco per confermare. '
                'Tocco sul microfono per parlare.',
              );

              return true;
            }

            return false;
          },
        ),
      ),
    );
  }
}
