import 'dart:async';
import 'package:flutter/material.dart';
import '../models/sensor_snapshot.dart';
import '../widgets/zone_nav.dart';
import '../services/tts_service.dart';
import '../services/api_service.dart';
import 'lettura_dati_screen.dart';

class OggiSemplificatoScreen extends StatefulWidget {
  const OggiSemplificatoScreen({super.key});

  @override
  State<OggiSemplificatoScreen> createState() => _OggiSemplificatoScreenState();
}

class _OggiSemplificatoScreenState extends State<OggiSemplificatoScreen> {
  SensorSnapshot? _dati;
  Timer? _timer;
  bool _caricamento = true;
  bool _raggiungibile = true;
  int _iAmbiente = 0;
  int _iUmidita = 0;
  int _iChimica = 0;

  @override
  void initState() {
    super.initState();
    _carica(annunciaErrore: false);
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _carica(annunciaErrore: false),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    TtsService.ferma();
    super.dispose();
  }

  Future<void> _carica({bool annunciaErrore = true}) async {
    final json = await ApiService.sensoriAttuali();
    if (!mounted) return;
    setState(() {
      _caricamento = false;
      _raggiungibile = json != null;
      if (json != null) _dati = SensorSnapshot.fromJson(json);
    });
    if (json == null && annunciaErrore) {
      await TtsService.leggi(
        'Raspberry Pi non raggiungibile. Controlla la connessione.',
      );
    }
  }

  String _v(double? value, String unita, {int decimali = 1}) => value == null
      ? 'dato non disponibile'
      : '${value.toStringAsFixed(decimali)} $unita';

  void _leggiAmbiente() {
    final valori = [
      'Temperatura: ${_v(_dati?.temperatura, 'gradi')}',
      'Luce: ${_v(_dati?.luce, 'lux')}',
    ];
    TtsService.leggi(valori[_iAmbiente++ % valori.length]);
  }

  void _leggiUmidita() {
    final valori = [
      'Umidità aria: ${_v(_dati?.umiditaAria, 'percento')}',
      'Umidità terreno: ${_v(_dati?.umiditaTerreno, 'percento')}',
    ];
    TtsService.leggi(valori[_iUmidita++ % valori.length]);
  }

  void _leggiChimica() {
    final valori = [
      'T D S: ${_v(_dati?.tds, 'p p m', decimali: 0)}',
      'P H: ${_v(_dati?.ph, '')}',
    ];
    TtsService.leggi(valori[_iChimica++ % valori.length]);
  }

  void _leggiAcqua() =>
      TtsService.leggi('Livello acqua: ${_v(_dati?.livelloAcqua, 'percento')}');

  void _leggiTutto() {
    final testo =
        _dati?.letturaCompleta() ??
        'Nessun dato disponibile. Il Raspberry Pi potrebbe non essere raggiungibile.';
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LetturaDatiScreen(testo: testo)));
  }

  @override
  Widget build(BuildContext context) {
    final stato = _caricamento
        ? 'Caricamento dati.'
        : (_raggiungibile
              ? 'Dati aggiornati.'
              : 'Raspberry Pi non raggiungibile.');

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              liveRegion: true,
              label: stato,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                color: _raggiungibile
                    ? Colors.green.shade900
                    : Colors.red.shade900,
                child: Text(stato, textAlign: TextAlign.center),
              ),
            ),
            Expanded(
              child: FiveZoneNav(
                annuncioApertura:
                    'Dati di oggi. In alto a sinistra temperatura e luce. '
                    'In alto a destra umidità. Al centro torna al menù. '
                    'In basso a sinistra T D S e P H. In basso a destra livello acqua.',
                altoSinistra: ZoneAction(
                  etichetta: 'Temperatura\ne luce',
                  onTocco: _leggiAmbiente,
                  onAttiva: _leggiAmbiente,
                ),
                altoDestra: ZoneAction(
                  etichetta: 'Umidità\naria e terreno',
                  onTocco: _leggiUmidita,
                  onAttiva: _leggiUmidita,
                ),
                centro: ZoneAction(
                  etichetta: 'Menù',
                  onTocco: () => TtsService.leggi(
                    'Torna al menù principale. Tocco prolungato per leggere tutti i valori.',
                  ),
                  onAttiva: () => Navigator.of(context).pop(),
                ),
                bassoSinistra: ZoneAction(
                  etichetta: 'T D S\ne P H',
                  onTocco: _leggiChimica,
                  onAttiva: _leggiChimica,
                ),
                bassoDestra: ZoneAction(
                  etichetta: 'Livello\nacqua',
                  onTocco: _leggiAcqua,
                  onAttiva: _leggiAcqua,
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _carica(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Aggiorna'),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _leggiTutto,
                    icon: const Icon(Icons.record_voice_over),
                    label: const Text('Leggi tutto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
