import 'package:flutter/material.dart';
import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';
import 'lettura_dati_screen.dart';
import 'selezione_giorno_screen.dart';
import 'selezione_ora_screen.dart';

class StoricoSemplificatoScreen extends StatefulWidget {
  const StoricoSemplificatoScreen({super.key});
  @override
  State<StoricoSemplificatoScreen> createState() => _State();
}

class _State extends State<StoricoSemplificatoScreen> {
  List<Map<String, dynamic>> dati = [];
  DateTime data = DateTime.now();
  bool loading = true;
  @override
  void initState() {
    super.initState();
    carica(false);
  }

  Future<void> carica([bool annuncia = true]) async {
    final r = await ApiService.storico();
    if (!mounted) return;
    setState(() {
      dati = r
          .whereType<Map>()
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      loading = false;
    });
    if (annuncia)
      await TtsService.leggi(
        'Storico aggiornato. Sono disponibili ${dati.length} rilevazioni.',
      );
  }

  String ts() =>
      '${data.year}-${data.month.toString().padLeft(2, '0')}-${data.day.toString().padLeft(2, '0')} ${data.hour.toString().padLeft(2, '0')}:00';
  Map<String, dynamic>? get riga {
    for (final r in dati) {
      if (r['timestamp'] == ts()) return r;
    }
    return null;
  }

  void leggi() {
    final r = riga;
    final testo = r == null
        ? 'Nessun dato disponibile per l’ora selezionata.'
        : 'Dati del ${data.day}/${data.month}/${data.year}, ore ${data.hour}. ${SensorSnapshot.fromJson(r).letturaCompleta()}';
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LetturaDatiScreen(testo: testo)),
    );
  }

  @override
  Widget build(BuildContext c) => Scaffold(
    body: SafeArea(
      child: FiveZoneNav(
        annuncioApertura: 'Storico dati e irrigazione.',
        altoSinistra: ZoneAction(
          etichetta: 'Giorno',
          onTocco: () => TtsService.leggi('Giorno ${data.day}'),
          onAttiva: () async {
            final n = await Navigator.push<DateTime>(
              c,
              MaterialPageRoute(
                builder: (_) => SelezioneGiornoScreen(dataIniziale: data),
              ),
            );
            if (n != null)
              setState(
                () => data = DateTime(n.year, n.month, n.day, data.hour),
              );
          },
        ),
        altoDestra: ZoneAction(
          etichetta: 'Ora',
          onTocco: () => TtsService.leggi('Ore ${data.hour}'),
          onAttiva: () async {
            final n = await Navigator.push<DateTime>(
              c,
              MaterialPageRoute(
                builder: (_) =>
                    SelezioneOraScreen(dataBase: data, datiStorico: dati),
              ),
            );
            if (n != null) setState(() => data = n);
          },
        ),
        centro: ZoneAction(
          etichetta: 'Menù',
          onTocco: () => TtsService.leggi('Torna al menù'),
          onAttiva: () => Navigator.pop(c),
        ),
        bassoSinistra: ZoneAction(
          etichetta: 'Leggi valori',
          onTocco: leggi,
          onAttiva: leggi,
        ),
        bassoDestra: ZoneAction(
          etichetta: 'Aggiorna',
          onTocco: () => carica(),
          onAttiva: () => carica(),
        ),
      ),
    ),
  );
}
