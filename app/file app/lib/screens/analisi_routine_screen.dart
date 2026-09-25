import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';

class AnalisiRoutineScreen extends StatefulWidget {
  const AnalisiRoutineScreen({super.key});

  @override
  State<AnalisiRoutineScreen> createState() => _AnalisiRoutineScreenState();
}

class _AnalisiRoutineScreenState extends State<AnalisiRoutineScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  bool _analisiInCorso = false;
  String? _errore;
  Map<String, dynamic>? _risultato;

  Future<void> _esegui(Future<Map<String, dynamic>> Function() azione) async {
    if (_analisiInCorso) return;

    setState(() {
      _analisiInCorso = true;
      _errore = null;
      _risultato = null;
    });

    try {
      final risultato = await azione();
      if (!mounted) return;

      if (risultato['ok'] == true) {
        setState(() {
          _risultato = _normalizzaRisposta(risultato);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analisi AI completata e report aggiornato.'),
          ),
        );
      } else {
        final messaggio =
            risultato['error']?.toString() ?? 'Errore sconosciuto';
        setState(() => _errore = messaggio);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Analisi non riuscita: $messaggio')),
        );
      }
    } catch (errore) {
      if (!mounted) return;
      setState(() => _errore = errore.toString());
    } finally {
      if (mounted) {
        setState(() => _analisiInCorso = false);
      }
    }
  }

  Future<Map<String, dynamic>> _analizzaFotoTelefono(String percorso) async {
    final file = File(percorso);
    final bytes = await file.readAsBytes();
    final fotoBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';

    final sensori = await ApiService.sensoriAttuali() ?? <String, dynamic>{};

    final sensoriInvio = <String, dynamic>{
      'temperatura': sensori['temperatura'],
      'umidita': sensori['umidita_aria'] ?? sensori['umidita'],
      'umidita_terreno': sensori['umidita_terreno'],
      'luce': sensori['luce'],
      'tds': sensori['tds'] ?? sensori['tds_ppm'],
      'tds_raw': sensori['tds_raw'],
      'ph': sensori['ph'],
      'livello_acqua': sensori['livello_acqua'],
    };

    final analisi = await ApiService.analizza(sensoriInvio, fotoBase64);

    if (analisi == null) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Il Raspberry Pi non ha restituito un risultato.',
      };
    }

    if (analisi['error'] != null) {
      return <String, dynamic>{
        'ok': false,
        'error': analisi['error'].toString(),
      };
    }

    return <String, dynamic>{
      'ok': true,
      'analisi': analisi,
      'sorgente_foto': 'telefono',
      'analisi_eliminata': false,
    };
  }

  Future<void> _usaFotocameraTelefono() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (foto == null) return;
    await _esegui(() => _analizzaFotoTelefono(foto.path));
  }

  Future<void> _usaGalleria() async {
    final foto = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
    );

    if (foto == null) return;
    await _esegui(() => _analizzaFotoTelefono(foto.path));
  }

  Future<void> _usaFotocameraRaspberry() async {
    await _esegui(ApiService.analizzaConFotocameraRaspberry);
  }

  Map<String, dynamic> _normalizzaRisposta(Map<String, dynamic> risposta) {
    final risultato = Map<String, dynamic>.from(risposta);
    final raw = risultato['analisi'] ?? risultato['report'];

    if (raw is Map) {
      final analisi = Map<String, dynamic>.from(raw);
      analisi['punteggio'] = _intero(analisi['punteggio'], 0, 10);
      analisi['azioni'] = _listaTesto(analisi['azioni']);
      analisi['azioni_urgenti'] = analisi['azioni_urgenti'] is List
          ? (analisi['azioni_urgenti'] as List).length.clamp(0, 3)
          : _intero(analisi['azioni_urgenti'], 0, 3);
      risultato['analisi'] = analisi;
    }

    return risultato;
  }

  int _intero(dynamic valore, int minimo, int massimo) {
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
      return valore.map((elemento) => elemento.toString()).toList();
    }
    if (valore == null || valore.toString().trim().isEmpty) {
      return <String>[];
    }
    return <String>[valore.toString()];
  }

  @override
  Widget build(BuildContext context) {
    final contenutoAnalisi = _risultato?['analisi'] ?? _risultato?['report'];
    final analisi = contenutoAnalisi is Map
        ? Map<String, dynamic>.from(contenutoAnalisi)
        : null;

    final azioni = _listaTesto(analisi?['azioni']);

    return Scaffold(
      appBar: AppBar(title: const Text('Analisi AI giornaliera')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Text(
            'Avvia manualmente la routine AI usando la fotocamera del '
            'Raspberry Pi oppure una foto del telefono.',
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _analisiInCorso ? null : _usaFotocameraRaspberry,
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Usa fotocamera Raspberry Pi'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _analisiInCorso ? null : _usaFotocameraTelefono,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Scatta foto con il telefono'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _analisiInCorso ? null : _usaGalleria,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Scegli foto dalla galleria'),
          ),
          if (_analisiInCorso) ...<Widget>[
            const SizedBox(height: 28),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 12),
            const Center(child: Text('Fotografia e analisi in corso…')),
          ],
          if (_errore != null) ...<Widget>[
            const SizedBox(height: 24),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errore!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
          if (analisi != null) ...<Widget>[
            const SizedBox(height: 28),
            Text('Risultato', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${analisi['stato'] ?? 'Stato non disponibile'} '
                      '• ${analisi['punteggio'] ?? '–'}/10',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    if (analisi['sommario'] != null)
                      Text(analisi['sommario'].toString()),
                    if (analisi['osservazioni_foto'] != null ||
                        analisi['visivo'] != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'Osservazioni sulla fotografia',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (analisi['osservazioni_foto'] ?? analisi['visivo'])
                            .toString(),
                      ),
                    ],
                    if (analisi['analisi_sensori'] != null ||
                        analisi['sensori_analisi'] != null) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'Analisi dei sensori',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (analisi['analisi_sensori'] ??
                                analisi['sensori_analisi'])
                            .toString(),
                      ),
                    ],
                    if (azioni.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 14),
                      Text(
                        'Azioni consigliate',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      for (final azione in azioni)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text(azione),
                        ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      'Sorgente foto: '
                      '${_risultato?['sorgente_foto'] ?? 'non disponibile'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_risultato?['analisi_eliminata'] == true)
                      Text(
                        'Analisi precedente eliminata automaticamente.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
