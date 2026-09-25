import 'dart:async';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniCampionamentoSuperSemplificateScreen extends StatefulWidget {
  const ImpostazioniCampionamentoSuperSemplificateScreen({super.key});

  @override
  State<ImpostazioniCampionamentoSuperSemplificateScreen> createState() =>
      _ImpostazioniCampionamentoSuperSemplificateScreenState();
}

class _ImpostazioniCampionamentoSuperSemplificateScreenState
    extends State<ImpostazioniCampionamentoSuperSemplificateScreen> {
  static const List<int> _intervalli = <int>[1, 5, 10, 30, 60];
  static const List<int> _conservazioni = <int>[7, 30, 90, 365, 0];

  int _voce = 0;
  int _intervallo = 5;
  int _conservazione = 30;
  bool _caricamento = true;
  bool _salvataggio = false;

  bool get _selezionaIntervallo => _voce == 0;
  String get _nomeVoce => _selezionaIntervallo
      ? 'Intervallo lettura sensori'
      : 'Conservazione dati';

  String get _valoreVoce {
    if (_selezionaIntervallo) {
      if (_intervallo == 1) return 'Ogni minuto';
      if (_intervallo == 60) return 'Ogni ora';
      return 'Ogni $_intervallo minuti';
    }
    switch (_conservazione) {
      case 0:
        return 'Sempre';
      case 7:
        return '7 giorni';
      case 30:
        return '30 giorni';
      case 90:
        return '3 mesi';
      case 365:
        return '1 anno';
      default:
        return '$_conservazione giorni';
    }
  }

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  Future<void> _carica() async {
    var intervallo = await AppSettings.getIntervalloMinuti();
    var conservazione = await AppSettings.getConservazioneGiorni();
    final remote = await ApiService.impostazioni();

    if (remote != null) {
      await AppSettings.applicaImpostazioniRemote(remote);
      intervallo = _intero(remote['interval']) ?? intervallo;
      conservazione = _intero(remote['retention']) ?? conservazione;
    }

    if (!_intervalli.contains(intervallo)) intervallo = 5;
    if (!_conservazioni.contains(conservazione)) conservazione = 30;
    if (!mounted) return;

    setState(() {
      _intervallo = intervallo;
      _conservazione = conservazione;
      _caricamento = false;
    });
  }

  int? _intero(dynamic valore) =>
      valore is num ? valore.toInt() : int.tryParse(valore?.toString() ?? '');

  void _leggi(String testo) => unawaited(TtsService.leggi(testo));

  void _sposta(int direzione) {
    if (_caricamento || _salvataggio) return;
    final List<int> valori = _selezionaIntervallo
        ? _intervalli
        : _conservazioni;
    final int corrente = _selezionaIntervallo ? _intervallo : _conservazione;
    final int indice =
        (valori.indexOf(corrente) + direzione + valori.length) % valori.length;

    setState(() {
      if (_selezionaIntervallo) {
        _intervallo = valori[indice];
      } else {
        _conservazione = valori[indice];
      }
    });
    _leggi('$_nomeVoce: $_valoreVoce.');
  }

  void _voceSuccessiva() {
    if (_caricamento || _salvataggio) return;
    setState(() => _voce = (_voce + 1) % 2);
    _leggi('$_nomeVoce: $_valoreVoce.');
  }

  Future<void> _salva() async {
    if (_caricamento || _salvataggio) return;
    setState(() => _salvataggio = true);

    await AppSettings.setIntervalloMinuti(_intervallo);
    await AppSettings.setConservazioneGiorni(_conservazione);
    final risultato = await ApiService.salvaImpostazioni(<String, dynamic>{
      'interval': _intervallo,
      'retention': _conservazione,
    });

    if (!mounted) return;
    setState(() => _salvataggio = false);
    await TtsService.leggi(
      risultato['ok'] == true
          ? 'Impostazioni salvate sul Raspberry Pi.'
          : 'Salvate sul telefono, ma non sul Raspberry Pi. '
                '${risultato['error'] ?? 'Errore sconosciuto.'}',
    );
  }

  void _tornaIndietro() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.contiene(comando, <String>[
      'valore precedente',
      'precedente',
    ])) {
      _sposta(-1);
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'valore successivo',
      'successivo',
      'avanti',
    ])) {
      _sposta(1);
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'voce successiva',
      'cambia voce',
      'cambia parametro',
    ])) {
      _voceSuccessiva();
      return true;
    }
    if (ComandiVocali.contiene(comando, <String>[
      'valore',
      'stato',
      'ripeti',
    ])) {
      await TtsService.leggi('$_nomeVoce: $_valoreVoce.');
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
  Widget build(BuildContext context) {
    if (_caricamento) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Campionamento. In alto puoi scegliere il valore. '
              'In basso a sinistra puoi cambiare parametro. '
              'In basso a destra puoi salvare.',
          domandaVocale:
              'Puoi dire valore precedente, valore successivo, voce successiva, '
              'valore, salva modifiche oppure indietro.',
          altoSinistra: ZoneAction(
            etichetta: 'Valore\nprecedente',
            onTocco: () => _leggi('Valore precedente per $_nomeVoce.'),
            onAttiva: () => _sposta(-1),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Valore\nsuccessivo',
            onTocco: () => _leggi('Valore successivo per $_nomeVoce.'),
            onAttiva: () => _sposta(1),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => _leggi(
              'Tieni premuto il microfono per tornare alle impostazioni.',
            ),
            onAttiva: _tornaIndietro,
          ),
          bassoSinistra: ZoneAction(
            etichetta: '$_valoreVoce\nVoce successiva',
            onTocco: () => _leggi('$_nomeVoce: $_valoreVoce.'),
            onAttiva: _voceSuccessiva,
          ),
          bassoDestra: ZoneAction(
            etichetta: _salvataggio
                ? 'Salvataggio\nin corso'
                : 'Salva\nmodifiche',
            onTocco: () => _leggi('Tocca due volte per salvare.'),
            onAttiva: () => unawaited(_salva()),
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
