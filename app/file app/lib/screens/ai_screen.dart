import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import '../theme.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});

  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  Map<String, dynamic>? _sensori;
  File? _foto;
  bool _analisiInCorso = false;
  bool _analisiRaspberryInCorso = false;
  Map<String, dynamic>? _risultato;
  String? _errore;

  @override
  void initState() {
    super.initState();
    _caricaSensori();
  }

  Future<void> _caricaSensori() async {
    final dati = await ApiService.sensoriAttuali();
    if (!mounted) return;

    setState(() {
      _sensori = dati;
    });
  }

  Future<void> _scegliFoto(ImageSource sorgente) async {
    final picker = ImagePicker();
    final scattata = await picker.pickImage(
      source: sorgente,
      maxWidth: 1280,
      imageQuality: 85,
    );

    if (scattata == null || !mounted) return;

    setState(() {
      _foto = File(scattata.path);
      _risultato = null;
      _errore = null;
    });
  }

  Future<void> _analizza() async {
    if (_analisiInCorso || _analisiRaspberryInCorso) return;

    if (_foto == null) {
      setState(() {
        _errore =
            'Scatta o seleziona una fotografia prima di avviare l’analisi.';
      });
      return;
    }

    setState(() {
      _analisiInCorso = true;
      _errore = null;
      _risultato = null;
    });

    try {
      // Usa la routine multipart del backend. Questa salva il risultato
      // sia in analisi_ai sia nella tabella report.
      final risposta = await ApiService.avviaRoutineTelefono(_foto!.path);

      if (!mounted) return;

      if (risposta['ok'] == true) {
        final analisiRaw = risposta['analisi'] ?? risposta['report'];

        if (analisiRaw is! Map) {
          setState(() {
            _errore =
                'Il server ha completato la richiesta, ma il risultato non è valido.';
          });
          return;
        }

        setState(() {
          _risultato = _normalizzaRisultato(
            Map<String, dynamic>.from(analisiRaw),
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analisi completata e report salvato.')),
        );
      } else {
        setState(() {
          _errore = _messaggioErrore(risposta);
        });
      }
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = 'Errore durante l’analisi: $errore';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analisiInCorso = false;
        });
      }
    }
  }

  Future<void> _analizzaConRaspberry() async {
    if (_analisiInCorso || _analisiRaspberryInCorso) return;

    setState(() {
      _analisiRaspberryInCorso = true;
      _errore = null;
      _risultato = null;
    });

    try {
      final risposta = await ApiService.analizzaConFotocameraRaspberry();

      if (!mounted) return;

      if (risposta['ok'] == true) {
        final analisiRaw = risposta['analisi'] ?? risposta['report'];

        if (analisiRaw is! Map) {
          setState(() {
            _errore =
                'Il server ha completato la richiesta, ma il risultato non è valido.';
          });
          return;
        }

        setState(() {
          _risultato = _normalizzaRisultato(
            Map<String, dynamic>.from(analisiRaw),
          );
        });

        await _caricaSensori();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Foto acquisita dal Raspberry Pi e report salvato nel database.',
            ),
          ),
        );
      } else {
        setState(() {
          _errore = _messaggioErrore(risposta);
        });
      }
    } catch (errore) {
      if (!mounted) return;
      setState(() {
        _errore = 'Errore durante l’analisi Raspberry: $errore';
      });
    } finally {
      if (mounted) {
        setState(() {
          _analisiRaspberryInCorso = false;
        });
      }
    }
  }

  String _messaggioErrore(Map<String, dynamic> risposta) {
    final statusCode = risposta['statusCode'] is num
        ? (risposta['statusCode'] as num).toInt()
        : null;
    final originale = risposta['error']?.toString() ?? '';
    final testo = originale.toLowerCase();

    if (statusCode == 429 ||
        testo.contains('quota giornaliera') ||
        testo.contains('quota exceeded') ||
        testo.contains('resource_exhausted')) {
      return 'La quota Gemini del modello è esaurita. Attendi il ripristino '
          'oppure seleziona un altro modello.';
    }

    if (statusCode == 503 ||
        testo.contains('503') ||
        testo.contains('unavailable') ||
        testo.contains('high demand')) {
      return 'Gemini è temporaneamente sovraccarico. Riprova tra poco.';
    }

    if (statusCode == 504 || testo.contains('timeout')) {
      return 'L’analisi ha superato il tempo massimo. Controlla comunque la '
          'sezione Report, perché il Raspberry potrebbe averla completata.';
    }

    return originale.isNotEmpty ? originale : 'Analisi non riuscita.';
  }

  Map<String, dynamic> _normalizzaRisultato(Map<String, dynamic> originale) {
    final risultato = Map<String, dynamic>.from(originale);

    risultato['punteggio'] = _interoSicuro(
      risultato['punteggio'],
      minimo: 0,
      massimo: 10,
    );
    risultato['azioni'] = _listaTesto(risultato['azioni']);

    final azioniUrgenti = risultato['azioni_urgenti'];
    risultato['azioni_urgenti'] = azioniUrgenti is List
        ? azioniUrgenti.length.clamp(0, 3)
        : _interoSicuro(azioniUrgenti, minimo: 0, massimo: 3);

    // Accetta sia i nomi nuovi del report_routine.py sia quelli vecchi.
    risultato['osservazioni_foto'] = _testoSicuro(
      risultato['osservazioni_foto'] ?? risultato['visivo'],
    );
    risultato['analisi_sensori'] = _testoSicuro(
      risultato['analisi_sensori'] ?? risultato['sensori_analisi'],
    );

    for (final chiave in <String>['stato', 'sommario', 'condizioni_ottimali']) {
      risultato[chiave] = _testoSicuro(risultato[chiave]);
    }

    return risultato;
  }

  int _interoSicuro(
    dynamic valore, {
    required int minimo,
    required int massimo,
  }) {
    int numero;

    if (valore is int) {
      numero = valore;
    } else if (valore is num) {
      numero = valore.toInt();
    } else if (valore is String) {
      numero = int.tryParse(valore.trim()) ?? minimo;
    } else if (valore is List) {
      numero = valore.length;
    } else {
      numero = minimo;
    }

    return numero.clamp(minimo, massimo);
  }

  List<String> _listaTesto(dynamic valore) {
    if (valore is List) {
      return valore
          .map(_testoSicuro)
          .where((testo) => testo.trim().isNotEmpty)
          .toList();
    }

    final testo = _testoSicuro(valore).trim();
    return testo.isEmpty ? <String>[] : <String>[testo];
  }

  String _testoSicuro(dynamic valore) {
    if (valore == null) return '';
    if (valore is String) return valore;

    if (valore is List) {
      return valore
          .map(_testoSicuro)
          .where((elemento) => elemento.isNotEmpty)
          .join('; ');
    }

    if (valore is Map) {
      return valore.entries
          .map((elemento) => '${elemento.key}: ${_testoSicuro(elemento.value)}')
          .join('; ');
    }

    return valore.toString();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Dati sensori attuali', style: sectionTitleStyle()),
        const SizedBox(height: 10),
        _grigliaSensori(),
        const SizedBox(height: 20),
        Text('Foto della pianta', style: sectionTitleStyle()),
        const SizedBox(height: 10),
        _zonaFoto(),
        const SizedBox(height: 16),
        if (_errore != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: HydroColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: HydroColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _errore!,
              style: const TextStyle(color: HydroColors.danger, fontSize: 12),
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_analisiInCorso || _analisiRaspberryInCorso)
                ? null
                : _analizza,
            style: ElevatedButton.styleFrom(
              backgroundColor: HydroColors.accent2,
              foregroundColor: HydroColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _analisiInCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: HydroColors.accent,
                    ),
                  )
                : const Icon(Icons.psychology),
            label: Text(
              _analisiInCorso ? 'Analisi in corso...' : 'Analizza la pianta',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: (_analisiInCorso || _analisiRaspberryInCorso)
                ? null
                : _analizzaConRaspberry,
            icon: _analisiRaspberryInCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam_outlined),
            label: Text(
              _analisiRaspberryInCorso
                  ? 'Fotocamera Raspberry in uso...'
                  : 'Analizza con fotocamera Raspberry',
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_risultato != null) _riquadroRisultato(_risultato!),
      ],
    );
  }

  Widget _grigliaSensori() {
    final voci = <(String, dynamic, String, IconData)>[
      ('Temp', _sensori?['temperatura'], '°C', Icons.thermostat),
      (
        'Umidità',
        _sensori?['umidita_aria'] ?? _sensori?['umidita'],
        '%',
        Icons.water_drop_outlined,
      ),
      ('Terreno', _sensori?['umidita_terreno'], '%', Icons.grass),
      ('Luce', _sensori?['luce'], 'lux', Icons.wb_sunny_outlined),
      (
        'TDS',
        _sensori?['tds'] ?? _sensori?['tds_ppm'],
        'ppm',
        Icons.science_outlined,
      ),
      ('pH', _sensori?['ph'], '', Icons.biotech_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.4,
      children: voci.map((voce) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: HydroColors.bg2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: HydroColors.border),
          ),
          child: Row(
            children: <Widget>[
              Icon(voce.$4, size: 16, color: HydroColors.text2),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      voce.$1,
                      style: const TextStyle(
                        fontSize: 10,
                        color: HydroColors.text2,
                      ),
                    ),
                    Text(
                      voce.$2 == null
                          ? '–'
                          : '${voce.$2}${voce.$3.isEmpty ? '' : ' ${voce.$3}'}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: HydroColors.text,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _zonaFoto() {
    if (_foto != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: <Widget>[
            Image.file(
              _foto!,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                icon: const Icon(Icons.close, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: HydroColors.danger.withValues(alpha: 0.85),
                ),
                onPressed: () {
                  setState(() {
                    _foto = null;
                    _risultato = null;
                    _errore = null;
                  });
                },
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _scegliFoto(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scatta foto'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _scegliFoto(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galleria'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _riquadroRisultato(Map<String, dynamic> risultato) {
    final punteggio = _interoSicuro(
      risultato['punteggio'],
      minimo: 0,
      massimo: 10,
    );

    Color coloreScore = HydroColors.accent;
    if (punteggio < 5) {
      coloreScore = HydroColors.danger;
    } else if (punteggio < 8) {
      coloreScore = HydroColors.warn;
    }

    final azioni = _listaTesto(risultato['azioni']);
    final azioniUrgenti = risultato['azioni_urgenti'] is List
        ? (risultato['azioni_urgenti'] as List).length.clamp(0, 3)
        : _interoSicuro(risultato['azioni_urgenti'], minimo: 0, massimo: 3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HydroColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HydroColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: coloreScore, width: 3),
                ),
                child: Text(
                  '$punteggio/10',
                  style: TextStyle(
                    color: coloreScore,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _testoSicuro(risultato['stato']),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      _testoSicuro(risultato['sommario']),
                      style: const TextStyle(
                        color: HydroColors.text2,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28, color: HydroColors.border),
          _sezioneTesto(
            'Osservazioni dalla foto',
            _testoSicuro(risultato['osservazioni_foto']),
          ),
          const SizedBox(height: 14),
          _sezioneTesto(
            'Analisi sensori',
            _testoSicuro(risultato['analisi_sensori']),
          ),
          if (_testoSicuro(risultato['condizioni_ottimali']).isNotEmpty) ...[
            const SizedBox(height: 14),
            _sezioneTesto(
              'Condizioni ottimali',
              _testoSicuro(risultato['condizioni_ottimali']),
            ),
          ],
          const SizedBox(height: 14),
          Text('Azioni consigliate', style: metricLabelStyle()),
          const SizedBox(height: 8),
          if (azioni.isEmpty)
            const Text(
              'Nessuna azione indicata.',
              style: TextStyle(color: HydroColors.text2, fontSize: 13),
            ),
          ...List<Widget>.generate(azioni.length, (indice) {
            final urgente = indice < azioniUrgenti;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    urgente ? Icons.priority_high : Icons.arrow_right,
                    size: 16,
                    color: urgente ? HydroColors.warn : HydroColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      azioni[indice],
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sezioneTesto(String titolo, String testo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(titolo, style: metricLabelStyle()),
        const SizedBox(height: 4),
        Text(
          testo.isEmpty ? 'Non disponibile' : testo,
          style: const TextStyle(
            fontSize: 13,
            height: 1.5,
            color: HydroColors.text,
          ),
        ),
      ],
    );
  }
}
