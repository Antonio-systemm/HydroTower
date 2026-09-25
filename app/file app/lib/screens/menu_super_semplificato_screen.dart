import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'analisi_super_semplificata_screen.dart';
import 'impostazioni_super_semplificate_screen.dart';
import 'oggi_super_semplificato_screen.dart';
import 'report_super_semplificato_screen.dart';
import 'storico_super_semplificato_screen.dart';

class MenuSuperSemplificatoScreen extends StatefulWidget {
  const MenuSuperSemplificatoScreen({super.key});

  @override
  State<MenuSuperSemplificatoScreen> createState() =>
      _MenuSuperSemplificatoScreenState();
}

class _MenuSuperSemplificatoScreenState
    extends State<MenuSuperSemplificatoScreen> {
  static const String _annuncioMenu =
      'Menù principale. '
      'In alto a sinistra trovi Oggi. '
      'In alto a destra trovi Analisi. '
      'Al centro trovi il microfono. '
      'Tieni premuto il microfono per aprire Impostazioni. '
      'In basso a sinistra trovi Report. '
      'In basso a destra trovi Storico.';

  static const String _comandiMenu =
      'Puoi chiedere direttamente i dati dei sensori, la temperatura, '
      'il P H, il T D S, il livello dell’acqua, il report di oggi '
      'oppure puoi dire avvia nuovo report. '
      'Puoi anche dire apri Oggi, apri Analisi, apri Impostazioni, '
      'apri Report, apri Storico oppure aiuto.';

  bool _operazioneInCorso = false;

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  Future<void> _ripetiPosizioniMenu() async {
    await TtsService.leggi(
      'Sei tornato al menù principale. $_annuncioMenu $_comandiMenu',
    );
  }

  Future<void> _apriPagina(Widget pagina) async {
    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => pagina));

    if (!mounted) {
      return;
    }

    await _ripetiPosizioniMenu();
  }

  String _formatoApi(DateTime data) {
    final String anno = data.year.toString().padLeft(4, '0');
    final String mese = data.month.toString().padLeft(2, '0');
    final String giorno = data.day.toString().padLeft(2, '0');
    return '$anno-$mese-$giorno';
  }

  String _testoCampo(
    dynamic valore, {
    String valoreAssente = 'non disponibile',
  }) {
    if (valore == null) {
      return valoreAssente;
    }

    if (valore is List) {
      if (valore.isEmpty) {
        return valoreAssente;
      }

      return valore.map((dynamic elemento) => elemento.toString()).join('. ');
    }

    final String testo = valore.toString().trim();
    return testo.isEmpty ? valoreAssente : testo;
  }

  String _valoreSensore(double? valore, String unita) {
    if (valore == null) {
      return 'non disponibile';
    }

    return '${valore.toStringAsFixed(1)} $unita'.trim();
  }

  Future<void> _leggiDatiSensori(String comando) async {
    if (_operazioneInCorso) {
      await TtsService.leggi('Attendi. È già in corso un’operazione.');
      return;
    }

    _operazioneInCorso = true;

    try {
      final Map<String, dynamic>? json = await ApiService.sensoriAttuali();

      if (json == null) {
        await TtsService.leggi(
          'Non riesco a leggere i sensori. Controlla il Raspberry Pi.',
        );
        return;
      }

      final SensorSnapshot dati = SensorSnapshot.fromJson(json);
      late final String risposta;

      if (ComandiVocali.contiene(comando, <String>['temperatura'])) {
        risposta = 'Temperatura: ${_valoreSensore(dati.temperatura, 'gradi')}.';
      } else if (ComandiVocali.contiene(comando, <String>['luce'])) {
        risposta = 'Luce: ${_valoreSensore(dati.luce, 'lux')}.';
      } else if (ComandiVocali.contiene(comando, <String>[
        'umidita aria',
        'umidità aria',
        'aria',
      ])) {
        risposta =
            'Umidità dell’aria: ${_valoreSensore(dati.umiditaAria, 'percento')}.';
      } else if (ComandiVocali.contiene(comando, <String>[
        'umidita terreno',
        'umidità terreno',
        'terreno',
      ])) {
        risposta =
            'Umidità del terreno: ${_valoreSensore(dati.umiditaTerreno, 'percento')}.';
      } else if (ComandiVocali.contiene(comando, <String>['tds', 't d s'])) {
        risposta = 'T D S: ${_valoreSensore(dati.tds, 'p p m')}.';
      } else if (ComandiVocali.contiene(comando, <String>['ph', 'p h'])) {
        risposta = 'P H: ${_valoreSensore(dati.ph, '')}.';
      } else if (ComandiVocali.contiene(comando, <String>[
        'livello acqua',
        'livello dell acqua',
        'acqua',
      ])) {
        risposta =
            'Livello dell’acqua: ${_valoreSensore(dati.livelloAcqua, 'percento')}.';
      } else {
        risposta = dati.letturaCompleta();
      }

      await TtsService.leggi(risposta);
    } finally {
      _operazioneInCorso = false;
    }
  }

  Future<void> _leggiReportOggi() async {
    if (_operazioneInCorso) {
      await TtsService.leggi('Attendi. È già in corso un’operazione.');
      return;
    }

    _operazioneInCorso = true;

    try {
      final Map<String, dynamic>? report = await ApiService.reportDettaglio(
        _formatoApi(DateTime.now()),
      );

      if (report == null) {
        await TtsService.leggi(
          'Il report di oggi non è disponibile. '
          'Puoi dire avvia nuovo report.',
        );
        return;
      }

      final StringBuffer testo = StringBuffer()
        ..write('Report di oggi. ')
        ..write('Punteggio: ${_testoCampo(report['punteggio'])} su dieci. ')
        ..write('Stato: ${_testoCampo(report['stato'])}. ')
        ..write('Sommario: ${_testoCampo(report['sommario'])}. ')
        ..write(
          'Condizioni ottimali: '
          '${_testoCampo(report['condizioni_ottimali'])}. ',
        )
        ..write(
          'Analisi dei sensori: '
          '${_testoCampo(report['analisi_sensori'])}. ',
        );

      final dynamic azioniRaw = report['azioni'];

      if (azioniRaw is List && azioniRaw.isNotEmpty) {
        testo.write('Azioni consigliate. ');

        for (int indice = 0; indice < azioniRaw.length; indice++) {
          testo.write('${indice + 1}. ${azioniRaw[indice]}. ');
        }
      } else {
        testo.write('Nessuna azione consigliata.');
      }

      await TtsService.leggi(testo.toString());
    } finally {
      _operazioneInCorso = false;
    }
  }

  Future<void> _avviaNuovoReport() async {
    if (_operazioneInCorso) {
      await TtsService.leggi('Attendi. È già in corso un’operazione.');
      return;
    }

    _operazioneInCorso = true;

    try {
      await TtsService.leggi(
        'Avvio un nuovo report usando la fotocamera del Raspberry Pi. '
        'L’operazione può richiedere alcuni secondi.',
      );

      final Map<String, dynamic> risultato =
          await ApiService.avviaRoutineRaspberry();

      if (risultato['ok'] == true) {
        await TtsService.leggi(
          'Nuovo report completato e salvato. '
          'Puoi dire leggi report di oggi.',
        );
      } else {
        await TtsService.leggi(
          'Non sono riuscito a creare il report. '
          '${risultato['error'] ?? 'Errore sconosciuto.'}',
        );
      }
    } finally {
      _operazioneInCorso = false;
    }
  }

  Future<bool> _gestisciComando(String comando) async {
    // Comando diretto: crea un report senza abbandonare il menù.
    if (ComandiVocali.contiene(comando, <String>[
      'avvia nuovo report',
      'crea nuovo report',
      'genera nuovo report',
      'fai un nuovo report',
      'nuovo report',
      'avvia report',
      'crea report',
      'genera report',
    ])) {
      await _avviaNuovoReport();
      return true;
    }

    // Comando diretto: legge il report corrente senza aprire Report.
    if (ComandiVocali.contiene(comando, <String>[
      'leggi report di oggi',
      'report di oggi',
      'report oggi',
      'dimmi il report di oggi',
      'ascolta il report di oggi',
      'leggi report',
      'ascolta report',
    ])) {
      await _leggiReportOggi();
      return true;
    }

    // Comando diretto: legge tutti i sensori o un singolo sensore.
    if (ComandiVocali.contiene(comando, <String>[
      'dati dei sensori',
      'dati sensori',
      'leggi i sensori',
      'leggi sensori',
      'situazione sensori',
      'come stanno i sensori',
      'leggi tutto',
      'tutti i dati',
      'temperatura',
      'luce',
      'umidita aria',
      'umidità aria',
      'umidita terreno',
      'umidità terreno',
      'aria',
      'terreno',
      'tds',
      't d s',
      'ph',
      'p h',
      'livello acqua',
      'livello dell acqua',
    ])) {
      await _leggiDatiSensori(comando);
      return true;
    }

    // Apertura facoltativa delle schermate tradizionali.
    if (ComandiVocali.contiene(comando, <String>[
      'oggi',
      'apri oggi',
      'vai a oggi',
      'schermata oggi',
    ])) {
      await _apriPagina(const OggiSuperSemplificatoScreen());
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'analisi',
      'apri analisi',
      'vai ad analisi',
      'schermata analisi',
      'apri foto',
    ])) {
      await _apriPagina(const AnalisiSuperSemplificataScreen());
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'impostazioni',
      'apri impostazioni',
      'vai alle impostazioni',
      'configurazione',
    ])) {
      await _apriPagina(const ImpostazioniSuperSemplificateScreen());
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'report',
      'apri report',
      'vai al report',
      'schermata report',
    ])) {
      await _apriPagina(const ReportSuperSemplificatoScreen());
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'storico',
      'apri storico',
      'vai allo storico',
      'schermata storico',
      'cronologia',
    ])) {
      await _apriPagina(const StoricoSuperSemplificatoScreen());
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'ripeti',
      'posizioni',
      'ripeti posizioni',
      'dove sono i tasti',
      'aiuto',
      'cosa posso dire',
      'comandi',
    ])) {
      await TtsService.leggi('$_annuncioMenu $_comandiMenu');
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura: _annuncioMenu,
          domandaVocale: _comandiMenu,
          altoSinistra: ZoneAction(
            etichetta: 'Oggi',
            onTocco: () {
              _leggi('Oggi. Tocca due volte per aprire.');
            },
            onAttiva: () {
              unawaited(_apriPagina(const OggiSuperSemplificatoScreen()));
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Analisi',
            onTocco: () {
              _leggi('Analisi. Tocca due volte per aprire.');
            },
            onAttiva: () {
              unawaited(_apriPagina(const AnalisiSuperSemplificataScreen()));
            },
          ),
          centro: ZoneAction(
            etichetta: 'Impostazioni',
            onTocco: () {
              _leggi(
                'Microfono. Tocca e chiedi direttamente i dati dei sensori, '
                'il report di oggi oppure di avviare un nuovo report. '
                'Tieni premuto per aprire Impostazioni.',
              );
            },
            onAttiva: () {
              unawaited(
                _apriPagina(const ImpostazioniSuperSemplificateScreen()),
              );
            },
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Report',
            onTocco: () {
              _leggi('Report. Tocca due volte per aprire.');
            },
            onAttiva: () {
              unawaited(_apriPagina(const ReportSuperSemplificatoScreen()));
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Storico',
            onTocco: () {
              _leggi('Storico. Tocca due volte per aprire.');
            },
            onAttiva: () {
              unawaited(_apriPagina(const StoricoSuperSemplificatoScreen()));
            },
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
