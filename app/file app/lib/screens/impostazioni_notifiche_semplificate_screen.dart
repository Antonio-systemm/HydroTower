import 'package:flutter/material.dart';
import '../services/impostazioni_controller.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniNotificheSemplificateScreen extends StatefulWidget {
  const ImpostazioniNotificheSemplificateScreen({super.key});
  @override
  State<ImpostazioniNotificheSemplificateScreen> createState() => _State();
}

class _State extends State<ImpostazioniNotificheSemplificateScreen> {
  final c = ImpostazioniController();
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

  Future<void> salva() async {
    final ok = await c.salva();
    await TtsService.leggi(
      ok
          ? 'Notifiche salvate sul Raspberry Pi'
          : 'Notifiche locali. ${c.ultimoErrore}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (c.caricamento)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    void toggle() {
      c.aggiorna(notificheAttive: !c.notificheAttive);
      TtsService.leggi(
        c.notificheAttive ? 'Notifiche attive' : 'Notifiche disattivate',
      );
    }

    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura: 'Impostazioni notifiche.',
          altoSinistra: ZoneAction(
            etichetta: c.notificheAttive
                ? 'Disattiva\nnotifiche'
                : 'Attiva\nnotifiche',
            onTocco: toggle,
            onAttiva: toggle,
          ),
          altoDestra: ZoneAction(
            etichetta: 'Stato\n${c.notificheAttive ? 'Attive' : 'Disattivate'}',
            onTocco: () =>
                TtsService.leggi(c.notificheAttive ? 'Attive' : 'Disattivate'),
            onAttiva: () =>
                TtsService.leggi(c.notificheAttive ? 'Attive' : 'Disattivate'),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => TtsService.leggi('Torna'),
            onAttiva: () => Navigator.pop(context),
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Ripeti\nstato',
            onTocco: () =>
                TtsService.leggi(c.notificheAttive ? 'Attive' : 'Disattivate'),
            onAttiva: () =>
                TtsService.leggi(c.notificheAttive ? 'Attive' : 'Disattivate'),
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
