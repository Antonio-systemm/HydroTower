import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/tts_service.dart';

/// Una delle 5 zone del navigatore.
/// [onTocco] gira ad ogni tocco singolo — tipicamente legge ad alta voce
/// cosa c'è in questa zona (ed eventualmente passa al valore successivo,
/// se la zona ne contiene più di uno da leggere in sequenza).
/// [onAttiva] gira al doppio tocco — conferma/apre/naviga.
/// Stesso schema di TalkBack e VoiceOver: un tocco per ascoltare,
/// doppio tocco per confermare.
class ZoneAction {
  final String etichetta;
  final VoidCallback onTocco;
  final VoidCallback onAttiva;

  const ZoneAction({
    required this.etichetta,
    required this.onTocco,
    required this.onAttiva,
  });
}

/// Schermo diviso in 5 grandi zone toccabili: 4 angoli + centro.
/// Ogni zona non definita resta vuota (nessun tocco riconosciuto lì).
class FiveZoneNav extends StatefulWidget {
  final ZoneAction? altoSinistra;
  final ZoneAction? altoDestra;
  final ZoneAction centro;
  final ZoneAction? bassoSinistra;
  final ZoneAction? bassoDestra;

  /// Letto automaticamente non appena la schermata si apre.
  final String annuncioApertura;

  const FiveZoneNav({
    super.key,
    this.altoSinistra,
    this.altoDestra,
    required this.centro,
    this.bassoSinistra,
    this.bassoDestra,
    required this.annuncioApertura,
  });

  @override
  State<FiveZoneNav> createState() => _FiveZoneNavState();
}

class _FiveZoneNavState extends State<FiveZoneNav> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.leggi(widget.annuncioApertura);
    });
  }

  Widget _cella(ZoneAction? zona) {
    if (zona == null) {
      return const Expanded(child: SizedBox.shrink());
    }
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: zona.onTocco,
        onDoubleTap: zona.onAttiva,
        child: Semantics(
          button: true,
          label: zona.etichetta,
          hint: 'Tocca per ascoltare, tocca due volte per confermare',
          child: Container(
            margin: const EdgeInsets.all(4),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: HydroColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: HydroColors.border),
            ),
            child: Text(
              zona.etichetta,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: HydroColors.text,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [_cella(widget.altoSinistra), _cella(widget.altoDestra)],
          ),
        ),
        Expanded(child: Row(children: [_cella(widget.centro)])),
        Expanded(
          child: Row(
            children: [
              _cella(widget.bassoSinistra),
              _cella(widget.bassoDestra),
            ],
          ),
        ),
      ],
    );
  }
}
