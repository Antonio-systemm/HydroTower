import 'dart:async';

import 'package:flutter/material.dart';

import '../services/comandi_vocali.dart';
import '../services/route_observer_service.dart';
import '../services/tts_service.dart';
import '../services/vibration_service.dart';
import '../services/voice_command_controller.dart';
import '../theme.dart';
import 'zone_nav.dart';

class FiveZoneVoiceNav extends StatefulWidget {
  final ZoneAction? altoSinistra;
  final ZoneAction? altoDestra;
  final ZoneAction centro;
  final ZoneAction? bassoSinistra;
  final ZoneAction? bassoDestra;
  final String annuncioApertura;
  final String domandaVocale;
  final Future<bool> Function(String comando) onComando;

  const FiveZoneVoiceNav({
    super.key,
    this.altoSinistra,
    this.altoDestra,
    required this.centro,
    this.bassoSinistra,
    this.bassoDestra,
    required this.annuncioApertura,
    required this.domandaVocale,
    required this.onComando,
  });

  @override
  State<FiveZoneVoiceNav> createState() => _FiveZoneVoiceNavState();
}

class _FiveZoneVoiceNavState extends State<FiveZoneVoiceNav> with RouteAware {
  final VoiceCommandController _voice = VoiceCommandController();

  ModalRoute<void>? _route;
  bool _disponibile = false;
  bool _ascolto = false;
  bool _inizializzazioneCompletata = false;
  bool _annuncioInCorso = false;
  bool _chiuso = false;
  String _stato = 'Preparazione del microfono…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_inizializza());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final ModalRoute<void>? nuovaRoute = ModalRoute.of(context);
    if (nuovaRoute == null || nuovaRoute == _route) {
      return;
    }

    if (_route != null) {
      routeObserver.unsubscribe(this);
    }

    _route = nuovaRoute;
    routeObserver.subscribe(this, nuovaRoute);
  }

  Future<void> _inizializza() async {
    final bool disponibile = await _voice.inizializza();
    if (!mounted || _chiuso) {
      return;
    }

    setState(() {
      _disponibile = disponibile;
      _stato = disponibile
          ? 'Microfono pronto. Tocca e attendi il segnale.'
          : 'Microfono non disponibile.';
    });

    _inizializzazioneCompletata = true;
    await _annunciaSchermata();
  }

  Future<void> _annunciaSchermata({bool rientro = false}) async {
    if (!mounted ||
        _chiuso ||
        !_inizializzazioneCompletata ||
        _ascolto ||
        _annuncioInCorso) {
      return;
    }

    _annuncioInCorso = true;

    try {
      await TtsService.ferma();
      if (!mounted || _chiuso || _ascolto) {
        return;
      }

      final String introduzione = rientro
          ? 'Sei tornato in questa schermata. '
          : '';

      await TtsService.leggi(
        '$introduzione'
        '${widget.annuncioApertura} '
        '${widget.domandaVocale} '
        'Tocca il microfono e parla quando compare Sto ascoltando. '
        'Tienilo premuto per ${widget.centro.etichetta}.',
      );
    } finally {
      _annuncioInCorso = false;
    }
  }

  @override
  void didPopNext() {
    if (!mounted || _chiuso || !_inizializzazioneCompletata) {
      return;
    }

    unawaited(_annunciaSchermata(rientro: true));
  }

  void _vibraAlContatto() {
    unawaited(VibrationService.tocco());
  }

  void _vibraPressioneProlungata() {
    unawaited(VibrationService.pressioneProlungata());
  }

  Future<void> _toccaMicrofono() async {
    if (_ascolto) {
      await _voice.annullaAscolto();
      if (!mounted || _chiuso) {
        return;
      }

      setState(() {
        _ascolto = false;
        _stato = 'Ascolto interrotto.';
      });
      return;
    }

    if (!_disponibile) {
      unawaited(VibrationService.errore());
      await TtsService.leggi(
        'Il microfono non è disponibile. '
        'Controlla il permesso nelle impostazioni Android.',
      );
      return;
    }

    await TtsService.ferma();
    if (!mounted || _chiuso) {
      return;
    }

    setState(() {
      _ascolto = true;
      _stato = 'Sto ascoltando. Parla ora.';
    });

    final risultato = await _voice.ascolta();
    if (!mounted || _chiuso) {
      return;
    }

    final String testoOriginale = risultato.testo?.trim() ?? '';
    final String testoNormalizzato = ComandiVocali.normalizza(testoOriginale);

    debugPrint('TESTO RICONOSCIUTO: $testoOriginale');
    debugPrint('TESTO NORMALIZZATO: $testoNormalizzato');

    setState(() {
      _ascolto = false;
      _stato = risultato.riuscito
          ? 'Hai detto: $testoOriginale'
          : risultato.errore ?? 'Comando non riconosciuto.';
    });

    if (!risultato.riuscito) {
      unawaited(VibrationService.errore());
      await TtsService.leggi(
        risultato.errore ??
            'Non ho riconosciuto il comando. Attendi il segnale e riprova.',
      );
      return;
    }

    final bool eseguito = await widget.onComando(testoOriginale);
    if (!mounted || _chiuso) {
      return;
    }

    if (eseguito) {
      unawaited(VibrationService.successo());
      return;
    }

    unawaited(VibrationService.errore());
    await TtsService.leggi('Comando non riconosciuto. ${widget.domandaVocale}');
  }

  Widget _cella(ZoneAction? zona) {
    if (zona == null) {
      return const Expanded(child: SizedBox.shrink());
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _vibraAlContatto(),
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

  Widget _microfonoCentrale() {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _vibraAlContatto(),
        onTap: () {
          unawaited(_toccaMicrofono());
        },
        onLongPress: () {
          _vibraPressioneProlungata();
          widget.centro.onAttiva();
        },
        child: Semantics(
          button: true,
          label: _ascolto ? 'Interrompi ascolto' : 'Avvia ascolto vocale',
          hint:
              'Tocca e parla quando compare Sto ascoltando. Tieni premuto per ${widget.centro.etichetta}.',
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _ascolto ? HydroColors.accent2 : HydroColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _ascolto ? HydroColors.accent : HydroColors.border,
                width: _ascolto ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  _ascolto ? Icons.hearing : Icons.mic,
                  size: 44,
                  color: _disponibile ? HydroColors.accent : HydroColors.text2,
                ),
                const SizedBox(height: 8),
                Text(
                  _ascolto ? 'Sto ascoltando…' : 'Microfono',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: HydroColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tieni premuto: ${widget.centro.etichetta}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: HydroColors.text2,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _stato,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: HydroColors.text2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _chiuso = true;
    routeObserver.unsubscribe(this);
    unawaited(TtsService.ferma());
    unawaited(_voice.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              _cella(widget.altoSinistra),
              _cella(widget.altoDestra),
            ],
          ),
        ),
        Expanded(child: Row(children: <Widget>[_microfonoCentrale()])),
        Expanded(
          child: Row(
            children: <Widget>[
              _cella(widget.bassoSinistra),
              _cella(widget.bassoDestra),
            ],
          ),
        ),
      ],
    );
  }
}
