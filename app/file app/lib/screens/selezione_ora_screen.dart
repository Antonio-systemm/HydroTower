import 'package:flutter/material.dart';
import '../models/sensor_snapshot.dart';
import '../widgets/zone_nav.dart';
import '../services/tts_service.dart';
import 'lettura_dati_screen.dart';

class SelezioneOraScreen extends StatefulWidget {
  final DateTime dataBase;
  final List<dynamic> datiStorico;

  const SelezioneOraScreen({
    super.key,
    required this.dataBase,
    required this.datiStorico,
  });

  @override
  State<SelezioneOraScreen> createState() => _SelezioneOraScreenState();
}

class _SelezioneOraScreenState extends State<SelezioneOraScreen> {
  late int _ora;

  @override
  void initState() {
    super.initState();
    _ora = widget.dataBase.hour;
  }

  DateTime get _dataScelta => DateTime(
    widget.dataBase.year,
    widget.dataBase.month,
    widget.dataBase.day,
    _ora,
  );

  String get _ts =>
      '${widget.dataBase.year}-'
      '${widget.dataBase.month.toString().padLeft(2, '0')}-'
      '${widget.dataBase.day.toString().padLeft(2, '0')} '
      '${_ora.toString().padLeft(2, '0')}:00';

  Map<String, dynamic>? _trovaRiga() {
    for (final raw in widget.datiStorico) {
      if (raw is Map && raw['timestamp'] == _ts) {
        return Map<String, dynamic>.from(raw);
      }
    }
    return null;
  }

  String _testoDati() {
    final riga = _trovaRiga();
    final data =
        '${widget.dataBase.day}/${widget.dataBase.month}/${widget.dataBase.year}';
    if (riga == null || riga['temperatura'] == null) {
      return 'Nessun dato disponibile per il $data, ore $_ora. '
          'Il sistema era probabilmente spento o non raggiungibile.';
    }
    return 'Dati del $data, ore $_ora. '
        '${SensorSnapshot.fromJson(riga).letturaCompleta()}';
  }

  void _leggiDati() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LetturaDatiScreen(testo: _testoDati())),
    );
  }

  void _conferma() => Navigator.of(context).pop(_dataScelta);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura:
              'Selezione ora. In alto a sinistra aumenta di un’ora. '
              'In alto a destra diminuisce di un’ora. '
              'Al centro conferma. In basso a sinistra leggi i dati. '
              'In basso a destra annulla.',
          altoSinistra: ZoneAction(
            etichetta: '+1 ora',
            onTocco: _aumenta,
            onAttiva: _aumenta,
          ),
          altoDestra: ZoneAction(
            etichetta: '-1 ora',
            onTocco: _diminuisci,
            onAttiva: _diminuisci,
          ),
          centro: ZoneAction(
            etichetta: 'Conferma\nore $_ora',
            onTocco: () => TtsService.leggi(
              'Ora selezionata: $_ora. Tocca due volte per confermare.',
            ),
            onAttiva: _conferma,
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Leggi dati',
            onTocco: _leggiDati,
            onAttiva: _leggiDati,
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Annulla',
            onTocco: () => TtsService.leggi(
              'Tocca due volte per annullare e tornare indietro',
            ),
            onAttiva: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  void _aumenta() {
    setState(() => _ora = (_ora + 1) % 24);
    TtsService.leggi('Ore $_ora');
  }

  void _diminuisci() {
    setState(() => _ora = (_ora - 1 + 24) % 24);
    TtsService.leggi('Ore $_ora');
  }
}
