import 'dart:async';

import 'package:flutter/material.dart';

import '../services/comandi_vocali.dart';
import '../services/impostazioni_controller.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniAllarmiSuperSemplificateScreen extends StatefulWidget {
  const ImpostazioniAllarmiSuperSemplificateScreen({super.key});

  @override
  State<ImpostazioniAllarmiSuperSemplificateScreen> createState() =>
      _ImpostazioniAllarmiSuperSemplificateScreenState();
}

class _ImpostazioniAllarmiSuperSemplificateScreenState
    extends State<ImpostazioniAllarmiSuperSemplificateScreen> {
  static const List<String> _nomi = <String>[
    'Temperatura massima',
    'P H minimo',
    'P H massimo',
    'T D S massimo',
    'Livello acqua minimo',
    'Umidità aria minima',
    'Umidità terreno minima',
  ];

  final ImpostazioniController _controller = ImpostazioniController();
  int _indice = 0;

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

  double get _valore => <double>[
    _controller.tempMax,
    _controller.phMin,
    _controller.phMax,
    _controller.tdsMax,
    _controller.acquaMin,
    _controller.umiditaAriaMin,
    _controller.umiditaTerrenoMin,
  ][_indice];

  double get _passo {
    if (_indice == 3) return 50;
    if (_indice == 1 || _indice == 2) return 0.1;
    return 1;
  }

  String get _nomeCorrente => _nomi[_indice];

  String get _valoreFormattato => (_indice == 1 || _indice == 2)
      ? _valore.toStringAsFixed(1)
      : _valore.toStringAsFixed(0);

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _cambiaValore(int direzione) {
    final double massimo = _indice == 3 ? 5000 : 100;
    final double nuovoValore = (_valore + (_passo * direzione))
        .clamp(0, massimo)
        .toDouble();

    switch (_indice) {
      case 0:
        _controller.aggiorna(tempMax: nuovoValore);
        break;
      case 1:
        _controller.aggiorna(phMin: nuovoValore);
        break;
      case 2:
        _controller.aggiorna(phMax: nuovoValore);
        break;
      case 3:
        _controller.aggiorna(tdsMax: nuovoValore);
        break;
      case 4:
        _controller.aggiorna(acquaMin: nuovoValore);
        break;
      case 5:
        _controller.aggiorna(umiditaAriaMin: nuovoValore);
        break;
      case 6:
        _controller.aggiorna(umiditaTerrenoMin: nuovoValore);
        break;
    }

    _leggi('$_nomeCorrente: $_valoreFormattato.');
  }

  void _sogliaSuccessiva() {
    setState(() {
      _indice = (_indice + 1) % _nomi.length;
    });
    _leggi('$_nomeCorrente: $_valoreFormattato.');
  }

  void _sogliaPrecedente() {
    setState(() {
      _indice = (_indice - 1 + _nomi.length) % _nomi.length;
    });
    _leggi('$_nomeCorrente: $_valoreFormattato.');
  }

  Future<void> _salva() async {
    final bool riuscito = await _controller.salva();
    await TtsService.leggi(
      riuscito
          ? 'Soglie salvate sul Raspberry Pi.'
          : 'Soglie salvate localmente. '
                '${_controller.ultimoErrore ?? 'Raspberry Pi non raggiungibile.'}',
    );
  }

  void _tornaIndietro() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.contiene(comando, <String>[
      'aumenta',
      'più',
      'incrementa',
    ])) {
      _cambiaValore(1);
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'diminuisci',
      'meno',
      'riduci',
    ])) {
      _cambiaValore(-1);
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'soglia successiva',
      'successiva',
      'avanti',
    ])) {
      _sogliaSuccessiva();
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'soglia precedente',
      'precedente',
    ])) {
      _sogliaPrecedente();
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'valore',
      'stato',
      'ripeti',
    ])) {
      await TtsService.leggi('$_nomeCorrente: $_valoreFormattato.');
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
      'impostazioni',
      'menù',
      'menu',
    ])) {
      _tornaIndietro();
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
              'Soglie di allarme. In alto puoi diminuire o aumentare il valore. '
              'In basso a sinistra puoi cambiare soglia. In basso a destra puoi salvare.',
          domandaVocale:
              'Puoi dire aumenta, diminuisci, soglia successiva, soglia precedente, '
              'valore, salva modifiche oppure indietro.',
          altoSinistra: ZoneAction(
            etichetta: 'Diminuisci\n$_nomeCorrente',
            onTocco: () => _leggi('Diminuisci $_nomeCorrente.'),
            onAttiva: () => _cambiaValore(-1),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Aumenta\n$_nomeCorrente',
            onTocco: () => _leggi('Aumenta $_nomeCorrente.'),
            onAttiva: () => _cambiaValore(1),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => _leggi(
              'Tieni premuto il microfono per tornare alle impostazioni.',
            ),
            onAttiva: _tornaIndietro,
          ),
          bassoSinistra: ZoneAction(
            etichetta: '$_valoreFormattato\nSoglia successiva',
            onTocco: () => _leggi('$_nomeCorrente: $_valoreFormattato.'),
            onAttiva: _sogliaSuccessiva,
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Salva\nmodifiche',
            onTocco: () => _leggi('Tocca due volte per salvare le soglie.'),
            onAttiva: () => unawaited(_salva()),
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
