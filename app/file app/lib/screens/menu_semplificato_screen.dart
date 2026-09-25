import 'package:flutter/material.dart';

import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';
import 'analisi_semplificata_screen.dart';
import 'impostazioni_semplificate_screen.dart';
import 'oggi_semplificato_screen.dart';
import 'report_semplificato_screen.dart';
import 'storico_semplificato_screen.dart';

class MenuSemplificatoScreen extends StatelessWidget {
  const MenuSemplificatoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura:
              'Menù principale. In alto a sinistra Oggi. '
              'In alto a destra Analisi. Al centro Impostazioni. '
              'In basso a sinistra Report. In basso a destra Storico.',
          altoSinistra: ZoneAction(
            etichetta: 'Oggi',
            onTocco: () => TtsService.leggi('Oggi. Dati attuali dei sensori.'),
            onAttiva: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OggiSemplificatoScreen()),
            ),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Analisi',
            onTocco: () => TtsService.leggi(
              'Analisi con intelligenza artificiale della pianta.',
            ),
            onAttiva: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AnalisiSemplificataScreen(),
              ),
            ),
          ),
          centro: ZoneAction(
            etichetta: 'Impostazioni',
            onTocco: () => TtsService.leggi('Impostazioni accessibili.'),
            onAttiva: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ImpostazioniSemplificateScreen(),
              ),
            ),
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Report',
            onTocco: () => TtsService.leggi(
              'Report giornalieri con analisi e azioni consigliate.',
            ),
            onAttiva: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ReportSemplificatoScreen(),
              ),
            ),
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Storico',
            onTocco: () => TtsService.leggi('Storico dati.'),
            onAttiva: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StoricoSemplificatoScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
