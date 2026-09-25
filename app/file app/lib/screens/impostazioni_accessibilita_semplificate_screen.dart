import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/modalita_app_service.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';

class ImpostazioniAccessibilitaSemplificateScreen extends StatefulWidget {
  const ImpostazioniAccessibilitaSemplificateScreen({super.key});

  @override
  State<ImpostazioniAccessibilitaSemplificateScreen> createState() => _State();
}

class _State extends State<ImpostazioniAccessibilitaSemplificateScreen> {
  ModalitaInterfaccia _selezionata = ModalitaInterfaccia.semplificata;

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    final modalita = await AppSettings.getModalitaInterfaccia();
    if (mounted) setState(() => _selezionata = modalita);
  }

  void _sposta(int delta) {
    final valori = ModalitaInterfaccia.values;
    final indice =
        (valori.indexOf(_selezionata) + delta + valori.length) % valori.length;
    setState(() => _selezionata = valori[indice]);
    TtsService.leggi(_selezionata.etichetta);
  }

  Future<void> _salva() async {
    await TtsService.leggi(
      '${_selezionata.etichetta} selezionata. Cambio dell’interfaccia in corso.',
    );
    await ModalitaAppService.imposta(_selezionata);
  }

  Future<void> _ripristina() async {
    await AppSettings.ripristinaImpostazioni();
    await TtsService.leggi(
      'Le impostazioni locali sono state ripristinate. La modalità dell’interfaccia non è stata modificata.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura:
              'Accessibilità. In alto a sinistra modalità precedente. '
              'In alto a destra modalità successiva. Al centro torna alle impostazioni. '
              'In basso a sinistra ascolta la modalità selezionata. '
              'In basso a destra salva e cambia interfaccia.',
          altoSinistra: ZoneAction(
            etichetta: 'Modalità\nprecedente',
            onTocco: () => _sposta(-1),
            onAttiva: () => _sposta(-1),
          ),
          altoDestra: ZoneAction(
            etichetta: 'Modalità\nsuccessiva',
            onTocco: () => _sposta(1),
            onAttiva: () => _sposta(1),
          ),
          centro: ZoneAction(
            etichetta: 'Torna a\nimpostazioni',
            onTocco: () => TtsService.leggi('Torna alle impostazioni'),
            onAttiva: () => Navigator.of(context).pop(),
          ),
          bassoSinistra: ZoneAction(
            etichetta: _selezionata.etichetta,
            onTocco: () => TtsService.leggi(
              'Modalità selezionata: ${_selezionata.etichetta}',
            ),
            onAttiva: _ripristina,
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Salva e\ncambia modalità',
            onTocco: () => TtsService.leggi(
              'Tocca due volte per attivare ${_selezionata.etichetta}',
            ),
            onAttiva: _salva,
          ),
        ),
      ),
    );
  }
}
