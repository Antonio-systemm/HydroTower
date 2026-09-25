import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/comandi_vocali.dart';
import '../services/modalita_app_service.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniAccessibilitaSuperSemplificateScreen extends StatefulWidget {
  const ImpostazioniAccessibilitaSuperSemplificateScreen({super.key});

  @override
  State<ImpostazioniAccessibilitaSuperSemplificateScreen> createState() =>
      _ImpostazioniAccessibilitaSuperSemplificateScreenState();
}

class _ImpostazioniAccessibilitaSuperSemplificateScreenState
    extends State<ImpostazioniAccessibilitaSuperSemplificateScreen> {
  ModalitaInterfaccia _selezionata = ModalitaInterfaccia.superSemplificata;
  bool _caricamento = true;
  bool _cambioInCorso = false;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  Future<void> _carica() async {
    final ModalitaInterfaccia modalita =
        await AppSettings.getModalitaInterfaccia();

    if (!mounted) {
      return;
    }

    setState(() {
      _selezionata = modalita;
      _caricamento = false;
    });
  }

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _sposta(int delta) {
    if (_cambioInCorso) {
      return;
    }

    final List<ModalitaInterfaccia> valori = ModalitaInterfaccia.values;
    final int indice =
        (valori.indexOf(_selezionata) + delta + valori.length) % valori.length;

    setState(() {
      _selezionata = valori[indice];
    });

    _leggi('Modalità selezionata: ${_selezionata.etichetta}.');
  }

  Future<void> _applicaModalita() async {
    if (_cambioInCorso) {
      return;
    }

    final ModalitaInterfaccia nuovaModalita = _selezionata;

    setState(() {
      _cambioInCorso = true;
    });

    await TtsService.ferma();
    await ModalitaAppService.imposta(nuovaModalita);

    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

    unawaited(TtsService.leggi('${nuovaModalita.etichetta} attivata.'));
  }

  Future<void> _ripristina() async {
    if (_cambioInCorso) {
      return;
    }

    await AppSettings.ripristinaImpostazioni();
    await TtsService.leggi(
      'Le impostazioni locali sono state ripristinate. '
      'La modalità dell’interfaccia non è stata modificata.',
    );
  }

  void _tornaIndietro() {
    if (mounted && !_cambioInCorso) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.comandoMenu(comando)) {
      _tornaIndietro();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'modalità precedente',
      'modalita precedente',
      'precedente',
    ])) {
      _sposta(-1);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'modalità successiva',
      'modalita successiva',
      'successiva',
    ])) {
      _sposta(1);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia normale',
      'modalità normale',
      'modalita normale',
    ])) {
      setState(() {
        _selezionata = ModalitaInterfaccia.normale;
      });
      await _applicaModalita();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia super semplificata',
      'modalità super semplificata',
      'modalita super semplificata',
    ])) {
      setState(() {
        _selezionata = ModalitaInterfaccia.superSemplificata;
      });
      await _applicaModalita();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia semplificata',
      'modalità semplificata',
      'modalita semplificata',
    ])) {
      setState(() {
        _selezionata = ModalitaInterfaccia.semplificata;
      });
      await _applicaModalita();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'salva',
      'applica',
      'conferma',
      'cambia modalità',
    ])) {
      await _applicaModalita();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'stato',
      'modalità selezionata',
      'modalita selezionata',
    ])) {
      await TtsService.leggi(
        'Modalità selezionata: ${_selezionata.etichetta}.',
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Accessibilità. In alto a sinistra Modalità precedente. '
              'In alto a destra Modalità successiva. '
              'Al centro trovi il microfono. '
              'In basso a sinistra trovi la modalità selezionata. '
              'In basso a destra trovi Salva e cambia modalità.',
          domandaVocale:
              'Puoi dire Modalità normale, Modalità semplificata, '
              'Modalità super semplificata, Modalità precedente, '
              'Modalità successiva, Salva oppure Indietro.',
          altoSinistra: ZoneAction(
            etichetta: 'Modalità\nprecedente',
            onTocco: () {
              _leggi('Modalità precedente. Tocca due volte per selezionarla.');
            },
            onAttiva: () {
              _sposta(-1);
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Modalità\nsuccessiva',
            onTocco: () {
              _leggi('Modalità successiva. Tocca due volte per selezionarla.');
            },
            onAttiva: () {
              _sposta(1);
            },
          ),
          centro: ZoneAction(
            etichetta: 'Indietro',
            onTocco: () {
              _leggi(
                'Microfono. Tocca per parlare. '
                'Tieni premuto per tornare alle impostazioni.',
              );
            },
            onAttiva: _tornaIndietro,
          ),
          bassoSinistra: ZoneAction(
            etichetta: _selezionata.etichetta,
            onTocco: () {
              _leggi('Modalità selezionata: ${_selezionata.etichetta}.');
            },
            onAttiva: () {
              unawaited(_ripristina());
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: _cambioInCorso
                ? 'Cambio\nin corso'
                : 'Salva e\ncambia modalità',
            onTocco: () {
              _leggi('Tocca due volte per attivare ${_selezionata.etichetta}.');
            },
            onAttiva: () {
              unawaited(_applicaModalita());
            },
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
