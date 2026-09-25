import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniCampionamentoSemplificateScreen extends StatefulWidget {
  const ImpostazioniCampionamentoSemplificateScreen({super.key});

  @override
  State<ImpostazioniCampionamentoSemplificateScreen> createState() => _State();
}

class _State extends State<ImpostazioniCampionamentoSemplificateScreen> {
  static const List<int> _intervalli = <int>[1, 5, 10, 30, 60];
  static const List<int> _conservazioni = <int>[7, 30, 90, 365, 0];

  int _voce = 0;
  int _intervallo = 5;
  int _conservazione = 30;
  bool _loading = true;
  bool _saving = false;

  bool get _isIntervallo => _voce == 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var intervallo = await AppSettings.getIntervalloMinuti();
    var conservazione = await AppSettings.getConservazioneGiorni();
    final remote = await ApiService.impostazioni();
    if (remote != null) {
      await AppSettings.applicaImpostazioniRemote(remote);
      intervallo = _asInt(remote['interval']) ?? intervallo;
      conservazione = _asInt(remote['retention']) ?? conservazione;
    }
    if (!_intervalli.contains(intervallo)) intervallo = 5;
    if (!_conservazioni.contains(conservazione)) conservazione = 30;
    if (!mounted) return;
    setState(() {
      _intervallo = intervallo;
      _conservazione = conservazione;
      _loading = false;
    });
  }

  int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  String get _nome =>
      _isIntervallo ? 'Intervallo lettura sensori' : 'Conservazione dati';

  String get _valore {
    if (_isIntervallo) {
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

  void _move(int delta) {
    if (_loading || _saving) return;
    final values = _isIntervallo ? _intervalli : _conservazioni;
    final current = _isIntervallo ? _intervallo : _conservazione;
    final index =
        (values.indexOf(current) + delta + values.length) % values.length;
    setState(() {
      if (_isIntervallo) {
        _intervallo = values[index];
      } else {
        _conservazione = values[index];
      }
    });
    TtsService.leggi('$_nome: $_valore.');
  }

  void _next() {
    if (_loading || _saving) return;
    setState(() => _voce = (_voce + 1) % 2);
    TtsService.leggi('$_nome: $_valore.');
  }

  Future<void> _save() async {
    if (_loading || _saving) return;
    setState(() => _saving = true);
    await AppSettings.setIntervalloMinuti(_intervallo);
    await AppSettings.setConservazioneGiorni(_conservazione);
    final result = await ApiService.salvaImpostazioni(<String, dynamic>{
      'interval': _intervallo,
      'retention': _conservazione,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['ok'] == true) {
      await TtsService.leggi('Impostazioni salvate sul Raspberry Pi.');
    } else {
      await TtsService.leggi(
        'Salvate sul telefono, ma non sul Raspberry Pi. '
        '${result['error'] ?? 'Errore sconosciuto'}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura:
              'Campionamento. In alto scegli il valore. Al centro torna indietro. '
              'In basso a sinistra cambia voce. In basso a destra salva.',
          altoSinistra: ZoneAction(
            etichetta: 'Valore\nprecedente',
            onTocco: () => _move(-1),
            onAttiva: () => _move(-1),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Valore\nsuccessivo',
            onTocco: () => _move(1),
            onAttiva: () => _move(1),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => TtsService.leggi('Torna alle impostazioni'),
            onAttiva: () => Navigator.of(context).pop(),
          ),
          bassoSinistra: ZoneAction(
            etichetta: '$_valore\nVoce successiva',
            onTocco: () => TtsService.leggi('$_nome: $_valore.'),
            onAttiva: _next,
          ),
          bassoDestra: ZoneAction(
            etichetta: _saving ? 'Salvataggio\nin corso' : 'Salva\nmodifiche',
            onTocco: () => TtsService.leggi('Tocca due volte per salvare.'),
            onAttiva: _save,
          ),
        ),
      ),
    );
  }
}
