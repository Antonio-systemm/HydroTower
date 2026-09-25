import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _meseVisualizzato = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  Map<String, dynamic> _dateConReport = {};
  String? _dataSelezionata;
  Map<String, dynamic>? _dettaglio;
  bool _caricamentoDate = true;
  bool _caricamentoDettaglio = false;
  String _serverUrl = '';
  String? _errore;

  @override
  void initState() {
    super.initState();
    _inizializza();
  }

  Future<void> _inizializza() async {
    await Future.wait([_caricaServerUrl(), _caricaDate()]);
  }

  Future<void> _caricaServerUrl() async {
    final url = await ApiService.getServerUrl();
    if (!mounted) return;
    setState(() => _serverUrl = url.trim());
  }

  Future<void> _caricaDate() async {
    if (mounted) {
      setState(() {
        _caricamentoDate = true;
        _errore = null;
      });
    }

    final elenco = await ApiService.reportDates();
    if (!mounted) return;

    final mappa = <String, dynamic>{};
    for (final elemento in elenco) {
      if (elemento is Map && elemento['data'] != null) {
        mappa[elemento['data'].toString()] = elemento;
      }
    }

    setState(() {
      _dateConReport = mappa;
      _caricamentoDate = false;
      if (elenco.isEmpty) {
        _errore =
            'Nessun report disponibile oppure Raspberry Pi non raggiungibile.';
      }
    });
  }

  Future<void> _aggiorna() async {
    await Future.wait([_caricaServerUrl(), _caricaDate()]);

    final data = _dataSelezionata;
    if (data != null && mounted) {
      await _selezionaGiorno(data);
    }
  }

  String _fmtData(int anno, int mese, int giorno) =>
      '$anno-${mese.toString().padLeft(2, '0')}-'
      '${giorno.toString().padLeft(2, '0')}';

  Future<void> _selezionaGiorno(String data) async {
    setState(() {
      _dataSelezionata = data;
      _caricamentoDettaglio = true;
      _dettaglio = null;
      _errore = null;
    });

    final dettaglio = await ApiService.reportDettaglio(data);
    if (!mounted) return;

    setState(() {
      _dettaglio = dettaglio;
      _caricamentoDettaglio = false;
      if (dettaglio == null) {
        _errore = 'Impossibile caricare il report del giorno selezionato.';
      }
    });
  }

  void _cambiaMese(int delta) {
    setState(() {
      _meseVisualizzato = DateTime(
        _meseVisualizzato.year,
        _meseVisualizzato.month + delta,
      );
    });
  }

  String? _urlFotoCompleto(dynamic fotoUrl) {
    final percorso = fotoUrl?.toString().trim();
    if (percorso == null || percorso.isEmpty) return null;

    final fotoUri = Uri.tryParse(percorso);
    if (fotoUri != null && fotoUri.hasScheme && fotoUri.host.isNotEmpty) {
      return percorso;
    }

    var base = _serverUrl.trim();
    if (base.isEmpty) return null;
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }

    final path = percorso.startsWith('/') ? percorso : '/$percorso';
    return '$base$path';
  }

  String _urlFotoConVersione(Map<String, dynamic> report) {
    final urlBase = _urlFotoCompleto(report['foto_url']);
    if (urlBase == null) return '';

    final versione = report['creato_il']?.toString().trim().isNotEmpty == true
        ? report['creato_il'].toString()
        : report['data']?.toString() ?? '';

    if (versione.isEmpty) return urlBase;
    final separatore = urlBase.contains('?') ? '&' : '?';
    return '$urlBase${separatore}v=${Uri.encodeQueryComponent(versione)}';
  }

  Widget _fotoReport(Map<String, dynamic> report) {
    final url = _urlFotoConVersione(report);
    if (url.isEmpty) {
      return _fotoNonDisponibile(
        'Nessuna fotografia associata a questo report',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotografia della pianta', style: metricLabelStyle()),
        const SizedBox(height: 8),
        Semantics(
          image: true,
          label: 'Fotografia della pianta associata al report selezionato',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 260,
              color: HydroColors.bg3,
              child: Image.network(
                url,
                key: ValueKey(url),
                width: double.infinity,
                height: 260,
                fit: BoxFit.cover,
                cacheWidth: 1280,
                gaplessPlayback: false,
                loadingBuilder: (context, child, progresso) {
                  if (progresso == null) return child;

                  final totale = progresso.expectedTotalBytes;
                  final caricati = progresso.cumulativeBytesLoaded;
                  return Container(
                    height: 260,
                    color: HydroColors.bg3,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: HydroColors.accent,
                          value: totale == null ? null : caricati / totale,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Caricamento fotografia...',
                          style: TextStyle(
                            color: HydroColors.text2,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                errorBuilder: (context, errore, stackTrace) {
                  debugPrint('Errore caricamento foto report: $errore');
                  debugPrint('URL fotografia: $url');
                  return _fotoNonDisponibile(
                    'Impossibile caricare la fotografia',
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _fotoNonDisponibile(String messaggio) {
    return Semantics(
      label: messaggio,
      child: Container(
        width: double.infinity,
        height: 180,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: HydroColors.bg3,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: HydroColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: 38,
              color: HydroColors.text2,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                messaggio,
                textAlign: TextAlign.center,
                style: const TextStyle(color: HydroColors.text2, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _aggiorna,
      color: HydroColors.accent,
      backgroundColor: HydroColors.bg2,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _intestazioneCalendario(),
          const SizedBox(height: 10),
          if (_caricamentoDate)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(color: HydroColors.accent),
              ),
            )
          else ...[
            _grigliaCalendario(),
            const SizedBox(height: 10),
            const Row(
              children: [
                _PallinoLegenda(),
                SizedBox(width: 6),
                Text(
                  'Giorno con report disponibile',
                  style: TextStyle(fontSize: 11, color: HydroColors.text2),
                ),
              ],
            ),
          ],
          if (_errore != null) ...[
            const SizedBox(height: 16),
            _messaggioErrore(_errore!),
          ],
          const SizedBox(height: 20),
          if (_dataSelezionata == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Seleziona un giorno evidenziato nel calendario',
                  style: TextStyle(color: HydroColors.text2),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_caricamentoDettaglio)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: CircularProgressIndicator(color: HydroColors.accent),
              ),
            )
          else if (_dettaglio != null)
            _pannelloDettaglio(_dettaglio!),
        ],
      ),
    );
  }

  Widget _messaggioErrore(String messaggio) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HydroColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: HydroColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: HydroColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              messaggio,
              style: const TextStyle(color: HydroColors.danger, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intestazioneCalendario() {
    const mesi = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () => _cambiaMese(-1),
          tooltip: 'Mese precedente',
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          '${mesi[_meseVisualizzato.month - 1]} ${_meseVisualizzato.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        IconButton(
          onPressed: () => _cambiaMese(1),
          tooltip: 'Mese successivo',
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Widget _grigliaCalendario() {
    final primoGiorno = DateTime(
      _meseVisualizzato.year,
      _meseVisualizzato.month,
      1,
    );
    final giorniNelMese = DateTime(
      _meseVisualizzato.year,
      _meseVisualizzato.month + 1,
      0,
    ).day;
    final offsetInizio = primoGiorno.weekday - 1;
    final oggi = DateTime.now();
    final oggiStringa = _fmtData(oggi.year, oggi.month, oggi.day);
    const giorniSettimana = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];

    final celle = <Widget>[
      ...giorniSettimana.map(
        (giorno) => Center(
          child: Text(
            giorno,
            style: const TextStyle(
              fontSize: 11,
              color: HydroColors.text2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      ...List.generate(offsetInizio, (_) => const SizedBox.shrink()),
      ...List.generate(giorniNelMese, (indice) {
        final giorno = indice + 1;
        final data = _fmtData(
          _meseVisualizzato.year,
          _meseVisualizzato.month,
          giorno,
        );
        final haReport = _dateConReport.containsKey(data);
        final eOggi = data == oggiStringa;
        final selezionato = data == _dataSelezionata;

        return Semantics(
          button: haReport,
          selected: selezionato,
          label: haReport
              ? '$giorno, report disponibile'
              : '$giorno, nessun report',
          child: GestureDetector(
            onTap: haReport ? () => _selezionaGiorno(data) : null,
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: selezionato
                    ? HydroColors.accent2
                    : (haReport ? HydroColors.bg2 : null),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: eOggi
                      ? HydroColors.accent
                      : (haReport ? HydroColors.border : Colors.transparent),
                  width: eOggi ? 2 : 1,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$giorno',
                style: TextStyle(
                  fontSize: 12,
                  color: selezionato
                      ? HydroColors.accent
                      : (haReport ? HydroColors.text : HydroColors.text2),
                ),
              ),
            ),
          ),
        );
      }),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: celle,
    );
  }

  Widget _pannelloDettaglio(Map<String, dynamic> report) {
    final punteggio = report['punteggio'] is num
        ? (report['punteggio'] as num).toInt()
        : int.tryParse(report['punteggio']?.toString() ?? '') ?? 0;

    var coloreScore = HydroColors.accent;
    if (punteggio < 5) {
      coloreScore = HydroColors.danger;
    } else if (punteggio < 8) {
      coloreScore = HydroColors.warn;
    }

    final azioniRaw = report['azioni'];
    final azioni = azioniRaw is List ? azioniRaw : <dynamic>[];
    final azioniUrgenti = report['azioni_urgenti'] is num
        ? (report['azioni_urgenti'] as num).toInt()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HydroColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HydroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fotoReport(report),
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: coloreScore, width: 3),
                ),
                child: Text(
                  '$punteggio/10',
                  style: TextStyle(
                    color: coloreScore,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['stato']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      report['sommario']?.toString() ?? '',
                      style: const TextStyle(
                        color: HydroColors.text2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: HydroColors.border),
          _grigliaSensori(report),
          const SizedBox(height: 16),
          _sezioneTesto(
            'Osservazioni dalla foto',
            report['osservazioni_foto']?.toString() ?? 'Non disponibili',
          ),
          const SizedBox(height: 12),
          _sezioneTesto(
            'Condizioni ottimali',
            report['condizioni_ottimali']?.toString() ?? 'Non disponibili',
          ),
          const SizedBox(height: 12),
          _sezioneTesto(
            'Analisi sensori',
            report['analisi_sensori']?.toString() ?? 'Non disponibile',
          ),
          const SizedBox(height: 12),
          Text('Azioni consigliate', style: metricLabelStyle()),
          const SizedBox(height: 8),
          if (azioni.isEmpty)
            const Text(
              'Nessuna azione consigliata',
              style: TextStyle(color: HydroColors.text2, fontSize: 13),
            )
          else
            ...List.generate(azioni.length, (indice) {
              final urgente = indice < azioniUrgenti;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      urgente ? Icons.priority_high : Icons.arrow_right,
                      size: 16,
                      color: urgente ? HydroColors.warn : HydroColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        azioni[indice].toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _grigliaSensori(Map<String, dynamic> report) {
    final valori = [
      ('Temperatura', report['temperatura'], '°C', Icons.thermostat),
      ('Umidità', report['umidita'], '%', Icons.water_drop_outlined),
      ('Terreno', report['umidita_terreno'], '%', Icons.grass),
      ('pH', report['ph'], '', Icons.science_outlined),
      ('TDS', report['tds'], 'ppm', Icons.bolt_outlined),
      ('Acqua', report['livello_acqua'], '%', Icons.waves),
      ('Luce', report['luce'], 'lux', Icons.wb_sunny_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.2,
      children: valori.map((voce) {
        final valore = voce.$2 == null ? '—' : voce.$2.toString();
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HydroColors.bg3,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HydroColors.border),
          ),
          child: Row(
            children: [
              Icon(voce.$4, size: 16, color: HydroColors.text2),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      voce.$1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: HydroColors.text2,
                      ),
                    ),
                    Text(
                      '$valore ${voce.$3}'.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _sezioneTesto(String titolo, String testo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titolo, style: metricLabelStyle()),
        const SizedBox(height: 4),
        Text(
          testo,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HydroColors.text,
          ),
        ),
      ],
    );
  }
}

class _PallinoLegenda extends StatelessWidget {
  const _PallinoLegenda();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: HydroColors.accent,
        shape: BoxShape.circle,
      ),
    );
  }
}
