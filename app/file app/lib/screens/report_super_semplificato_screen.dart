import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'lettura_dati_screen.dart';

class ReportSuperSemplificatoScreen extends StatefulWidget {
  const ReportSuperSemplificatoScreen({super.key});

  @override
  State<ReportSuperSemplificatoScreen> createState() =>
      _ReportSuperSemplificatoScreenState();
}

class _ReportSuperSemplificatoScreenState
    extends State<ReportSuperSemplificatoScreen> {
  DateTime _dataSelezionata = DateTime.now();

  Map<String, dynamic>? _report;
  bool _caricamento = false;

  String _formatoApi(DateTime data) {
    final anno = data.year.toString().padLeft(4, '0');
    final mese = data.month.toString().padLeft(2, '0');
    final giorno = data.day.toString().padLeft(2, '0');

    return '$anno-$mese-$giorno';
  }

  String _nomeMese(int mese) {
    const mesi = [
      'gennaio',
      'febbraio',
      'marzo',
      'aprile',
      'maggio',
      'giugno',
      'luglio',
      'agosto',
      'settembre',
      'ottobre',
      'novembre',
      'dicembre',
    ];

    return mesi[mese - 1];
  }

  String _dataLeggibile(DateTime data) {
    return '${data.day} ${_nomeMese(data.month)} ${data.year}';
  }

  Future<void> _caricaReport({bool annuncia = true}) async {
    if (_caricamento) {
      return;
    }

    setState(() {
      _caricamento = true;
      _report = null;
    });

    final dataApi = _formatoApi(_dataSelezionata);

    final dettaglio = await ApiService.reportDettaglio(dataApi);

    if (!mounted) {
      return;
    }

    setState(() {
      _report = dettaglio;
      _caricamento = false;
    });

    if (!annuncia) {
      return;
    }

    if (dettaglio == null) {
      await TtsService.leggi(
        'Nessun report disponibile per il '
        '${_dataLeggibile(_dataSelezionata)}.',
      );
    } else {
      await TtsService.leggi(
        'Report del ${_dataLeggibile(_dataSelezionata)} caricato. '
        'Puoi dire: leggi report.',
      );
    }
  }

  Future<void> _cambiaGiorno(int differenza) async {
    final nuovaData = DateTime(
      _dataSelezionata.year,
      _dataSelezionata.month,
      _dataSelezionata.day + differenza,
    );

    final oggi = DateTime.now();
    final dataOdierna = DateTime(oggi.year, oggi.month, oggi.day);

    if (nuovaData.isAfter(dataOdierna)) {
      await TtsService.leggi('Non puoi selezionare una data futura.');

      return;
    }

    setState(() {
      _dataSelezionata = nuovaData;
      _report = null;
    });

    await TtsService.leggi(
      'Data selezionata: '
      '${_dataLeggibile(_dataSelezionata)}.',
    );

    await _caricaReport(annuncia: false);
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

      return valore.map((elemento) => elemento.toString()).join('. ');
    }

    final testo = valore.toString().trim();

    if (testo.isEmpty) {
      return valoreAssente;
    }

    return testo;
  }

  String _creaTestoReport(Map<String, dynamic> report) {
    final azioniRaw = report['azioni'];

    final List<String> azioni;

    if (azioniRaw is List) {
      azioni = azioniRaw.map((elemento) => elemento.toString()).toList();
    } else {
      azioni = [];
    }

    final azioniUrgenti = report['azioni_urgenti'] is num
        ? (report['azioni_urgenti'] as num).toInt()
        : 0;

    final buffer = StringBuffer();

    buffer.write(
      'Report giornaliero del '
      '${_dataLeggibile(_dataSelezionata)}. ',
    );

    buffer.write(
      'Punteggio: '
      '${_testoCampo(report['punteggio'])} su dieci. ',
    );

    buffer.write(
      'Stato: '
      '${_testoCampo(report['stato'])}. ',
    );

    buffer.write(
      'Sommario: '
      '${_testoCampo(report['sommario'])}. ',
    );

    buffer.write(
      'Temperatura: '
      '${_testoCampo(report['temperatura'])} gradi. ',
    );

    buffer.write(
      'Umidità dell’aria: '
      '${_testoCampo(report['umidita'])} percento. ',
    );

    buffer.write(
      'Umidità del terreno: '
      '${_testoCampo(report['umidita_terreno'])} percento. ',
    );

    buffer.write(
      'Luce: '
      '${_testoCampo(report['luce'])} lux. ',
    );

    buffer.write(
      'T D S: '
      '${_testoCampo(report['tds'])} p p m. ',
    );

    buffer.write(
      'P H: '
      '${_testoCampo(report['ph'])}. ',
    );

    buffer.write(
      'Livello dell’acqua: '
      '${_testoCampo(report['livello_acqua'])} percento. ',
    );

    buffer.write(
      'Osservazioni dalla foto: '
      '${_testoCampo(report['osservazioni_foto'])}. ',
    );

    buffer.write(
      'Condizioni ottimali: '
      '${_testoCampo(report['condizioni_ottimali'])}. ',
    );

    buffer.write(
      'Analisi dei sensori: '
      '${_testoCampo(report['analisi_sensori'])}. ',
    );

    if (azioni.isEmpty) {
      buffer.write('Nessuna azione consigliata.');
    } else {
      buffer.write('Azioni consigliate. ');

      for (var indice = 0; indice < azioni.length; indice++) {
        final urgente = indice < azioniUrgenti ? 'Urgente. ' : '';

        buffer.write(
          '${indice + 1}. '
          '$urgente'
          '${azioni[indice]}. ',
        );
      }
    }

    return buffer.toString();
  }

  Future<void> _leggiReport() async {
    if (_caricamento) {
      await TtsService.leggi('Il report è in fase di caricamento. Attendi.');

      return;
    }

    if (_report == null) {
      await _caricaReport(annuncia: false);

      if (!mounted) {
        return;
      }
    }

    final report = _report;

    if (report == null) {
      await TtsService.leggi(
        'Nessun report disponibile per il '
        '${_dataLeggibile(_dataSelezionata)}.',
      );

      return;
    }

    final testo = _creaTestoReport(report);

    if (!mounted) {
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LetturaDatiScreen(testo: testo)));
  }

  Future<void> _selezionaDataVocale(String comando) async {
    final nuovaData = ComandiVocali.dataCompleta(
      comando,
      riferimento: _dataSelezionata,
    );

    if (nuovaData == null) {
      await TtsService.leggi(
        'Non ho riconosciuto una data completa. '
        'Pronuncia giorno, mese e anno. '
        'Per esempio: sedici agosto duemilaventisei.',
      );

      return;
    }

    final oggi = DateTime.now();

    final dataOdierna = DateTime(oggi.year, oggi.month, oggi.day);

    if (nuovaData.isAfter(dataOdierna)) {
      await TtsService.leggi(
        'La data indicata è futura. '
        'Scegli una data uguale o precedente a oggi.',
      );

      return;
    }

    setState(() {
      _dataSelezionata = nuovaData;
      _report = null;
    });

    await TtsService.leggi(
      'Data selezionata: '
      '${_dataLeggibile(_dataSelezionata)}.',
    );

    await _caricaReport(annuncia: true);
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.contiene(comando, [
      'menù',
      'indietro',
      'torna indietro',
    ])) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      return true;
    }

    if (ComandiVocali.contiene(comando, [
      'leggi report',
      'lettura report',
      'leggi',
      'ascolta report',
    ])) {
      await _leggiReport();

      return true;
    }

    if (ComandiVocali.contiene(comando, [
      'aggiorna',
      'carica',
      'carica report',
      'aggiorna report',
    ])) {
      await _caricaReport();

      return true;
    }

    if (ComandiVocali.contiene(comando, [
      'giorno successivo',
      'domani',
      'più uno',
    ])) {
      await _cambiaGiorno(1);

      return true;
    }

    if (ComandiVocali.contiene(comando, [
      'giorno precedente',
      'ieri',
      'meno uno',
    ])) {
      await _cambiaGiorno(-1);

      return true;
    }

    final dataRiconosciuta = ComandiVocali.dataCompleta(
      comando,
      riferimento: _dataSelezionata,
    );

    if (dataRiconosciuta != null) {
      await _selezionaDataVocale(comando);

      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final dataVisualizzata =
        '${_dataSelezionata.day}/'
        '${_dataSelezionata.month}/'
        '${_dataSelezionata.year}';

    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Report giornaliero. '
              'In alto a sinistra giorno successivo. '
              'In alto a destra giorno precedente. '
              'Al centro Menù e controllo del microfono. '
              'In basso a sinistra data selezionata. '
              'In basso a destra lettura del report.',

          domandaVocale:
              'Puoi pronunciare una data completa, '
              'per esempio sedici agosto duemilaventisei. '
              'Puoi anche dire: leggi report, aggiorna, '
              'giorno successivo, giorno precedente oppure menù.',

          altoSinistra: ZoneAction(
            etichetta: 'Giorno\nsuccessivo',
            onTocco: () => TtsService.leggi('Giorno successivo.'),
            onAttiva: () => _cambiaGiorno(1),
          ),

          altoDestra: ZoneAction(
            etichetta: 'Giorno\nprecedente',
            onTocco: () => TtsService.leggi('Giorno precedente.'),
            onAttiva: () => _cambiaGiorno(-1),
          ),

          centro: ZoneAction(
            etichetta: 'Menù',
            onTocco: () => TtsService.leggi(
              'Torna al menù principale. '
              'Il pulsante rotondo al centro '
              'attiva o disattiva il microfono.',
            ),
            onAttiva: () {
              Navigator.of(context).pop();
            },
          ),

          bassoSinistra: ZoneAction(
            etichetta: 'Data\n$dataVisualizzata',
            onTocco: () => TtsService.leggi(
              'Data selezionata: '
              '${_dataLeggibile(_dataSelezionata)}.',
            ),
            onAttiva: () => _caricaReport(),
          ),

          bassoDestra: ZoneAction(
            etichetta: _caricamento
                ? 'Caricamento\nin corso'
                : 'Lettura\nreport',
            onTocco: () => TtsService.leggi(
              _report == null
                  ? 'Carica il report selezionato.'
                  : 'Leggi il report selezionato.',
            ),
            onAttiva: _leggiReport,
          ),

          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
