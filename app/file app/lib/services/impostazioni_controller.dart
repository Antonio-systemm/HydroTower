import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'app_settings.dart';

class ImpostazioniController extends ChangeNotifier {
  static const List<int> intervalliDisponibili = <int>[1, 5, 10, 30, 60];
  static const List<int> conservazioniDisponibili = <int>[7, 30, 90, 365, 0];

  bool caricamento = true;
  bool salvataggio = false;
  bool serverRaggiungibile = false;
  String? ultimoErrore;

  double tempMin = 18;
  double tempMax = 28;
  double phMin = 5.5;
  double phMax = 7;
  double tdsMin = 600;
  double tdsMax = 1200;
  double acquaMin = 20;
  double umiditaAriaMin = 40;
  double umiditaAriaMax = 75;
  double umiditaTerrenoMin = 35;
  double umiditaTerrenoMax = 75;
  int intervalloMinuti = 5;
  int conservazioneGiorni = 30;
  bool notificheAttive = true;
  bool notificheReportAttive = true;

  Future<void> carica() async {
    caricamento = true;
    ultimoErrore = null;
    notifyListeners();
    await _caricaLocale();
    final Map<String, dynamic>? remote = await ApiService.impostazioni();
    if (remote != null) {
      await AppSettings.applicaImpostazioniRemote(remote);
      await _caricaLocale();
      serverRaggiungibile = true;
    } else {
      serverRaggiungibile = false;
      ultimoErrore = 'Raspberry Pi non raggiungibile';
    }
    caricamento = false;
    notifyListeners();
  }

  Future<void> _caricaLocale() async {
    tempMin = await AppSettings.getTempMin();
    tempMax = await AppSettings.getTempMax();
    phMin = await AppSettings.getPhMin();
    phMax = await AppSettings.getPhMax();
    tdsMin = await AppSettings.getTdsMin();
    tdsMax = await AppSettings.getTdsMax();
    acquaMin = await AppSettings.getAcquaMin();
    umiditaAriaMin = await AppSettings.getUmiditaAriaMin();
    umiditaAriaMax = await AppSettings.getUmiditaAriaMax();
    umiditaTerrenoMin = await AppSettings.getUmiditaTerrenoMin();
    umiditaTerrenoMax = await AppSettings.getUmiditaTerrenoMax();
    intervalloMinuti = await AppSettings.getIntervalloMinuti();
    conservazioneGiorni = await AppSettings.getConservazioneGiorni();
    notificheAttive = await AppSettings.getNotificheAttive();
    notificheReportAttive = await AppSettings.getNotificheReportAttive();
  }

  Map<String, dynamic> get jsonCompleto => <String, dynamic>{
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
    'interval': intervalloMinuti,
    'retention': conservazioneGiorni,
    'notifications': notificheAttive,
    'reportNotifications': notificheReportAttive,
    'thresholdSource': 'manual',
    'towerName': 'Torre #1',
  };

  String? _valida() {
    if (tempMin >= tempMax)
      return 'La temperatura minima deve essere inferiore alla massima';
    if (phMin >= phMax) return 'Il pH minimo deve essere inferiore al massimo';
    if (tdsMin >= tdsMax)
      return 'Il TDS minimo deve essere inferiore al massimo';
    if (umiditaAriaMin >= umiditaAriaMax)
      return 'L’umidità aria minima deve essere inferiore alla massima';
    if (umiditaTerrenoMin >= umiditaTerrenoMax)
      return 'L’umidità terreno minima deve essere inferiore alla massima';
    return null;
  }

  Future<bool> salva() async {
    if (salvataggio) return false;
    ultimoErrore = _valida();
    if (ultimoErrore != null) {
      notifyListeners();
      return false;
    }
    salvataggio = true;
    notifyListeners();
    await AppSettings.applicaImpostazioniRemote(jsonCompleto);
    final Map<String, dynamic> risultato = await ApiService.salvaImpostazioni(
      jsonCompleto,
    );
    final bool ok = risultato['ok'] == true;
    serverRaggiungibile = ok;
    ultimoErrore = ok
        ? null
        : risultato['error']?.toString() ?? 'Errore sconosciuto';
    final dynamic remote = risultato['impostazioni'];
    if (ok && remote is Map) {
      await AppSettings.applicaImpostazioniRemote(
        Map<String, dynamic>.from(remote),
      );
      await _caricaLocale();
    }
    salvataggio = false;
    notifyListeners();
    return ok;
  }

  void aggiorna({
    double? tempMin,
    double? tempMax,
    double? phMin,
    double? phMax,
    double? tdsMin,
    double? tdsMax,
    double? acquaMin,
    double? umiditaAriaMin,
    double? umiditaAriaMax,
    double? umiditaTerrenoMin,
    double? umiditaTerrenoMax,
    int? intervalloMinuti,
    int? conservazioneGiorni,
    bool? notificheAttive,
    bool? notificheReportAttive,
  }) {
    this.tempMin = tempMin ?? this.tempMin;
    this.tempMax = tempMax ?? this.tempMax;
    this.phMin = phMin ?? this.phMin;
    this.phMax = phMax ?? this.phMax;
    this.tdsMin = tdsMin ?? this.tdsMin;
    this.tdsMax = tdsMax ?? this.tdsMax;
    this.acquaMin = acquaMin ?? this.acquaMin;
    this.umiditaAriaMin = umiditaAriaMin ?? this.umiditaAriaMin;
    this.umiditaAriaMax = umiditaAriaMax ?? this.umiditaAriaMax;
    this.umiditaTerrenoMin = umiditaTerrenoMin ?? this.umiditaTerrenoMin;
    this.umiditaTerrenoMax = umiditaTerrenoMax ?? this.umiditaTerrenoMax;
    this.intervalloMinuti = intervalloMinuti ?? this.intervalloMinuti;
    this.conservazioneGiorni = conservazioneGiorni ?? this.conservazioneGiorni;
    this.notificheAttive = notificheAttive ?? this.notificheAttive;
    this.notificheReportAttive =
        notificheReportAttive ?? this.notificheReportAttive;
    notifyListeners();
  }
}
