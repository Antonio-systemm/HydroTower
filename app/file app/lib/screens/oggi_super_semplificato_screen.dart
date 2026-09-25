import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';

class OggiSuperSemplificatoScreen extends StatefulWidget {
  const OggiSuperSemplificatoScreen({super.key});

  @override
  State<OggiSuperSemplificatoScreen> createState() => _State();
}

class _State extends State<OggiSuperSemplificatoScreen> {
  SensorSnapshot? d;
  bool _caricamento = false;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    if (_caricamento) {
      return;
    }

    _caricamento = true;

    try {
      final j = await ApiService.sensoriAttuali();

      if (!mounted) {
        return;
      }

      setState(() {
        d = j == null ? null : SensorSnapshot.fromJson(j);
      });
    } finally {
      _caricamento = false;
    }
  }

  String _v(double? x, String u) {
    if (x == null) {
      return 'non disponibile';
    }

    final unita = u.trim();
    return unita.isEmpty
        ? x.toStringAsFixed(1)
        : '${x.toStringAsFixed(1)} $unita';
  }

  Future<void> _feedbackLeggero() async {
    await HapticFeedback.mediumImpact();
  }

  Future<void> _feedbackForte() async {
    await HapticFeedback.heavyImpact();
  }

  Future<void> _eseguiConFeedback(
    Future<void> Function() azione, {
    bool forte = false,
  }) async {
    if (forte) {
      await _feedbackForte();
    } else {
      await _feedbackLeggero();
    }

    if (!mounted) {
      return;
    }

    await azione();
  }

  Future<void> _leggi(String cosa) async {
    String t;

    if (ComandiVocali.contiene(cosa, <String>['temperatura'])) {
      t = 'Temperatura: ${_v(d?.temperatura, 'gradi')}';
    } else if (ComandiVocali.contiene(cosa, <String>['luce'])) {
      t = 'Luce: ${_v(d?.luce, 'lux')}';
    } else if (ComandiVocali.contiene(cosa, <String>['aria'])) {
      t = 'Umidità dell’aria: ${_v(d?.umiditaAria, 'percento')}';
    } else if (ComandiVocali.contiene(cosa, <String>['terreno'])) {
      t = 'Umidità del terreno: ${_v(d?.umiditaTerreno, 'percento')}';
    } else if (ComandiVocali.contiene(cosa, <String>['tds', 't d s'])) {
      t = 'T D S: ${_v(d?.tds, 'p p m')}';
    } else if (ComandiVocali.contiene(cosa, <String>['ph', 'p h'])) {
      t = 'P H: ${_v(d?.ph, '')}';
    } else if (ComandiVocali.contiene(cosa, <String>['acqua', 'livello'])) {
      t = 'Livello dell’acqua: ${_v(d?.livelloAcqua, 'percento')}';
    } else {
      t = d?.letturaCompleta() ?? 'Dati non disponibili';
    }

    await TtsService.leggi(t);
  }

  Future<void> _tornaIndietro() async {
    if (!mounted) {
      return;
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Dati di oggi. La grafica è uguale alla modalità semplificata.',
          domandaVocale:
              'Puoi dire temperatura, luce, umidità aria, umidità terreno, '
              'T D S, P H, acqua, aggiorna, leggi tutto oppure menù.',
          altoSinistra: ZoneAction(
            etichetta: 'Temperatura\ne luce',
            onTocco: () => _eseguiConFeedback(() => _leggi('temperatura')),
            onAttiva: () =>
                _eseguiConFeedback(() => _leggi('luce'), forte: true),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Umidità\naria e terreno',
            onTocco: () => _eseguiConFeedback(() => _leggi('aria')),
            onAttiva: () =>
                _eseguiConFeedback(() => _leggi('terreno'), forte: true),
          ),
          centro: ZoneAction(
            etichetta: 'Menù',
            onTocco: () => _eseguiConFeedback(
              () =>
                  TtsService.leggi('Menù. Al centro trovi anche il microfono.'),
            ),
            onAttiva: () => _eseguiConFeedback(_tornaIndietro, forte: true),
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'T D S\ne P H',
            onTocco: () => _eseguiConFeedback(() => _leggi('tds')),
            onAttiva: () => _eseguiConFeedback(() => _leggi('ph'), forte: true),
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Livello\nacqua',
            onTocco: () => _eseguiConFeedback(() => _leggi('acqua')),
            onAttiva: () =>
                _eseguiConFeedback(() => _leggi('acqua'), forte: true),
          ),
          onComando: (c) async {
            if (ComandiVocali.contiene(c, <String>['menù', 'indietro'])) {
              await _feedbackForte();
              await _tornaIndietro();
              return true;
            }

            if (ComandiVocali.contiene(c, <String>['aggiorna'])) {
              await _feedbackLeggero();
              await _carica();
              await TtsService.leggi('Dati aggiornati');
              return true;
            }

            if (ComandiVocali.contiene(c, <String>[
              'temperatura',
              'luce',
              'aria',
              'terreno',
              'tds',
              't d s',
              'ph',
              'p h',
              'acqua',
              'livello',
              'tutto',
            ])) {
              await _feedbackLeggero();
              await _leggi(c);
              return true;
            }

            await HapticFeedback.vibrate();
            return false;
          },
        ),
      ),
    );
  }
}
