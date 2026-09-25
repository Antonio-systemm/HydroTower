import 'package:shared_preferences/shared_preferences.dart';

enum ModalitaInterfaccia { normale, semplificata, superSemplificata }

extension ModalitaInterfacciaTesto on ModalitaInterfaccia {
  String get etichetta {
    switch (this) {
      case ModalitaInterfaccia.normale:
        return 'Interfaccia normale';
      case ModalitaInterfaccia.semplificata:
        return 'Interfaccia semplificata';
      case ModalitaInterfaccia.superSemplificata:
        return 'Interfaccia super semplificata con comandi vocali';
    }
  }
}

class AppSettings {
  static const String _keyModalitaInterfaccia = 'modalita_interfaccia';
  static const String _keyModalitaSemplificataLegacy = 'modalita_semplificata';
  static const String _keyOnboardingCompletato = 'onboarding_completato';

  static const String _keyTempMin = 'temp_min';
  static const String _keyTempMax = 'temp_max';
  static const String _keyPhMin = 'ph_min';
  static const String _keyPhMax = 'ph_max';
  static const String _keyTdsMin = 'tds_min';
  static const String _keyTdsMax = 'tds_max';
  static const String _keyAcquaMin = 'acqua_min';
  static const String _keyUmiditaAriaMin = 'umidita_aria_min';
  static const String _keyUmiditaAriaMax = 'umidita_aria_max';
  static const String _keyUmiditaTerrenoMin = 'umidita_terreno_min';
  static const String _keyUmiditaTerrenoMax = 'umidita_terreno_max';

  static const String _keyIntervalloMinuti = 'intervallo_minuti';
  static const String _keyConservazioneGiorni = 'conservazione_giorni';
  static const String _keyNotifiche = 'notifiche_attive';
  static const String _keyNotificheReport = 'notifiche_report_attive';
  static const String _keyNotificheRipristino = 'notifiche_ripristino_attive';
  static const String _keyAggiornamentoGemini = 'aggiornamento_soglie_gemini';
  static const String _keyOrigineSoglie = 'origine_soglie';
  static const String _keySoglieAggiornateIl = 'soglie_aggiornate_il';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  static Future<ModalitaInterfaccia> getModalitaInterfaccia() async {
    final SharedPreferences prefs = await _prefs;
    final String? salvata = prefs.getString(_keyModalitaInterfaccia);

    for (final ModalitaInterfaccia modalita in ModalitaInterfaccia.values) {
      if (modalita.name == salvata) return modalita;
    }

    final bool? vecchia = prefs.getBool(_keyModalitaSemplificataLegacy);
    if (vecchia == true) return ModalitaInterfaccia.semplificata;
    return ModalitaInterfaccia.normale;
  }

  static Future<void> setModalitaInterfaccia(
    ModalitaInterfaccia modalita,
  ) async {
    final SharedPreferences prefs = await _prefs;
    await prefs.setString(_keyModalitaInterfaccia, modalita.name);
    await prefs.setBool(
      _keyModalitaSemplificataLegacy,
      modalita != ModalitaInterfaccia.normale,
    );
  }

  static Future<bool> getModalitaSemplificata() async =>
      (await getModalitaInterfaccia()) != ModalitaInterfaccia.normale;

  static Future<void> setModalitaSemplificata(bool value) async =>
      setModalitaInterfaccia(
        value ? ModalitaInterfaccia.semplificata : ModalitaInterfaccia.normale,
      );

  static Future<bool> getOnboardingCompletato() async =>
      (await _prefs).getBool(_keyOnboardingCompletato) ?? false;

  static Future<void> setOnboardingCompletato(bool value) async =>
      (await _prefs).setBool(_keyOnboardingCompletato, value);

  static Future<double> getTempMin() async =>
      (await _prefs).getDouble(_keyTempMin) ?? 18.0;

  static Future<void> setTempMin(double value) async =>
      (await _prefs).setDouble(_keyTempMin, value);

  static Future<double> getTempMax() async =>
      (await _prefs).getDouble(_keyTempMax) ?? 28.0;

  static Future<void> setTempMax(double value) async =>
      (await _prefs).setDouble(_keyTempMax, value);

  static Future<double> getPhMin() async =>
      (await _prefs).getDouble(_keyPhMin) ?? 5.5;

  static Future<void> setPhMin(double value) async =>
      (await _prefs).setDouble(_keyPhMin, value);

  static Future<double> getPhMax() async =>
      (await _prefs).getDouble(_keyPhMax) ?? 7.0;

  static Future<void> setPhMax(double value) async =>
      (await _prefs).setDouble(_keyPhMax, value);

  static Future<double> getTdsMin() async =>
      (await _prefs).getDouble(_keyTdsMin) ?? 600.0;

  static Future<void> setTdsMin(double value) async =>
      (await _prefs).setDouble(_keyTdsMin, value);

  static Future<double> getTdsMax() async =>
      (await _prefs).getDouble(_keyTdsMax) ?? 1200.0;

  static Future<void> setTdsMax(double value) async =>
      (await _prefs).setDouble(_keyTdsMax, value);

  static Future<double> getAcquaMin() async =>
      (await _prefs).getDouble(_keyAcquaMin) ?? 20.0;

  static Future<void> setAcquaMin(double value) async =>
      (await _prefs).setDouble(_keyAcquaMin, value);

  static Future<double> getUmiditaAriaMin() async =>
      (await _prefs).getDouble(_keyUmiditaAriaMin) ?? 40.0;

  static Future<void> setUmiditaAriaMin(double value) async =>
      (await _prefs).setDouble(_keyUmiditaAriaMin, value);

  static Future<double> getUmiditaAriaMax() async =>
      (await _prefs).getDouble(_keyUmiditaAriaMax) ?? 75.0;

  static Future<void> setUmiditaAriaMax(double value) async =>
      (await _prefs).setDouble(_keyUmiditaAriaMax, value);

  static Future<double> getUmiditaTerrenoMin() async =>
      (await _prefs).getDouble(_keyUmiditaTerrenoMin) ?? 35.0;

  static Future<void> setUmiditaTerrenoMin(double value) async =>
      (await _prefs).setDouble(_keyUmiditaTerrenoMin, value);

  static Future<double> getUmiditaTerrenoMax() async =>
      (await _prefs).getDouble(_keyUmiditaTerrenoMax) ?? 75.0;

  static Future<void> setUmiditaTerrenoMax(double value) async =>
      (await _prefs).setDouble(_keyUmiditaTerrenoMax, value);

  static Future<int> getIntervalloMinuti() async =>
      (await _prefs).getInt(_keyIntervalloMinuti) ?? 5;

  static Future<void> setIntervalloMinuti(int value) async =>
      (await _prefs).setInt(_keyIntervalloMinuti, value);

  static Future<int> getConservazioneGiorni() async =>
      (await _prefs).getInt(_keyConservazioneGiorni) ?? 30;

  static Future<void> setConservazioneGiorni(int value) async =>
      (await _prefs).setInt(_keyConservazioneGiorni, value);

  static Future<bool> getNotificheAttive() async =>
      (await _prefs).getBool(_keyNotifiche) ?? true;

  static Future<void> setNotificheAttive(bool value) async =>
      (await _prefs).setBool(_keyNotifiche, value);

  static Future<bool> getNotificheReportAttive() async =>
      (await _prefs).getBool(_keyNotificheReport) ?? true;

  static Future<void> setNotificheReportAttive(bool value) async =>
      (await _prefs).setBool(_keyNotificheReport, value);

  static Future<bool> getNotificheRipristinoAttive() async =>
      (await _prefs).getBool(_keyNotificheRipristino) ?? false;

  static Future<void> setNotificheRipristinoAttive(bool value) async =>
      (await _prefs).setBool(_keyNotificheRipristino, value);

  static Future<bool> getAggiornamentoSoglieGemini() async =>
      (await _prefs).getBool(_keyAggiornamentoGemini) ?? true;

  static Future<void> setAggiornamentoSoglieGemini(bool value) async =>
      (await _prefs).setBool(_keyAggiornamentoGemini, value);

  static Future<String> getOrigineSoglie() async =>
      (await _prefs).getString(_keyOrigineSoglie) ?? 'predefinite';

  static Future<void> setOrigineSoglie(String value) async =>
      (await _prefs).setString(_keyOrigineSoglie, value);

  static Future<DateTime?> getSoglieAggiornateIl() async {
    final String? value = (await _prefs).getString(_keySoglieAggiornateIl);
    return value == null ? null : DateTime.tryParse(value);
  }

  static Future<void> setSoglieAggiornateIl(DateTime value) async =>
      (await _prefs).setString(_keySoglieAggiornateIl, value.toIso8601String());

  static Future<void> ripristinaImpostazioni() async {
    final SharedPreferences prefs = await _prefs;
    for (final String key in <String>[
      _keyTempMin,
      _keyTempMax,
      _keyPhMin,
      _keyPhMax,
      _keyTdsMin,
      _keyTdsMax,
      _keyAcquaMin,
      _keyUmiditaAriaMin,
      _keyUmiditaAriaMax,
      _keyUmiditaTerrenoMin,
      _keyUmiditaTerrenoMax,
      _keyIntervalloMinuti,
      _keyConservazioneGiorni,
      _keyNotifiche,
      _keyNotificheReport,
      _keyNotificheRipristino,
      _keyAggiornamentoGemini,
      _keyOrigineSoglie,
      _keySoglieAggiornateIl,
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<void> applicaImpostazioniRemote(
    Map<String, dynamic> values,
  ) async {
    double? asDouble(dynamic value) {
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '');
    }

    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final Map<String, dynamic> soglie = values['thresholds'] is Map
        ? Map<String, dynamic>.from(values['thresholds'] as Map)
        : values;

    final double? tempMin = asDouble(
      soglie['tempMin'] ?? soglie['temperatura_min'],
    );
    final double? tempMax = asDouble(
      soglie['tempMax'] ?? soglie['temperatura_max'],
    );
    final double? phMin = asDouble(soglie['phMin'] ?? soglie['ph_min']);
    final double? phMax = asDouble(soglie['phMax'] ?? soglie['ph_max']);
    final double? tdsMin = asDouble(soglie['tdsMin'] ?? soglie['tds_min']);
    final double? tdsMax = asDouble(soglie['tdsMax'] ?? soglie['tds_max']);
    final double? waterMin = asDouble(
      soglie['waterMin'] ?? soglie['livello_acqua_min'],
    );
    final double? humidityAirMin = asDouble(
      soglie['humidityAirMin'] ?? soglie['umidita_aria_min'],
    );
    final double? humidityAirMax = asDouble(
      soglie['humidityAirMax'] ?? soglie['umidita_aria_max'],
    );
    final double? humiditySoilMin = asDouble(
      soglie['humiditySoilMin'] ?? soglie['umidita_terreno_min'],
    );
    final double? humiditySoilMax = asDouble(
      soglie['humiditySoilMax'] ?? soglie['umidita_terreno_max'],
    );

    final int? interval = asInt(values['interval']);
    final int? retention = asInt(values['retention']);

    if (tempMin != null) await setTempMin(tempMin);
    if (tempMax != null) await setTempMax(tempMax);
    if (phMin != null) await setPhMin(phMin);
    if (phMax != null) await setPhMax(phMax);
    if (tdsMin != null) await setTdsMin(tdsMin);
    if (tdsMax != null) await setTdsMax(tdsMax);
    if (waterMin != null) await setAcquaMin(waterMin);
    if (humidityAirMin != null) await setUmiditaAriaMin(humidityAirMin);
    if (humidityAirMax != null) await setUmiditaAriaMax(humidityAirMax);
    if (humiditySoilMin != null) {
      await setUmiditaTerrenoMin(humiditySoilMin);
    }
    if (humiditySoilMax != null) {
      await setUmiditaTerrenoMax(humiditySoilMax);
    }
    if (interval != null) await setIntervalloMinuti(interval);
    if (retention != null) await setConservazioneGiorni(retention);

    if (values['notifications'] is bool) {
      await setNotificheAttive(values['notifications'] as bool);
    }
    if (values['reportNotifications'] is bool) {
      await setNotificheReportAttive(values['reportNotifications'] as bool);
    }
    if (values['recoveryNotifications'] is bool) {
      await setNotificheRipristinoAttive(
        values['recoveryNotifications'] as bool,
      );
    }
    if (values['geminiAutoThresholds'] is bool) {
      await setAggiornamentoSoglieGemini(
        values['geminiAutoThresholds'] as bool,
      );
    }

    final String? origine =
        values['thresholdSource']?.toString() ??
        values['soglie_origine']?.toString();
    if (origine != null && origine.isNotEmpty) {
      await setOrigineSoglie(origine);
    }

    final DateTime? aggiornateIl = DateTime.tryParse(
      values['thresholdUpdatedAt']?.toString() ??
          values['soglie_aggiornate_il']?.toString() ??
          '',
    );
    if (aggiornateIl != null) {
      await setSoglieAggiornateIl(aggiornateIl);
    }
  }

  static Future<Map<String, dynamic>> impostazioniCondiviseJson() async {
    return <String, dynamic>{
      'tempMin': await getTempMin(),
      'tempMax': await getTempMax(),
      'phMin': await getPhMin(),
      'phMax': await getPhMax(),
      'tdsMin': await getTdsMin(),
      'tdsMax': await getTdsMax(),
      'waterMin': await getAcquaMin(),
      'humidityAirMin': await getUmiditaAriaMin(),
      'humidityAirMax': await getUmiditaAriaMax(),
      'humiditySoilMin': await getUmiditaTerrenoMin(),
      'humiditySoilMax': await getUmiditaTerrenoMax(),
      'interval': await getIntervalloMinuti(),
      'retention': await getConservazioneGiorni(),
      'notifications': await getNotificheAttive(),
      'reportNotifications': await getNotificheReportAttive(),
      'recoveryNotifications': await getNotificheRipristinoAttive(),
      'geminiAutoThresholds': await getAggiornamentoSoglieGemini(),
      'thresholdSource': await getOrigineSoglie(),
      'thresholdUpdatedAt': (await getSoglieAggiornateIl())?.toIso8601String(),
      'towerName': 'Torre #1',
    };
  }
}
