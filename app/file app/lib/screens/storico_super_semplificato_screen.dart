import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'lettura_dati_screen.dart';

class StoricoSuperSemplificatoScreen extends StatefulWidget {
  const StoricoSuperSemplificatoScreen({super.key});

  @override
  State<StoricoSuperSemplificatoScreen> createState() {
    return _StoricoSuperSemplificatoScreenState();
  }
}

class _StoricoSuperSemplificatoScreenState
    extends State<StoricoSuperSemplificatoScreen> {
  List<dynamic> _righe = <dynamic>[];
  DateTime _data = DateTime.now();

  bool _caricamento = false;
  bool _raggiungibile = true;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  String _timestampSelezionato() {
    final String mese = _data.month.toString().padLeft(2, '0');
    final String giorno = _data.day.toString().padLeft(2, '0');
    final String ora = _data.hour.toString().padLeft(2, '0');

    return '${_data.year}-$mese-$giorno $ora:00';
  }

  Future<void> _carica() async {
    if (_caricamento) {
      return;
    }

    if (mounted) {
      setState(() {
        _caricamento = true;
      });
    }

    try {
      final List<dynamic> nuoveRighe = await ApiService.storico();

      if (!mounted) {
        return;
      }

      setState(() {
        _righe = nuoveRighe;
        _raggiungibile = nuoveRighe.isNotEmpty;
        _caricamento = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _raggiungibile = false;
        _caricamento = false;
      });
    }
  }

  Map<String, dynamic>? _trovaRilevamento() {
    final String timestamp = _timestampSelezionato();

    for (final dynamic elemento in _righe) {
      if (elemento is! Map) {
        continue;
      }

      final Map<String, dynamic> rilevamento = Map<String, dynamic>.from(
        elemento,
      );

      final String timestampRiga = rilevamento['timestamp']?.toString() ?? '';

      // Riconosce sia "2026-09-12 14:00"
      // sia "2026-09-12 14:00:00".
      if (timestampRiga.startsWith(timestamp)) {
        return rilevamento;
      }
    }

    return null;
  }

  Future<void> _leggi() async {
    final Map<String, dynamic>? rilevamento = _trovaRilevamento();

    final String testo;

    if (rilevamento == null || rilevamento['temperatura'] == null) {
      testo =
          'Nessun dato disponibile per il '
          '${_data.day} ${_data.month} ${_data.year}, '
          'alle ore ${_data.hour}.';
    } else {
      final SensorSnapshot snapshot = SensorSnapshot.fromJson(rilevamento);

      testo =
          'Dati del ${_data.day} ${_data.month} ${_data.year}, '
          'ore ${_data.hour}. '
          '${snapshot.letturaCompleta()}';
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => LetturaDatiScreen(testo: testo)),
    );
  }

  Future<void> _annunciaData() {
    return TtsService.leggi('Data ${_data.day} ${_data.month} ${_data.year}');
  }

  Future<void> _annunciaOra() {
    return TtsService.leggi('Ore ${_data.hour}');
  }

  Future<void> _annunciaAggiornamento() async {
    await _carica();

    if (!_raggiungibile) {
      await TtsService.leggi(
        'Storico non disponibile. '
        'Controlla la connessione al Raspberry Pi.',
      );
      return;
    }

    await TtsService.leggi(
      'Storico aggiornato. '
      'Sono disponibili ${_righe.length} rilevazioni.',
    );
  }

  Future<bool> _gestisciComando(BuildContext context, String comando) async {
    if (ComandiVocali.contiene(comando, <String>['menù', 'menu', 'indietro'])) {
      if (mounted) {
        Navigator.of(context).pop();
      }

      return true;
    }

    if (ComandiVocali.contiene(comando, <String>['aggiorna'])) {
      await _annunciaAggiornamento();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'leggi',
      'valori',
      'acqua',
      'pompa',
      'irrigazione',
    ])) {
      await _leggi();
      return true;
    }

    final DateTime? nuovaData = ComandiVocali.dataCompleta(
      comando,
      riferimento: _data,
    );

    if (nuovaData != null) {
      final int nuovaOra = ComandiVocali.ora(comando) ?? _data.hour;

      if (!mounted) {
        return true;
      }

      setState(() {
        _data = DateTime(
          nuovaData.year,
          nuovaData.month,
          nuovaData.day,
          nuovaOra,
        );
      });

      await TtsService.leggi(
        'Data selezionata '
        '${_data.day} ${_data.month} ${_data.year}, '
        'ore ${_data.hour}',
      );

      return true;
    }

    final int? nuovaOra = ComandiVocali.ora(comando);

    if (nuovaOra != null) {
      if (!mounted) {
        return true;
      }

      setState(() {
        _data = DateTime(_data.year, _data.month, _data.day, nuovaOra);
      });

      await _annunciaOra();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final String statoConnessione = _caricamento
        ? 'Caricamento storico.'
        : _raggiungibile
        ? 'Storico disponibile.'
        : 'Storico non disponibile.';

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            FiveZoneVoiceNav(
              annuncioApertura:
                  'Storico dati, acqua e irrigazione. '
                  'In alto a sinistra trovi la data. '
                  'In alto a destra trovi l’ora. '
                  'In basso a sinistra puoi leggere i valori. '
                  'In basso a destra puoi aggiornare lo storico.',
              domandaVocale:
                  'Pronuncia una data e un’ora, '
                  'oppure di leggi, aggiorna o menù.',
              altoSinistra: ZoneAction(
                etichetta: 'Data\n${_data.day}/${_data.month}',
                onTocco: () {
                  unawaited(_annunciaData());
                },
                onAttiva: () {
                  unawaited(TtsService.leggi('Pronuncia la data completa'));
                },
              ),
              altoDestra: ZoneAction(
                etichetta: 'Ora\n${_data.hour}',
                onTocco: () {
                  unawaited(_annunciaOra());
                },
                onAttiva: () {
                  unawaited(TtsService.leggi('Pronuncia la data e l’ora'));
                },
              ),
              centro: ZoneAction(
                etichetta: 'Menù',
                onTocco: () {
                  unawaited(TtsService.leggi('Torna al menù principale'));
                },
                onAttiva: () {
                  Navigator.of(context).pop();
                },
              ),
              bassoSinistra: ZoneAction(
                etichetta: 'Leggi\nvalori',
                onTocco: () {
                  unawaited(_leggi());
                },
                onAttiva: () {
                  unawaited(_leggi());
                },
              ),
              bassoDestra: ZoneAction(
                etichetta: 'Aggiorna',
                onTocco: () {
                  unawaited(
                    TtsService.leggi(
                      'Tocca due volte per aggiornare lo storico',
                    ),
                  );
                },
                onAttiva: () {
                  unawaited(_annunciaAggiornamento());
                },
              ),
              onComando: (String comando) {
                return _gestisciComando(context, comando);
              },
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: Semantics(
                  liveRegion: true,
                  label: statoConnessione,
                  child: AnimatedOpacity(
                    opacity: _caricamento || !_raggiungibile ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _raggiungibile
                            ? Colors.blueGrey.shade800
                            : Colors.red.shade900,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_caricamento)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              Icons.cloud_off,
                              size: 18,
                              color: Colors.white,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              statoConnessione,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
