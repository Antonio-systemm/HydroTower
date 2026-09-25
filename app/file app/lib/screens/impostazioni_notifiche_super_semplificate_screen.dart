import 'dart:async';

import 'package:flutter/material.dart';

import '../services/comandi_vocali.dart';
import '../services/impostazioni_controller.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniNotificheSuperSemplificateScreen extends StatefulWidget {
  const ImpostazioniNotificheSuperSemplificateScreen({super.key});

  @override
  State<ImpostazioniNotificheSuperSemplificateScreen> createState() =>
      _ImpostazioniNotificheSuperSemplificateScreenState();
}

class _ImpostazioniNotificheSuperSemplificateScreenState
    extends State<ImpostazioniNotificheSuperSemplificateScreen> {
  final ImpostazioniController _controller = ImpostazioniController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_aggiornaInterfaccia);
    unawaited(_controller.carica());
  }

  void _aggiornaInterfaccia() {
    if (mounted) {
      setState(() {});
    }
  }

  String get _statoNotifiche =>
      _controller.notificheAttive ? 'attive' : 'disattivate';

  String get _azioneNotifiche =>
      _controller.notificheAttive ? 'Disattiva' : 'Attiva';

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _attivaNotifiche() {
    if (!_controller.notificheAttive) {
      _controller.aggiorna(notificheAttive: true);
    }

    _leggi('Notifiche attive. Tocca due volte Salva modifiche per confermare.');
  }

  void _disattivaNotifiche() {
    if (_controller.notificheAttive) {
      _controller.aggiorna(notificheAttive: false);
    }

    _leggi(
      'Notifiche disattivate. Tocca due volte Salva modifiche per confermare.',
    );
  }

  void _cambiaStato() {
    final nuovoStato = !_controller.notificheAttive;
    _controller.aggiorna(notificheAttive: nuovoStato);

    _leggi(
      nuovoStato
          ? 'Notifiche attive. Tocca due volte Salva modifiche per confermare.'
          : 'Notifiche disattivate. Tocca due volte Salva modifiche per confermare.',
    );
  }

  Future<void> _salva() async {
    final bool riuscito = await _controller.salva();

    if (!mounted) {
      return;
    }

    await TtsService.leggi(
      riuscito
          ? 'Notifiche salvate sul Raspberry Pi.'
          : 'Notifiche salvate localmente. '
                '${_controller.ultimoErrore ?? 'Raspberry Pi non raggiungibile.'}',
    );
  }

  void _tornaIndietro() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.contiene(comando, <String>[
      'attiva notifiche',
      'attiva',
      'accendi notifiche',
    ])) {
      _attivaNotifiche();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'disattiva notifiche',
      'disattiva',
      'spegni notifiche',
    ])) {
      _disattivaNotifiche();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'cambia stato',
      'inverti',
      'modifica notifiche',
    ])) {
      _cambiaStato();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'stato',
      'stato notifiche',
      'ripeti stato',
    ])) {
      await TtsService.leggi('Le notifiche sono $_statoNotifiche.');
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'salva',
      'salva modifiche',
      'conferma',
    ])) {
      await _salva();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'indietro',
      'torna indietro',
      'impostazioni',
      'menù',
      'menu',
    ])) {
      _tornaIndietro();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'aiuto',
      'comandi',
      'cosa posso dire',
      'ripeti',
    ])) {
      await TtsService.leggi(
        'Puoi dire: attiva notifiche, disattiva notifiche, cambia stato, '
        'stato notifiche, salva modifiche oppure indietro.',
      );
      return true;
    }

    return false;
  }

  @override
  void dispose() {
    _controller.removeListener(_aggiornaInterfaccia);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Impostazioni notifiche. In alto a sinistra puoi cambiare lo '
              'stato. In alto a destra puoi ascoltare lo stato corrente. '
              'Al centro è disponibile il microfono. In basso a sinistra '
              'puoi ripetere lo stato. In basso a destra puoi salvare.',
          domandaVocale:
              'Puoi dire: attiva notifiche, disattiva notifiche, cambia stato, '
              'stato notifiche, salva modifiche oppure indietro.',
          altoSinistra: ZoneAction(
            etichetta: '$_azioneNotifiche\nnotifiche',
            onTocco: () {
              _leggi(
                '$_azioneNotifiche notifiche. Tocca due volte per confermare.',
              );
            },
            onAttiva: _cambiaStato,
          ),
          altoDestra: ZoneAction(
            etichetta:
                'Stato\n${_controller.notificheAttive ? 'Attive' : 'Disattivate'}',
            onTocco: () {
              _leggi('Le notifiche sono $_statoNotifiche.');
            },
            onAttiva: () {
              _leggi('Le notifiche sono $_statoNotifiche.');
            },
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () {
              _leggi(
                'Tocca il microfono per parlare. Tienilo premuto per tornare alle impostazioni.',
              );
            },
            onAttiva: _tornaIndietro,
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Ripeti\nstato',
            onTocco: () {
              _leggi('Le notifiche sono $_statoNotifiche.');
            },
            onAttiva: () {
              _leggi('Le notifiche sono $_statoNotifiche.');
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Salva\nmodifiche',
            onTocco: () {
              _leggi(
                'Tocca due volte per salvare le notifiche $_statoNotifiche.',
              );
            },
            onAttiva: () {
              unawaited(_salva());
            },
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
