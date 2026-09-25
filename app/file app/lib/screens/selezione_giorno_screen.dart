import 'package:flutter/material.dart';
import '../widgets/zone_nav.dart';
import '../services/tts_service.dart';

/// alto-sx Giorno · alto-dx Mese · centro Conferma · basso-sx Anno · basso-dx Cancella
class SelezioneGiornoScreen extends StatefulWidget {
  final DateTime dataIniziale;
  const SelezioneGiornoScreen({super.key, required this.dataIniziale});

  @override
  State<SelezioneGiornoScreen> createState() => _SelezioneGiornoScreenState();
}

class _SelezioneGiornoScreenState extends State<SelezioneGiornoScreen> {
  late int _giorno, _mese, _anno;

  @override
  void initState() {
    super.initState();
    _giorno = widget.dataIniziale.day;
    _mese = widget.dataIniziale.month;
    _anno = widget.dataIniziale.year;
  }

  int _giorniNelMese(int mese, int anno) => DateTime(anno, mese + 1, 0).day;

  void _confermaScelta() {
    final giornoValido = _giorno.clamp(1, _giorniNelMese(_mese, _anno));
    final nuovaData = DateTime(
      _anno,
      _mese,
      giornoValido,
      widget.dataIniziale.hour,
    );
    Navigator.of(context).pop(nuovaData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneNav(
          annuncioApertura:
              'Selezione giorno. In alto a sinistra giorno. In alto a destra mese. '
              'Al centro conferma. In basso a sinistra anno. In basso a destra cancella.',
          altoSinistra: ZoneAction(
            etichetta: 'Giorno',
            onTocco: () {
              setState(
                () => _giorno = (_giorno % _giorniNelMese(_mese, _anno)) + 1,
              );
              TtsService.leggi('Giorno $_giorno');
            },
            onAttiva: () {
              setState(
                () => _giorno = (_giorno % _giorniNelMese(_mese, _anno)) + 1,
              );
              TtsService.leggi('Giorno $_giorno');
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Mese',
            onTocco: () {
              setState(() => _mese = (_mese % 12) + 1);
              TtsService.leggi('Mese $_mese');
            },
            onAttiva: () {
              setState(() => _mese = (_mese % 12) + 1);
              TtsService.leggi('Mese $_mese');
            },
          ),
          centro: ZoneAction(
            etichetta: 'Conferma',
            onTocco: () => TtsService.leggi(
              'Data selezionata: $_giorno $_mese $_anno. Tocca due volte per confermare.',
            ),
            onAttiva: _confermaScelta,
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Anno',
            onTocco: () {
              final annoAttuale = DateTime.now().year;
              setState(
                () => _anno = _anno == annoAttuale
                    ? annoAttuale - 1
                    : annoAttuale,
              );
              TtsService.leggi('Anno $_anno');
            },
            onAttiva: () {
              final annoAttuale = DateTime.now().year;
              setState(
                () => _anno = _anno == annoAttuale
                    ? annoAttuale - 1
                    : annoAttuale,
              );
              TtsService.leggi('Anno $_anno');
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Cancella',
            onTocco: () => TtsService.leggi(
              'Tocca due volte per annullare e tornare indietro',
            ),
            onAttiva: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
