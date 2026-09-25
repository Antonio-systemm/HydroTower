import 'dart:async';

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/comandi_vocali.dart';
import '../services/modalita_app_service.dart';
import '../services/tts_service.dart';
import '../widgets/five_zone_voice_nav.dart';
import '../widgets/zone_nav.dart';
import 'impostazioni_accessibilita_super_semplificate_screen.dart';
import 'impostazioni_allarmi_super_semplificate_screen.dart';
import 'impostazioni_campionamento_super_semplificate_screen.dart';
import 'impostazioni_notifiche_super_semplificate_screen.dart';

class ImpostazioniSuperSemplificateScreen extends StatefulWidget {
  const ImpostazioniSuperSemplificateScreen({super.key});

  @override
  State<ImpostazioniSuperSemplificateScreen> createState() =>
      _ImpostazioniSuperSemplificateScreenState();
}

class _ImpostazioniSuperSemplificateScreenState
    extends State<ImpostazioniSuperSemplificateScreen> {
  static const List<String> _categorie = <String>[
    'Soglie di allarme',
    'Campionamento',
    'Notifiche',
    'Accessibilità',
  ];

  int _indiceCategoria = 0;

  String get _categoriaCorrente => _categorie[_indiceCategoria];

  void _leggi(String testo) {
    unawaited(TtsService.leggi(testo));
  }

  void _categoriaPrecedente() {
    setState(() {
      _indiceCategoria =
          (_indiceCategoria - 1 + _categorie.length) % _categorie.length;
    });

    _leggi('Categoria selezionata: $_categoriaCorrente.');
  }

  void _categoriaSuccessiva() {
    setState(() {
      _indiceCategoria = (_indiceCategoria + 1) % _categorie.length;
    });

    _leggi('Categoria selezionata: $_categoriaCorrente.');
  }

  Widget _paginaCategoriaSelezionata() {
    switch (_indiceCategoria) {
      case 0:
        return const ImpostazioniAllarmiSuperSemplificateScreen();
      case 1:
        return const ImpostazioniCampionamentoSuperSemplificateScreen();
      case 2:
        return const ImpostazioniNotificheSuperSemplificateScreen();
      case 3:
        return const ImpostazioniAccessibilitaSuperSemplificateScreen();
    }

    return const SizedBox.shrink();
  }

  Future<void> _apriCategoriaSelezionata() async {
    await TtsService.leggi('Apro $_categoriaCorrente.');

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => _paginaCategoriaSelezionata()),
    );
  }

  Future<void> _cambiaModalita(ModalitaInterfaccia nuovaModalita) async {
    await TtsService.ferma();
    await ModalitaAppService.imposta(nuovaModalita);

    if (!mounted) {
      return;
    }

    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);

    unawaited(TtsService.leggi('${nuovaModalita.etichetta} attivata.'));
  }

  void _tornaAlMenu() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<bool> _gestisciComando(String comando) async {
    if (ComandiVocali.contiene(comando, <String>[
      'menù',
      'menu',
      'indietro',
      'torna indietro',
      'torna al menù',
      'torna al menu',
    ])) {
      _tornaAlMenu();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'categoria precedente',
      'precedente',
    ])) {
      _categoriaPrecedente();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'categoria successiva',
      'successiva',
      'avanti',
    ])) {
      _categoriaSuccessiva();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'soglie',
      'soglie di allarme',
      'allarmi',
      'temperatura massima',
      'p h massimo',
      'p h minimo',
      't d s massimo',
    ])) {
      setState(() {
        _indiceCategoria = 0;
      });
      await _apriCategoriaSelezionata();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'campionamento',
      'intervallo',
      'intervallo sensori',
      'conservazione dati',
    ])) {
      setState(() {
        _indiceCategoria = 1;
      });
      await _apriCategoriaSelezionata();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'notifiche',
      'attiva notifiche',
      'disattiva notifiche',
    ])) {
      setState(() {
        _indiceCategoria = 2;
      });
      await _apriCategoriaSelezionata();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'accessibilità',
      'accessibilita',
      'modalità',
      'modalita',
    ])) {
      setState(() {
        _indiceCategoria = 3;
      });
      await _apriCategoriaSelezionata();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia super semplificata',
      'modalità super semplificata',
      'modalita super semplificata',
      'super semplificata',
      'super',
    ])) {
      await _cambiaModalita(ModalitaInterfaccia.superSemplificata);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia normale',
      'modalità normale',
      'modalita normale',
    ])) {
      await _cambiaModalita(ModalitaInterfaccia.normale);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'interfaccia semplificata',
      'modalità semplificata',
      'modalita semplificata',
      'semplificata',
    ])) {
      await _cambiaModalita(ModalitaInterfaccia.semplificata);
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'apri',
      'accedi',
      'conferma',
      'seleziona',
    ])) {
      await _apriCategoriaSelezionata();
      return true;
    }

    if (ComandiVocali.contiene(comando, <String>[
      'aiuto',
      'comandi',
      'cosa posso dire',
      'ripeti',
    ])) {
      await TtsService.leggi(
        'Puoi dire: Soglie, Campionamento, Notifiche, Accessibilità, '
        'Categoria precedente, Categoria successiva, Apri, '
        'Interfaccia normale, Interfaccia semplificata, '
        'Interfaccia super semplificata oppure Menù.',
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
              'Impostazioni. In alto a sinistra Categoria precedente. '
              'In alto a destra Categoria successiva. '
              'Al centro è disponibile il microfono. '
              'In basso a sinistra Accedi alla categoria. '
              'In basso a destra ascolta la categoria selezionata.',
          domandaVocale:
              'Puoi dire: Soglie, Campionamento, Notifiche, Accessibilità, '
              'Categoria precedente, Categoria successiva, Apri, '
              'Interfaccia normale, Interfaccia semplificata, '
              'Interfaccia super semplificata, Aiuto oppure Menù.',
          altoSinistra: ZoneAction(
            etichetta: 'Categoria\nprecedente',
            onTocco: () {
              _leggi('Categoria precedente. Tocca due volte per selezionarla.');
            },
            onAttiva: _categoriaPrecedente,
          ),
          altoDestra: ZoneAction(
            etichetta: 'Categoria\nsuccessiva',
            onTocco: () {
              _leggi('Categoria successiva. Tocca due volte per selezionarla.');
            },
            onAttiva: _categoriaSuccessiva,
          ),
          centro: ZoneAction(
            etichetta: 'Menù',
            onTocco: () {
              _leggi(
                'Microfono. Tocca per parlare. '
                'Tieni premuto per tornare al menù.',
              );
            },
            onAttiva: _tornaAlMenu,
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
              unawaited(_apriCategoriaSelezionata());
            },
          ),
          bassoDestra: ZoneAction(
            etichetta:
                'Categoria\n${_indiceCategoria + 1} di ${_categorie.length}',
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
