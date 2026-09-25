import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';
import 'lettura_dati_screen.dart';

/// Report giornaliero in modalita semplificata.
///
/// Zone:
/// - alto sinistra: giorno successivo;
/// - alto destra: giorno precedente;
/// - centro: ritorno al menu;
/// - basso sinistra: selezione diretta della data;
/// - basso destra: lettura del report selezionato.
class ReportSemplificatoScreen extends StatefulWidget {
  const ReportSemplificatoScreen({super.key});

  @override
  State<ReportSemplificatoScreen> createState() =>
      _ReportSemplificatoScreenState();
}

class _ReportSemplificatoScreenState extends State<ReportSemplificatoScreen> {
  DateTime _dataSelezionata = DateTime.now();
  Map<String, Map<String, dynamic>> _reportDisponibili = {};
  Map<String, dynamic>? _reportCorrente;

  bool _caricamentoDate = true;
  bool _caricamentoReport = false;
  bool _serverRaggiungibile = true;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  @override
  void dispose() {
    TtsService.ferma();
    super.dispose();
  }

  Future<void> _inizializza() async {
    await _caricaDateDisponibili();
    if (!mounted) return;

    final oggi = _normalizzaData(DateTime.now());
    if (_reportDisponibili.containsKey(_formatoApi(oggi))) {
      _dataSelezionata = oggi;
    } else if (_reportDisponibili.isNotEmpty) {
      final date =
          _reportDisponibili.keys.map(_dataDaApi).whereType<DateTime>().toList()
            ..sort();
      _dataSelezionata = date.last;
    }

    await _caricaReport(annuncia: false);
  }

  DateTime _normalizzaData(DateTime data) =>
      DateTime(data.year, data.month, data.day);

  String _formatoApi(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';

  DateTime? _dataDaApi(String valore) {
    final data = DateTime.tryParse(valore);
    return data == null ? null : _normalizzaData(data);
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

  String _dataLeggibile(DateTime data) =>
      '${data.day} ${_nomeMese(data.month)} ${data.year}';

  bool get _haReport =>
      _reportDisponibili.containsKey(_formatoApi(_dataSelezionata));

  Future<void> _caricaDateDisponibili({bool annuncia = false}) async {
    if (mounted) {
      setState(() {
        _caricamentoDate = true;
        _errore = null;
      });
    }

    final elenco = await ApiService.reportDates();
    if (!mounted) return;

    final mappa = <String, Map<String, dynamic>>{};
    for (final elemento in elenco) {
      if (elemento is! Map) continue;
      final report = Map<String, dynamic>.from(elemento);
      final data = report['data']?.toString();
      if (data != null && data.isNotEmpty) mappa[data] = report;
    }

    setState(() {
      _reportDisponibili = mappa;
      _caricamentoDate = false;
      _serverRaggiungibile = elenco.isNotEmpty;
      if (elenco.isEmpty) {
        _errore =
            'Nessun report disponibile oppure Raspberry Pi non raggiungibile.';
      }
    });

    if (annuncia) {
      await TtsService.leggi(
        mappa.isEmpty
            ? 'Nessun report disponibile. Controlla la connessione al Raspberry Pi.'
            : 'Elenco aggiornato. Sono disponibili ${mappa.length} report giornalieri.',
      );
    }
  }

  Future<void> _caricaReport({bool annuncia = true}) async {
    final dataApi = _formatoApi(_dataSelezionata);

    if (!_reportDisponibili.containsKey(dataApi)) {
      if (mounted) {
        setState(() {
          _reportCorrente = null;
          _caricamentoReport = false;
          _errore = null;
        });
      }
      if (annuncia) {
        await TtsService.leggi(
          'Nessun report disponibile per il ${_dataLeggibile(_dataSelezionata)}.',
        );
      }
      return;
    }

    setState(() {
      _caricamentoReport = true;
      _errore = null;
    });

    final dettaglio = await ApiService.reportDettaglio(dataApi);
    if (!mounted) return;

    setState(() {
      _reportCorrente = dettaglio;
      _caricamentoReport = false;
      _serverRaggiungibile = dettaglio != null;
      if (dettaglio == null) {
        _errore = 'Impossibile caricare il report selezionato.';
      }
    });

    if (annuncia) {
      await TtsService.leggi(
        dettaglio == null
            ? 'Impossibile caricare il report. Controlla la connessione.'
            : 'Report del ${_dataLeggibile(_dataSelezionata)} caricato. Tocca lettura report per ascoltarlo.',
      );
    }
  }

  Future<void> _cambiaGiorno(int delta) async {
    final nuovaData = _normalizzaData(
      _dataSelezionata.add(Duration(days: delta)),
    );

    if (nuovaData.isAfter(_normalizzaData(DateTime.now()))) {
      await TtsService.leggi('Non puoi selezionare una data futura.');
      return;
    }

    setState(() {
      _dataSelezionata = nuovaData;
      _reportCorrente = null;
      _errore = null;
    });

    await TtsService.leggi(
      '${_dataLeggibile(_dataSelezionata)}. '
      '${_haReport ? 'Report disponibile.' : 'Nessun report disponibile.'}',
    );

    if (_haReport) await _caricaReport(annuncia: false);
  }

  Future<void> _selezionaData() async {
    final oggi = _normalizzaData(DateTime.now());
    final primaData = _reportDisponibili.keys
        .map(_dataDaApi)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (precedente, data) {
          if (precedente == null || data.isBefore(precedente)) return data;
          return precedente;
        });

    final scelta = await showDatePicker(
      context: context,
      initialDate: _dataSelezionata.isAfter(oggi) ? oggi : _dataSelezionata,
      firstDate: primaData ?? DateTime(2020, 1, 1),
      lastDate: oggi,
      helpText: 'Seleziona il giorno del report',
      cancelText: 'Annulla',
      confirmText: 'Conferma',
      fieldLabelText: 'Data del report',
      errorFormatText: 'Formato data non valido',
      errorInvalidText: 'Data non disponibile',
    );

    if (scelta == null || !mounted) {
      await TtsService.leggi('Selezione della data annullata.');
      return;
    }

    setState(() {
      _dataSelezionata = _normalizzaData(scelta);
      _reportCorrente = null;
      _errore = null;
    });

    await TtsService.leggi(
      'Data selezionata: ${_dataLeggibile(_dataSelezionata)}. '
      '${_haReport ? 'Report disponibile.' : 'Nessun report disponibile.'}',
    );

    if (_haReport) await _caricaReport(annuncia: false);
  }

  String _testoCampo(dynamic valore, {String fallback = 'non disponibile'}) {
    if (valore == null) return fallback;
    if (valore is List) {
      if (valore.isEmpty) return fallback;
      return valore.map((elemento) => elemento.toString()).join('. ');
    }
    if (valore is Map) {
      if (valore.isEmpty) return fallback;
      return valore.entries
          .map((voce) => '${voce.key}: ${voce.value}')
          .join('. ');
    }
    final testo = valore.toString().trim();
    return testo.isEmpty ? fallback : testo;
  }

  String _formattaNumero(dynamic valore, String unita) {
    if (valore == null) return 'non disponibile';
    return '${valore.toString()} $unita'.trim();
  }

  String _formattaReport(Map<String, dynamic> report) {
    final azioniRaw = report['azioni'];
    final azioni = azioniRaw is List
        ? azioniRaw.map((azione) => azione.toString()).toList()
        : <String>[];
    final urgenti = report['azioni_urgenti'] is num
        ? (report['azioni_urgenti'] as num).toInt()
        : 0;

    final buffer = StringBuffer()
      ..write('Report giornaliero del ${_dataLeggibile(_dataSelezionata)}. ')
      ..write('Punteggio: ${_testoCampo(report['punteggio'])} su 10. ')
      ..write('Stato: ${_testoCampo(report['stato'])}. ')
      ..write('Sommario: ${_testoCampo(report['sommario'])}. ')
      ..write(
        'Temperatura: ${_formattaNumero(report['temperatura'], 'gradi')}. ',
      )
      ..write(
        'Umidità aria: ${_formattaNumero(report['umidita'], 'percento')}. ',
      )
      ..write(
        'Umidità terreno: ${_formattaNumero(report['umidita_terreno'], 'percento')}. ',
      )
      ..write('Luce: ${_formattaNumero(report['luce'], 'lux')}. ')
      ..write('T D S: ${_formattaNumero(report['tds'], 'p p m')}. ')
      ..write('P H: ${_testoCampo(report['ph'])}. ')
      ..write(
        'Livello acqua: ${_formattaNumero(report['livello_acqua'], 'percento')}. ',
      )
      ..write(
        'Osservazioni dalla foto: ${_testoCampo(report['osservazioni_foto'])}. ',
      )
      ..write(
        'Condizioni ottimali: ${_testoCampo(report['condizioni_ottimali'])}. ',
      )
      ..write(
        'Analisi dei sensori: ${_testoCampo(report['analisi_sensori'])}. ',
      );

    if (azioni.isEmpty) {
      buffer.write('Nessuna azione consigliata.');
    } else {
      buffer.write('Azioni consigliate. ');
      for (var indice = 0; indice < azioni.length; indice++) {
        final urgente = indice < urgenti ? 'Urgente. ' : '';
        buffer.write('${indice + 1}. $urgente${azioni[indice]}. ');
      }
    }

    return buffer.toString();
  }

  Future<void> _leggiReport() async {
    if (_caricamentoReport || _caricamentoDate) {
      await TtsService.leggi('Caricamento in corso. Attendi.');
      return;
    }

    if (!_haReport) {
      await TtsService.leggi(
        'Nessun report disponibile per il ${_dataLeggibile(_dataSelezionata)}.',
      );
      return;
    }

    if (_reportCorrente == null) {
      await _caricaReport(annuncia: false);
      if (!mounted || _reportCorrente == null) {
        await TtsService.leggi(
          'Impossibile caricare il report. Controlla la connessione al Raspberry Pi.',
        );
        return;
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LetturaDatiScreen(testo: _formattaReport(_reportCorrente!)),
      ),
    );
  }

  Future<void> _aggiorna() async {
    await _caricaDateDisponibili(annuncia: true);
    if (!mounted) return;
    if (_haReport) await _caricaReport(annuncia: false);
  }

  @override
  Widget build(BuildContext context) {
    final data = _dataLeggibile(_dataSelezionata);
    final stato = _caricamentoDate || _caricamentoReport
        ? 'Caricamento in corso'
        : _errore ?? (_haReport ? 'Report disponibile' : 'Nessun report');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              label: '$data. $stato',
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                color: !_serverRaggiungibile
                    ? Colors.red.shade900
                    : _haReport
                    ? Colors.green.shade900
                    : const Color(0xFF161D17),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stato,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: FiveZoneNav(
                annuncioApertura:
                    'Report giornaliero. In alto a sinistra giorno successivo. '
                    'In alto a destra giorno precedente. Al centro torna al menù. '
                    'In basso a sinistra selezione della data. '
                    'In basso a destra lettura del report.',
                altoSinistra: ZoneAction(
                  etichetta: 'Giorno\npiu uno',
                  onTocco: () => _cambiaGiorno(1),
                  onAttiva: () => _cambiaGiorno(1),
                ),
                altoDestra: ZoneAction(
                  etichetta: 'Giorno\nmeno uno',
                  onTocco: () => _cambiaGiorno(-1),
                  onAttiva: () => _cambiaGiorno(-1),
                ),
                centro: ZoneAction(
                  etichetta: 'Menù',
                  onTocco: () => TtsService.leggi('Torna al menù principale'),
                  onAttiva: () => Navigator.of(context).pop(),
                ),
                bassoSinistra: ZoneAction(
                  etichetta: 'Selezione\ndata',
                  onTocco: () => TtsService.leggi(
                    'Data selezionata: $data. Tocca due volte per scegliere una data.',
                  ),
                  onAttiva: _selezionaData,
                ),
                bassoDestra: ZoneAction(
                  etichetta: _haReport ? 'Lettura\nreport' : 'Aggiorna\nreport',
                  onTocco: () => TtsService.leggi(
                    _haReport
                        ? 'Report disponibile per $data. Tocca due volte per leggerlo.'
                        : 'Nessun report per $data. Tocca due volte per aggiornare.',
                  ),
                  onAttiva: _haReport ? _leggiReport : _aggiorna,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
