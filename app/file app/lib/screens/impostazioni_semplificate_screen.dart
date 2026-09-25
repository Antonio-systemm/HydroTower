import 'dart:async';

import 'package:flutter/material.dart';

import '../services/comandi_vocali.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'impostazioni_accessibilita_semplificate_screen.dart';
import 'impostazioni_allarmi_semplificate_screen.dart';
import 'impostazioni_campionamento_semplificate_screen.dart';
import 'impostazioni_notifiche_semplificate_screen.dart';

class ImpostazioniSemplificateScreen extends StatefulWidget {
  final int categoriaIniziale;

  const ImpostazioniSemplificateScreen({super.key, this.categoriaIniziale = 0});

  @override
  State<ImpostazioniSemplificateScreen> createState() =>
      _ImpostazioniSemplificateScreenState();
}

class _ImpostazioniSemplificateScreenState
    extends State<ImpostazioniSemplificateScreen> {
  static const List<String> _nomi = <String>[
    'Soglie di allarme',
    'Campionamento',
    'Notifiche',
    'Accessibilità',
  ];

  late int _categoria;

  String get _categoriaCorrente => _nomi[_categoria];

  @override
  void initState() {
    super.initState();

    _categoria = widget.categoriaIniziale.clamp(0, _nomi.length - 1);
  }

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _sposta(int differenza) {
    setState(() {
      _categoria = (_categoria + differenza + _nomi.length) % _nomi.length;
    });

    _leggi('Categoria selezionata: $_categoriaCorrente.');
  }

  Widget _paginaCategoria(int indice) {
    switch (indice) {
      case 0:
        return const ImpostazioniAllarmiSemplificateScreen();
      case 1:
        return const ImpostazioniCampionamentoSemplificateScreen();
      case 2:
        return const ImpostazioniNotificheSemplificateScreen();
      case 3:
        return const ImpostazioniAccessibilitaSemplificateScreen();
    }

    return const SizedBox.shrink();
  }

  Future<void> _apriCategoria({int? indice}) async {
    final int categoriaDaAprire = indice ?? _categoria;

    if (categoriaDaAprire < 0 || categoriaDaAprire >= _nomi.length) {
      return;
    }

    if (_categoria != categoriaDaAprire) {
      setState(() {
        _categoria = categoriaDaAprire;
      });
    }

    await TtsService.leggi('Apro ${_nomi[categoriaDaAprire]}.');

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _paginaCategoria(categoriaDaAprire),
      ),
    );

    if (!mounted) {
      return;
    }

    await TtsService.leggi(
      'Sei tornato alle impostazioni. '
      'Categoria selezionata: $_categoriaCorrente.',
    );
  }

  void _tornaIndietro() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.comandoMenu(comando)) {
      _tornaIndietro();
      return true;
    }

    // Le categorie possono essere aperte pronunciando soltanto il nome.
    if (ComandiVocali.contiene(comando, <String>[
      'soglie',
      'soglie di allarme',
      'allarmi',
      'apri soglie',
      'apri allarmi',
      'temperatura massima',
      'ph minimo',
      'p h minimo',
      'ph massimo',
      'p h massimo',
      'tds massimo',
      't d s massimo',
    ])) {
      await _apriCategoria(indice: 0);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'campionamento',
      'apri campionamento',
      'intervallo',
      'intervallo sensori',
      'conservazione dati',
    ])) {
      await _apriCategoria(indice: 1);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'notifiche',
      'apri notifiche',
      'allarmi attivi',
      'email di notifica',
    ])) {
      await _apriCategoria(indice: 2);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'accessibilita',
      'accessibilità',
      'apri accessibilita',
      'apri accessibilità',
      'modalita interfaccia',
      'modalità interfaccia',
    ])) {
      await _apriCategoria(indice: 3);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'categoria precedente',
      'precedente',
    ])) {
      _sposta(-1);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'categoria successiva',
      'successiva',
      'avanti',
    ])) {
      _sposta(1);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'apri',
      'accedi',
      'seleziona',
      'conferma',
    ])) {
      await _apriCategoria();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'aiuto',
      'comandi',
      'cosa posso dire',
      'ripeti',
    ])) {
      await TtsService.leggi(
        'Puoi dire Soglie, Campionamento, Notifiche o Accessibilità. '
        'Puoi anche dire Categoria precedente, Categoria successiva, '
        'Apri oppure Menù.',
      );
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FiveZoneVoiceNav(
          annuncioApertura:
              'Impostazioni semplificate. '
              'In alto a sinistra categoria precedente. '
              'In alto a destra categoria successiva. '
              'Al centro è disponibile il microfono. '
              'In basso a sinistra accedi alla categoria. '
              'In basso a destra ascolta la categoria selezionata.',
          domandaVocale:
              'Puoi dire Soglie, Campionamento, Notifiche o Accessibilità. '
              'Puoi anche dire Categoria precedente, Categoria successiva, '
              'Apri, Aiuto oppure Menù.',
          altoSinistra: ZoneAction(
            etichetta: 'Categoria\nprecedente',
            onTocco: () {
              _leggi('Categoria precedente. Tocca due volte per selezionarla.');
            },
            onAttiva: () {
              _sposta(-1);
            },
          ),
          altoDestra: ZoneAction(
            etichetta: 'Categoria\nsuccessiva',
            onTocco: () {
              _leggi('Categoria successiva. Tocca due volte per selezionarla.');
            },
            onAttiva: () {
              _sposta(1);
            },
          ),
          centro: ZoneAction(
            etichetta: 'Menù',
            onTocco: () {
              _leggi(
                'Microfono. Tocca per parlare. '
                'Tieni premuto per tornare al menù.',
              );
            },
            onAttiva: _tornaIndietro,
          ),
          bassoSinistra: ZoneAction(
            etichetta: 'Accedi\n$_categoriaCorrente',
            onTocco: () {
              _leggi(
                'Categoria selezionata: $_categoriaCorrente. '
                'Tocca due volte per aprirla.',
              );
            },
            onAttiva: () {
              unawaited(_apriCategoria());
            },
          ),
          bassoDestra: ZoneAction(
            etichetta: 'Categoria\n${_categoria + 1} di ${_nomi.length}',
            onTocco: () {
              _leggi('Categoria selezionata: $_categoriaCorrente.');
            },
            onAttiva: () {
              _leggi('Categoria selezionata: $_categoriaCorrente.');
            },
          ),
          onComando: _gestisciComando,
        ),
      ),
    );
  }
}
