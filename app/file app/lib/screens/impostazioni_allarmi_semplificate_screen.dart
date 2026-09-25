import 'package:flutter/material.dart';
import '../services/impostazioni_controller.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniAllarmiSemplificateScreen extends StatefulWidget {
  const ImpostazioniAllarmiSemplificateScreen({super.key});
  @override
  State<ImpostazioniAllarmiSemplificateScreen> createState() => _State();
}

class _State extends State<ImpostazioniAllarmiSemplificateScreen> {
  final c = ImpostazioniController();
  int i = 0;
  static const nomi = [
    'Temperatura massima',
    'P H minimo',
    'P H massimo',
    'T D S massimo',
    'Livello acqua minimo',
    'Umidità aria minima',
    'Umidità terreno minima',
  ];
  @override
  void initState() {
    super.initState();
    c.addListener(up);
    c.carica();
  }

  void up() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(up);
    c.dispose();
    super.dispose();
  }

  double get v => [
    c.tempMax,
    c.phMin,
    c.phMax,
    c.tdsMax,
    c.acquaMin,
    c.umiditaAriaMin,
    c.umiditaTerrenoMin,
  ][i];
  double get passo => i == 3 ? 50 : ((i == 1 || i == 2) ? 0.1 : 1);
  void cambia(int d) {
    final x = (v + passo * d).clamp(0, i == 3 ? 5000 : 100).toDouble();
    switch (i) {
      case 0:
        c.aggiorna(tempMax: x);
      case 1:
        c.aggiorna(phMin: x);
      case 2:
        c.aggiorna(phMax: x);
      case 3:
        c.aggiorna(tdsMax: x);
      case 4:
        c.aggiorna(acquaMin: x);
      case 5:
        c.aggiorna(umiditaAriaMin: x);
      case 6:
        c.aggiorna(umiditaTerrenoMin: x);
    }
    TtsService.leggi('${nomi[i]} $x');
  }

  Future<void> salva() async {
    final ok = await c.salva();
    await TtsService.leggi(
      ok
          ? 'Soglie salvate sul Raspberry Pi'
          : 'Soglie locali. ${c.ultimoErrore}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (c.caricamento)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura: 'Soglie di allarme.',
          altoSinistra: ZoneAction(
            etichetta: 'Diminuisci\n${nomi[i]}',
            onTocco: () => cambia(-1),
            onAttiva: () => cambia(-1),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Aumenta\n${nomi[i]}',
            onTocco: () => cambia(1),
            onAttiva: () => cambia(1),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => TtsService.leggi('Torna'),
            onAttiva: () => Navigator.pop(context),
          ),
          bassoSinistra: ZoneAction(
            etichetta:
                '${v.toStringAsFixed(i == 1 || i == 2 ? 1 : 0)}\nSoglia successiva',
            onTocco: () => TtsService.leggi('${nomi[i]} $v'),
            onAttiva: () {
              setState(() => i = (i + 1) % nomi.length);
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Salva\nmodifiche',
            onTocco: () => TtsService.leggi('Salva'),
            onAttiva: salva,
          ),
        ),
      ),
    );
  }
}
