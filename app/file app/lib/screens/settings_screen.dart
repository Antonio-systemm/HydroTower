import 'dart:async';
import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/app_settings.dart';
import '../services/modalita_app_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<int> _intervalli = <int>[1, 5, 10, 30, 60];
  static const List<int> _conservazioni = <int>[7, 30, 90, 365, 0];

  static const String _chiaveNomeTorre = 'hydro_tower_name';
  static const String _chiaveEmailAttiva = 'hydro_email_notifications';
  static const String _chiaveTemaChiaro = 'hydro_light_theme';

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _nomeTorreController = TextEditingController();
  final TextEditingController _tempMinController = TextEditingController();
  final TextEditingController _tempMaxController = TextEditingController();
  final TextEditingController _phMinController = TextEditingController();
  final TextEditingController _phMaxController = TextEditingController();
  final TextEditingController _tdsMinController = TextEditingController();
  final TextEditingController _tdsMaxController = TextEditingController();
  final TextEditingController _acquaMinController = TextEditingController();
  final TextEditingController _umiditaAriaMinController =
  TextEditingController();
  final TextEditingController _umiditaAriaMaxController =
  TextEditingController();
  final TextEditingController _umiditaTerrenoMinController =
  TextEditingController();
  final TextEditingController _umiditaTerrenoMaxController =
  TextEditingController();

  ModalitaInterfaccia _modalita = ModalitaInterfaccia.normale;
  int _intervallo = 5;
  int _conservazione = 30;
  bool _notificheAttive = true;
  bool _notificheReportAttive = true;
  bool _aggiornamentoSoglieGemini = false;
  String _origineSoglie = 'manual';
  DateTime? _soglieAggiornateIl;
  bool _emailAttiva = false;
  bool _temaChiaro = false;
  bool _caricamento = true;
  bool _salvataggio = false;
  bool _serverOnline = false;
  String? _errore;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _nomeTorreController.dispose();
    _tempMinController.dispose();
    _tempMaxController.dispose();
    _phMinController.dispose();
    _phMaxController.dispose();
    _tdsMinController.dispose();
    _tdsMaxController.dispose();
    _acquaMinController.dispose();
    _umiditaAriaMinController.dispose();
    _umiditaAriaMaxController.dispose();
    _umiditaTerrenoMinController.dispose();
    _umiditaTerrenoMaxController.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() {
      _caricamento = true;
      _errore = null;
    });

    final SharedPreferences preferenze = await SharedPreferences.getInstance();
    final String url = await ApiService.getServerUrl();
    final ModalitaInterfaccia modalita =
    await AppSettings.getModalitaInterfaccia();

    double tempMin = await AppSettings.getTempMin();
    double tempMax = await AppSettings.getTempMax();
    double phMin = await AppSettings.getPhMin();
    double phMax = await AppSettings.getPhMax();
    double tdsMin = await AppSettings.getTdsMin();
    double tdsMax = await AppSettings.getTdsMax();
    double acquaMin = await AppSettings.getAcquaMin();
    double umiditaAriaMin = await AppSettings.getUmiditaAriaMin();
    double umiditaAriaMax = await AppSettings.getUmiditaAriaMax();
    double umiditaTerrenoMin = await AppSettings.getUmiditaTerrenoMin();
    double umiditaTerrenoMax = await AppSettings.getUmiditaTerrenoMax();
    int intervallo = await AppSettings.getIntervalloMinuti();
    int conservazione = await AppSettings.getConservazioneGiorni();
    bool notificheAttive = await AppSettings.getNotificheAttive();
    bool notificheReportAttive = await AppSettings.getNotificheReportAttive();
    bool aggiornamentoSoglieGemini =
    await AppSettings.getAggiornamentoSoglieGemini();
    String origineSoglie = await AppSettings.getOrigineSoglie();
    DateTime? soglieAggiornateIl = await AppSettings.getSoglieAggiornateIl();
    String nomeTorre = preferenze.getString(_chiaveNomeTorre) ?? 'Torre #1';
    bool emailAttiva = preferenze.getBool(_chiaveEmailAttiva) ?? false;
    final bool temaChiaro = preferenze.getBool(_chiaveTemaChiaro) ?? false;
    bool serverOnline = false;

    final Map<String, dynamic>? remote = await ApiService.impostazioni();
    if (remote != null) {
      serverOnline = true;
      await AppSettings.applicaImpostazioniRemote(remote);
      tempMin = _comeDouble(remote['tempMin']) ?? tempMin;
      tempMax = _comeDouble(remote['tempMax']) ?? tempMax;
      phMin = _comeDouble(remote['phMin']) ?? phMin;
      phMax = _comeDouble(remote['phMax']) ?? phMax;
      tdsMin = _comeDouble(remote['tdsMin']) ?? tdsMin;
      tdsMax = _comeDouble(remote['tdsMax']) ?? tdsMax;
      acquaMin = _comeDouble(remote['waterMin']) ?? acquaMin;
      umiditaAriaMin = _comeDouble(remote['humidityAirMin']) ?? umiditaAriaMin;
      umiditaAriaMax = _comeDouble(remote['humidityAirMax']) ?? umiditaAriaMax;
      umiditaTerrenoMin =
          _comeDouble(remote['humiditySoilMin']) ?? umiditaTerrenoMin;
      umiditaTerrenoMax =
          _comeDouble(remote['humiditySoilMax']) ?? umiditaTerrenoMax;
      intervallo = _comeInt(remote['interval']) ?? intervallo;
      conservazione = _comeInt(remote['retention']) ?? conservazione;
      notificheAttive = remote['notifications'] is bool
          ? remote['notifications'] as bool
          : notificheAttive;
      notificheReportAttive = remote['reportNotifications'] is bool
          ? remote['reportNotifications'] as bool
          : notificheReportAttive;
      aggiornamentoSoglieGemini = remote['geminiAutoThresholds'] is bool
          ? remote['geminiAutoThresholds'] as bool
          : aggiornamentoSoglieGemini;
      origineSoglie = remote['thresholdSource']?.toString() ?? origineSoglie;
      soglieAggiornateIl =
          DateTime.tryParse(remote['thresholdUpdatedAt']?.toString() ?? '') ??
              soglieAggiornateIl;
      emailAttiva = remote['emailNotifications'] is bool
          ? remote['emailNotifications'] as bool
          : emailAttiva;
      nomeTorre = remote['towerName']?.toString() ?? nomeTorre;
    }

    if (!_intervalli.contains(intervallo)) intervallo = 5;
    if (!_conservazioni.contains(conservazione)) conservazione = 30;

    if (!mounted) return;
    setState(() {
      _urlController.text = url;
      _nomeTorreController.text = nomeTorre;
      _tempMinController.text = _numero(tempMin);
      _tempMaxController.text = _numero(tempMax);
      _phMinController.text = phMin.toStringAsFixed(1);
      _phMaxController.text = phMax.toStringAsFixed(1);
      _tdsMinController.text = _numero(tdsMin);
      _tdsMaxController.text = _numero(tdsMax);
      _acquaMinController.text = _numero(acquaMin);
      _umiditaAriaMinController.text = _numero(umiditaAriaMin);
      _umiditaAriaMaxController.text = _numero(umiditaAriaMax);
      _umiditaTerrenoMinController.text = _numero(umiditaTerrenoMin);
      _umiditaTerrenoMaxController.text = _numero(umiditaTerrenoMax);
      _modalita = modalita;
      _intervallo = intervallo;
      _conservazione = conservazione;
      _notificheAttive = notificheAttive;
      _notificheReportAttive = notificheReportAttive;
      _aggiornamentoSoglieGemini = aggiornamentoSoglieGemini;
      _origineSoglie = origineSoglie;
      _soglieAggiornateIl = soglieAggiornateIl;
      _emailAttiva = emailAttiva;
      _temaChiaro = temaChiaro;
      _serverOnline = serverOnline;
      _caricamento = false;
    });
  }

  double? _comeDouble(dynamic valore) {
    if (valore is num) return valore.toDouble();
    return double.tryParse(valore?.toString() ?? '');
  }

  int? _comeInt(dynamic valore) {
    if (valore is num) return valore.toInt();
    return int.tryParse(valore?.toString() ?? '');
  }

  String _numero(double valore) => valore == valore.roundToDouble()
      ? valore.toInt().toString()
      : valore.toString();

  double? _leggiNumero(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _messaggio(String testo, {bool errore = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(testo),
        backgroundColor: errore ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _salvaUrl() async {
    String url = _urlController.text.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !<String>{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      _messaggio('Indirizzo del Raspberry Pi non valido', errore: true);
      return;
    }

    await ApiService.setServerUrl(url);
    _urlController.text = url;
    final Map<String, dynamic>? remote = await ApiService.impostazioni();
    if (!mounted) return;
    setState(() => _serverOnline = remote != null);
    _messaggio(
      remote != null
          ? 'Indirizzo salvato. Raspberry Pi collegato.'
          : 'Indirizzo salvato, ma il Raspberry Pi non risponde.',
      errore: remote == null,
    );

    final String? token = await NotificationService.token();

    if (token != null && token.trim().isNotEmpty) {
      await ApiService.registraTokenFcm(token.trim());
    }
  }

  Future<void> _salvaImpostazioni() async {
    if (_salvataggio) return;

    final double? tempMin = _leggiNumero(_tempMinController);
    final double? tempMax = _leggiNumero(_tempMaxController);
    final double? phMin = _leggiNumero(_phMinController);
    final double? phMax = _leggiNumero(_phMaxController);
    final double? tdsMin = _leggiNumero(_tdsMinController);
    final double? tdsMax = _leggiNumero(_tdsMaxController);
    final double? acquaMin = _leggiNumero(_acquaMinController);
    final double? umiditaAriaMin = _leggiNumero(_umiditaAriaMinController);
    final double? umiditaAriaMax = _leggiNumero(_umiditaAriaMaxController);
    final double? umiditaTerrenoMin = _leggiNumero(
      _umiditaTerrenoMinController,
    );
    final double? umiditaTerrenoMax = _leggiNumero(
      _umiditaTerrenoMaxController,
    );

    if (<double?>[
      tempMin,
      tempMax,
      phMin,
      phMax,
      tdsMin,
      tdsMax,
      acquaMin,
      umiditaAriaMin,
      umiditaAriaMax,
      umiditaTerrenoMin,
      umiditaTerrenoMax,
    ].any((double? valore) => valore == null)) {
      _messaggio('Controlla tutti i valori numerici', errore: true);
      return;
    }

    if (tempMin! >= tempMax!) {
      _messaggio(
        'La temperatura minima deve essere inferiore alla massima',
        errore: true,
      );
      return;
    }
    if (phMin! >= phMax!) {
      _messaggio(
        'Il pH minimo deve essere inferiore al pH massimo',
        errore: true,
      );
      return;
    }

    if (tdsMin! >= tdsMax!) {
      _messaggio(
        'Il TDS minimo deve essere inferiore al massimo',
        errore: true,
      );
      return;
    }
    if (umiditaAriaMin! >= umiditaAriaMax!) {
      _messaggio(
        'L’umidità aria minima deve essere inferiore alla massima',
        errore: true,
      );
      return;
    }
    if (umiditaTerrenoMin! >= umiditaTerrenoMax!) {
      _messaggio(
        'L’umidità terreno minima deve essere inferiore alla massima',
        errore: true,
      );
      return;
    }
    setState(() {
      _salvataggio = true;
      _errore = null;
    });

    // Qui i "!" su tempMin, tdsMin, umiditaAriaMin/Max e
    // umiditaTerrenoMin/Max sono stati rimossi perché Dart promuove
    // automaticamente queste variabili a non-null dopo i confronti
    // con "!" fatti sopra.
    await AppSettings.setTempMin(tempMin);
    await AppSettings.setTempMax(tempMax);
    await AppSettings.setPhMin(phMin);
    await AppSettings.setPhMax(phMax);
    await AppSettings.setTdsMin(tdsMin);
    await AppSettings.setTdsMax(tdsMax);
    await AppSettings.setAcquaMin(acquaMin!);
    await AppSettings.setUmiditaAriaMin(umiditaAriaMin);
    await AppSettings.setUmiditaAriaMax(umiditaAriaMax);
    await AppSettings.setUmiditaTerrenoMin(umiditaTerrenoMin);
    await AppSettings.setUmiditaTerrenoMax(umiditaTerrenoMax);
    await AppSettings.setIntervalloMinuti(_intervallo);
    await AppSettings.setConservazioneGiorni(_conservazione);
    await AppSettings.setNotificheAttive(_notificheAttive);
    await AppSettings.setNotificheReportAttive(_notificheReportAttive);
    await AppSettings.setAggiornamentoSoglieGemini(_aggiornamentoSoglieGemini);

    final SharedPreferences preferenze = await SharedPreferences.getInstance();
    final String nomeTorre = _nomeTorreController.text.trim().isEmpty
        ? 'Torre #1'
        : _nomeTorreController.text.trim();
    await preferenze.setString(_chiaveNomeTorre, nomeTorre);
    await preferenze.setBool(_chiaveEmailAttiva, _emailAttiva);
    await preferenze.setBool(_chiaveTemaChiaro, _temaChiaro);

    final Map<String, dynamic> risultato =
    await ApiService.salvaImpostazioni(<String, dynamic>{
      'tempMin': tempMin,
      'tempMax': tempMax,
      'phMin': phMin,
      'phMax': phMax,
      'tdsMin': tdsMin,
      'tdsMax': tdsMax,
      'waterMin': acquaMin,
      'humidityAirMin': umiditaAriaMin,
      'humidityAirMax': umiditaAriaMax,
      'humiditySoilMin': umiditaTerrenoMin,
      'humiditySoilMax': umiditaTerrenoMax,
      'interval': _intervallo,
      'retention': _conservazione,
      'notifications': _notificheAttive,
      'reportNotifications': _notificheReportAttive,
      'geminiAutoThresholds': _aggiornamentoSoglieGemini,
      'thresholdSource': 'manual',
      'emailNotifications': _emailAttiva,
      'towerName': nomeTorre,
      'lightTheme': _temaChiaro,
    });

    if (!mounted) return;
    final bool riuscito = risultato['ok'] == true;
    setState(() {
      _salvataggio = false;
      _serverOnline = riuscito;
      _errore = riuscito ? null : risultato['error']?.toString();
    });

    _messaggio(
      riuscito
          ? 'Impostazioni salvate sul Raspberry Pi'
          : 'Impostazioni salvate sul telefono. Raspberry Pi non raggiungibile.',
      errore: !riuscito,
    );
  }

  Future<void> _cambiaModalita(ModalitaInterfaccia? modalita) async {
    if (modalita == null || modalita == _modalita) return;
    setState(() => _modalita = modalita);
    await ModalitaAppService.imposta(modalita);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _cancellaDati() async {
    final bool? conferma = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Cancellare tutti i dati?'),
        content: const Text(
          'Questa operazione elimina i dati locali salvati dall’app. '
              'Non può essere annullata.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (conferma != true) return;
    final SharedPreferences preferenze = await SharedPreferences.getInstance();
    await preferenze.remove('hydro_data');
    _messaggio('Dati locali eliminati');
  }

  Future<void> _ripristina() async {
    await AppSettings.ripristinaImpostazioni();
    await _carica();
    _messaggio('Impostazioni locali ripristinate');
  }

  String _testoIntervallo(int minuti) {
    if (minuti == 1) return 'Ogni minuto';
    if (minuti == 60) return 'Ogni ora';
    return 'Ogni $minuti minuti';
  }

  String _testoConservazione(int giorni) {
    switch (giorni) {
      case 0:
        return 'Sempre';
      case 365:
        return '1 anno';
      default:
        return '$giorni giorni';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caricamento) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: HydroColors.accent),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: <Widget>[
            _titolo('Connessione'),
            _card(<Widget>[
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Indirizzo del Raspberry Pi',
                  hintText: 'http://192.168.1.120:5000',
                  prefixIcon: Icon(Icons.router_outlined),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(
                    _serverOnline
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                    color: _serverOnline
                        ? HydroColors.accent
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _serverOnline
                          ? 'Raspberry Pi collegato'
                          : 'Raspberry Pi non raggiungibile',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _salvaUrl,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Salva indirizzo'),
              ),
            ]),
            _titolo('Soglie di allarme'),
            _card(<Widget>[
              _rigaDoppia(
                _campoNumero(
                  controller: _tempMinController,
                  label: 'Temperatura minima',
                  unita: '°C',
                  icon: Icons.thermostat_outlined,
                ),
                _campoNumero(
                  controller: _tempMaxController,
                  label: 'Temperatura massima',
                  unita: '°C',
                  icon: Icons.thermostat_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _rigaDoppia(
                _campoNumero(
                  controller: _phMinController,
                  label: 'pH minimo',
                  icon: Icons.science_outlined,
                ),
                _campoNumero(
                  controller: _phMaxController,
                  label: 'pH massimo',
                  icon: Icons.science_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _rigaDoppia(
                _campoNumero(
                  controller: _tdsMinController,
                  label: 'TDS minimo',
                  unita: 'ppm',
                  icon: Icons.bolt_outlined,
                ),
                _campoNumero(
                  controller: _tdsMaxController,
                  label: 'TDS massimo',
                  unita: 'ppm',
                  icon: Icons.bolt_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _campoNumero(
                controller: _acquaMinController,
                label: 'Livello acqua minimo',
                unita: '%',
                icon: Icons.water_outlined,
              ),
              const SizedBox(height: 14),
              _rigaDoppia(
                _campoNumero(
                  controller: _umiditaAriaMinController,
                  label: 'Umidità aria minima',
                  unita: '%',
                  icon: Icons.water_drop_outlined,
                ),
                _campoNumero(
                  controller: _umiditaAriaMaxController,
                  label: 'Umidità aria massima',
                  unita: '%',
                  icon: Icons.water_drop_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _rigaDoppia(
                _campoNumero(
                  controller: _umiditaTerrenoMinController,
                  label: 'Umidità terreno minima',
                  unita: '%',
                  icon: Icons.grass_outlined,
                ),
                _campoNumero(
                  controller: _umiditaTerrenoMaxController,
                  label: 'Umidità terreno massima',
                  unita: '%',
                  icon: Icons.grass_outlined,
                ),
              ),
            ]),
            _titolo('Gestione soglie con AI'),
            _card(<Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Consenti a Gemini di aggiornare le soglie'),
                subtitle: const Text(
                  'Dopo un report riuscito, il Raspberry valida e applica le soglie consigliate dall’AI.',
                ),
                value: _aggiornamentoSoglieGemini,
                onChanged: (bool valore) {
                  setState(() => _aggiornamentoSoglieGemini = valore);
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(
                  _origineSoglie == 'gemini'
                      ? 'Soglie correnti: Gemini'
                      : 'Soglie correnti: utente',
                ),
                subtitle: Text(
                  _soglieAggiornateIl == null
                      ? 'Nessun aggiornamento AI registrato'
                      : 'Ultimo aggiornamento: ${_soglieAggiornateIl!.toLocal()}',
                ),
              ),
            ]),
            _titolo('Campionamento'),
            _card(<Widget>[
              DropdownButtonFormField<int>(
                initialValue: _intervallo,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Intervallo lettura sensori',
                  prefixIcon: Icon(Icons.refresh_outlined),
                ),
                items: _intervalli
                    .map(
                      (int valore) => DropdownMenuItem<int>(
                    value: valore,
                    child: Text(
                      _testoIntervallo(valore),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                    .toList(),
                onChanged: (int? valore) {
                  if (valore != null) setState(() => _intervallo = valore);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _conservazione,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Conserva storico per',
                  prefixIcon: Icon(Icons.storage_outlined),
                ),
                items: _conservazioni
                    .map(
                      (int valore) => DropdownMenuItem<int>(
                    value: valore,
                    child: Text(
                      _testoConservazione(valore),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                    .toList(),
                onChanged: (int? valore) {
                  if (valore != null) setState(() => _conservazione = valore);
                },
              ),
            ]),
            _titolo('Notifiche'),
            _card(<Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Allarmi attivi'),
                subtitle: const Text(
                  'Mostra avvisi quando i valori escono dai range',
                ),
                value: _notificheAttive,
                onChanged: (bool valore) {
                  setState(() => _notificheAttive = valore);
                },
              ),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.description_outlined),
                title: const Text('Notifiche nuovi report'),
                subtitle: const Text(
                  'Avvisa quando il report giornaliero è pronto',
                ),
                value: _notificheReportAttive,
                onChanged: (bool valore) {
                  setState(() => _notificheReportAttive = valore);
                },
              ),
              const Divider(),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.mail_outline),
                title: const Text('Email di notifica'),
                subtitle: const Text('Invia email in caso di allarme'),
                value: _emailAttiva,
                onChanged: (bool valore) {
                  setState(() => _emailAttiva = valore);
                },
              ),
            ]),
            _titolo('Aspetto'),
            _card(<Widget>[
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.light_mode_outlined),
                title: const Text('Tema chiaro'),
                subtitle: const Text(
                  'La preferenza viene salvata. Per applicarla globalmente '
                      'l’app deve collegarla al ThemeMode di MaterialApp.',
                ),
                value: _temaChiaro,
                onChanged: (bool valore) {
                  setState(() => _temaChiaro = valore);
                },
              ),
              const Divider(),
              TextField(
                controller: _nomeTorreController,
                decoration: const InputDecoration(
                  labelText: 'Nome torre',
                  prefixIcon: Icon(Icons.eco_outlined),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<ModalitaInterfaccia>(
                initialValue: _modalita,
                isExpanded: true,
                menuMaxHeight: 320,
                decoration: const InputDecoration(
                  labelText: 'Modalità dell’interfaccia',
                  prefixIcon: Icon(Icons.accessibility_new_outlined),
                ),
                items: ModalitaInterfaccia.values
                    .map(
                      (ModalitaInterfaccia modalita) =>
                      DropdownMenuItem<ModalitaInterfaccia>(
                        value: modalita,
                        child: Text(
                          modalita.etichetta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                )
                    .toList(),
                selectedItemBuilder: (BuildContext context) =>
                    ModalitaInterfaccia.values
                        .map(
                          (ModalitaInterfaccia modalita) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          modalita.etichetta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                        .toList(),
                onChanged: _cambiaModalita,
              ),
            ]),
            _titolo('Zona pericolosa'),
            _card(<Widget>[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Cancella tutti i dati',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: const Text('Elimina i dati locali salvati dall’app'),
                trailing: OutlinedButton(
                  onPressed: _cancellaDati,
                  child: const Text('Cancella'),
                ),
              ),
            ]),
            if (_errore != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _errore!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _salvataggio ? null : _salvaImpostazioni,
              icon: _salvataggio
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.save_outlined),
              label: Text(
                _salvataggio ? 'Salvataggio in corso…' : 'Salva impostazioni',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _salvataggio ? null : _ripristina,
              icon: const Icon(Icons.restore_outlined),
              label: const Text('Ripristina impostazioni locali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titolo(String testo) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(testo, style: sectionTitleStyle()),
  );

  Widget _card(List<Widget> figli) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: figli,
      ),
    ),
  );

  Widget _rigaDoppia(Widget sinistra, Widget destra) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Expanded(child: sinistra),
      const SizedBox(width: 12),
      Expanded(child: destra),
    ],
  );

  Widget _campoNumero({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? unita,
  }) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixText: unita,
    ),
  );
}