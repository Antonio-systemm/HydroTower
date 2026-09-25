import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../services/tts_service.dart';
import '../widgets/zone_nav.dart';
import 'lettura_dati_screen.dart';

/// Analisi AI accessibile a cinque zone:
/// alto-sx dati sensori, alto-dx foto, centro menu,
/// basso-sx invia analisi, basso-dx cancella foto.
class AnalisiSemplificataScreen extends StatefulWidget {
  const AnalisiSemplificataScreen({super.key});

  @override
  State<AnalisiSemplificataScreen> createState() =>
      _AnalisiSemplificataScreenState();
}

class _AnalisiSemplificataScreenState extends State<AnalisiSemplificataScreen> {
  final ImagePicker _picker = ImagePicker();

  SensorSnapshot? _sensori;
  File? _foto;
  bool _caricamentoSensori = true;
  bool _analisiInCorso = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _caricaSensori();
  }

  @override
  void dispose() {
    TtsService.ferma();
    super.dispose();
  }

  Future<void> _caricaSensori({bool annuncia = false}) async {
    final json = await ApiService.sensoriAttuali();
    if (!mounted) return;

    setState(() {
      _caricamentoSensori = false;
      _sensori = json == null ? null : SensorSnapshot.fromJson(json);
    });

    if (annuncia) {
      await TtsService.leggi(
        _sensori == null
            ? 'Dati sensori non disponibili. Controlla la connessione al Raspberry Pi.'
            : _sensori!.letturaCompleta(),
      );
    }
  }

  void _leggiSensori() {
    if (_caricamentoSensori) {
      TtsService.leggi('Caricamento dei dati sensori in corso.');
      return;
    }
    final testo = _sensori == null
        ? 'Dati sensori non disponibili. Tocca due volte per riprovare.'
        : _sensori!.letturaCompleta();
    TtsService.leggi(testo);
  }

  Future<void> _apriSceltaFoto() async {
    if (_analisiInCorso) return;

    final sorgente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF161D17),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scatta una foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Annulla'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (sorgente == null) {
      await TtsService.leggi('Scelta della foto annullata.');
      return;
    }

    try {
      final immagine = await _picker.pickImage(
        source: sorgente,
        maxWidth: 1280,
        imageQuality: 85,
      );
      if (immagine == null || !mounted) {
        await TtsService.leggi('Nessuna foto selezionata.');
        return;
      }

      setState(() {
        _foto = File(immagine.path);
        _errore = null;
      });
      await TtsService.leggi(
        sorgente == ImageSource.camera
            ? 'Foto scattata e pronta per l’analisi.'
            : 'Foto selezionata e pronta per l’analisi.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errore = 'Impossibile acquisire la foto.');
      await TtsService.leggi(
        'Impossibile acquisire la foto. Controlla i permessi della fotocamera.',
      );
    }
  }

  Future<void> _eliminaFoto() async {
    if (_foto == null) {
      await TtsService.leggi('Non c’è nessuna foto da cancellare.');
      return;
    }
    setState(() {
      _foto = null;
      _errore = null;
    });
    await TtsService.leggi('Foto cancellata.');
  }

  Future<void> _inviaAnalisi() async {
    if (_analisiInCorso) {
      await TtsService.leggi('Analisi già in corso. Attendi.');
      return;
    }
    if (_foto == null) {
      await TtsService.leggi(
        'Prima devi scattare o selezionare una foto della pianta.',
      );
      return;
    }
    if (_sensori == null) {
      await TtsService.leggi(
        'I dati sensori non sono disponibili. Provo ad aggiornarli.',
      );
      await _caricaSensori();
      if (_sensori == null) {
        await TtsService.leggi(
          'Raspberry Pi non raggiungibile. Analisi annullata.',
        );
        return;
      }
    }

    setState(() {
      _analisiInCorso = true;
      _errore = null;
    });
    await TtsService.leggi(
      'Invio della foto e dei dati. Analisi in corso. Attendi.',
    );

    try {
      final bytes = await _foto!.readAsBytes();
      final estensione = _foto!.path.toLowerCase();
      final mime = estensione.endsWith('.png') ? 'image/png' : 'image/jpeg';
      final fotoBase64 = 'data:$mime;base64,${base64Encode(bytes)}';

      final dati = <String, dynamic>{
        'temperatura': _sensori!.temperatura,
        'umidità': _sensori!.umiditaAria,
        'umidita_terreno': _sensori!.umiditaTerreno,
        'luce': _sensori!.luce,
        'tds': _sensori!.tds,
        'ph': _sensori!.ph,
        'livello_acqua': _sensori!.livelloAcqua,
      };

      final risposta = await ApiService.analizza(dati, fotoBase64);
      if (!mounted) return;

      if (risposta == null || risposta['error'] != null) {
        final messaggio =
            risposta?['error']?.toString() ??
            'Il server non ha restituito un risultato valido.';
        setState(() => _errore = messaggio);
        await TtsService.leggi('Analisi non riuscita. $messaggio');
        return;
      }

      final testo = _formattaRisultato(risposta);
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LetturaDatiScreen(testo: testo)),
      );
      if (mounted) {
        await TtsService.leggi(
          'Sei tornato alla schermata Analisi. La foto e ancora disponibile.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errore =
            'Connessione al Raspberry Pi non riuscita oppure risposta non valida.',
      );
      await TtsService.leggi(
        'Analisi non riuscita. Controlla la connessione al Raspberry Pi.',
      );
    } finally {
      if (mounted) setState(() => _analisiInCorso = false);
    }
  }

  String _formattaRisultato(Map<String, dynamic> r) {
    final punteggio = r['punteggio']?.toString() ?? 'non disponibile';
    final stato = r['stato']?.toString() ?? 'non disponibile';
    final sommario = r['sommario']?.toString() ?? 'non disponibile';
    final visivo = r['visivo']?.toString() ?? 'non disponibile';
    final sensori = r['sensori_analisi']?.toString() ?? 'non disponibile';
    final azioniRaw = r['azioni'];
    final azioni = azioniRaw is List
        ? azioniRaw.map((a) => a.toString()).toList()
        : <String>[];
    final urgenti = r['azioni_urgenti'] is num
        ? (r['azioni_urgenti'] as num).toInt()
        : 0;

    final buffer = StringBuffer()
      ..write('Risultato dell analisi. ')
      ..write('Punteggio: $punteggio su 10. ')
      ..write('Stato: $stato. ')
      ..write('Sommario: $sommario. ')
      ..write('Osservazioni dalla foto: $visivo. ')
      ..write('Analisi dei sensori: $sensori. ');

    if (azioni.isEmpty) {
      buffer.write('Nessuna azione consigliata.');
    } else {
      buffer.write('Azioni consigliate. ');
      for (var i = 0; i < azioni.length; i++) {
        final priorita = i < urgenti ? 'Urgente. ' : '';
        buffer.write('${i + 1}. $priorita${azioni[i]}. ');
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final fotoPronta = _foto != null;
    final stato = _analisiInCorso
        ? 'Analisi in corso'
        : fotoPronta
        ? 'Foto pronta'
        : 'Nessuna foto';

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
                color: _errore != null
                    ? Colors.red.shade900
                    : fotoPronta
                    ? Colors.green.shade900
                    : const Color(0xFF161D17),
                child: Text(
                  _errore ?? stato,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (_foto != null)
              SizedBox(
                height: 100,
                width: double.infinity,
                child: Image.file(_foto!, fit: BoxFit.cover),
              ),
            Expanded(
              child: FiveZoneNav(
                annuncioApertura:
                    'Analisi con intelligenza artificiale. '
                    'In alto a sinistra dati sensori. '
                    'In alto a destra fai una foto. '
                    'Al centro torna al menù. '
                    'In basso a sinistra invia l’analisi. '
                    'In basso a destra cancella la foto.',
                altoSinistra: ZoneAction(
                  etichetta: 'Dati\nsensori',
                  onTocco: _leggiSensori,
                  onAttiva: () => _caricaSensori(annuncia: true),
                ),
                altoDestra: ZoneAction(
                  etichetta: fotoPronta ? 'Cambia\nfoto' : 'Fai una\nfoto',
                  onTocco: () => TtsService.leggi(
                    fotoPronta
                        ? 'Una foto e pronta. Tocca due volte per cambiarla.'
                        : 'Tocca due volte per scattare una foto o sceglierla dalla galleria.',
                  ),
                  onAttiva: _apriSceltaFoto,
                ),
                centro: ZoneAction(
                  etichetta: 'Menù',
                  onTocco: () => TtsService.leggi('Torna al menù principale'),
                  onAttiva: () => Navigator.of(context).pop(),
                ),
                bassoSinistra: ZoneAction(
                  etichetta: _analisiInCorso
                      ? 'Analisi\nin corso'
                      : 'Invia\nanalisi',
                  onTocco: () => TtsService.leggi(
                    _analisiInCorso
                        ? 'Analisi in corso. Attendi.'
                        : fotoPronta
                        ? 'Tocca due volte per inviare la foto e i dati.'
                        : 'Prima devi fare una foto.',
                  ),
                  onAttiva: _inviaAnalisi,
                ),
                bassoDestra: ZoneAction(
                  etichetta: 'Cancella\nfoto',
                  onTocco: () => TtsService.leggi(
                    fotoPronta
                        ? 'Tocca due volte per cancellare la foto.'
                        : 'Nessuna foto da cancellare.',
                  ),
                  onAttiva: _eliminaFoto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
