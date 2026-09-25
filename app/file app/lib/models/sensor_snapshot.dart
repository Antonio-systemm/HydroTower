class SensorSnapshot {
  const SensorSnapshot({
    this.temperatura,
    this.umiditaAria,
    this.umiditaTerreno,
    this.luce,
    this.tds,
    this.tdsRaw,
    this.ph,
    this.phRaw,
    this.phVoltage,
    this.phAdcRange,
    this.phStable,
    this.phValid,
    this.phCalibrated,
    this.acquaPresente,
    this.livelloAcqua,
    this.livelloAcquaStato,
    this.messaggioAcqua,
    this.pompaAttiva,
    this.secondiPompaOra,
    this.irrigazioniOra,
    this.motivoUltimoArresto,
    this.bloccoPompa,
    this.dailyRuntimeSeconds,
    this.startsToday,
  });

  final double? temperatura;
  final double? umiditaAria;
  final double? umiditaTerreno;
  final double? luce;
  final double? tds;
  final int? tdsRaw;

  final double? ph;
  final int? phRaw;
  final double? phVoltage;
  final int? phAdcRange;
  final bool? phStable;
  final bool? phValid;
  final bool? phCalibrated;

  final bool? acquaPresente;
  final double? livelloAcqua;
  final String? livelloAcquaStato;
  final String? messaggioAcqua;

  final bool? pompaAttiva;
  final double? secondiPompaOra;
  final int? irrigazioniOra;
  final String? motivoUltimoArresto;
  final String? bloccoPompa;
  final double? dailyRuntimeSeconds;
  final int? startsToday;

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    return SensorSnapshot(
      temperatura: _toDouble(json['temperatura']),
      umiditaAria: _toDouble(json['umidita_aria'] ?? json['umidita']),
      umiditaTerreno: _toDouble(json['umidita_terreno']),
      luce: _toDouble(json['luce']),
      tds: _toDouble(json['tds'] ?? json['tds_ppm']),
      tdsRaw: _toInt(json['tds_raw']),
      ph: _toDouble(json['ph']),
      phRaw: _toInt(json['ph_raw']),
      phVoltage: _toDouble(json['ph_voltage']),
      phAdcRange: _toInt(json['ph_adc_range']),
      phStable: _toBool(json['ph_stable']),
      phValid: _toBool(json['ph_valid']),
      phCalibrated: _toBool(json['ph_calibrated']),
      acquaPresente: _toBool(
        json['acqua_presente'] ?? json['livello_acqua_ok'],
      ),
      livelloAcqua: _toDouble(json['livello_acqua']),
      livelloAcquaStato: json['livello_acqua_stato']?.toString(),
      messaggioAcqua: (json['messaggio_acqua'] ?? json['livello_acqua_testo'])
          ?.toString(),
      pompaAttiva: _toBool(json['pompa_attiva'] ?? json['pump_on']),
      secondiPompaOra: _toDouble(
        json['secondi_pompa_ora'] ?? json['current_run_seconds'],
      ),
      irrigazioniOra: _toInt(json['irrigazioni_ora']),
      motivoUltimoArresto:
          (json['motivo_ultimo_arresto'] ?? json['last_stop_reason'])
              ?.toString(),
      bloccoPompa: (json['blocco_pompa'] ?? json['lockout'])?.toString(),
      dailyRuntimeSeconds: _toDouble(json['daily_runtime_seconds']),
      startsToday: _toInt(json['starts_today']),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null || value is bool) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.'));
  }

  static int? _toInt(dynamic value) {
    if (value == null || value is bool) return null;
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value.toString());
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final String text = value?.toString().trim().toLowerCase() ?? '';
    if (<String>{'true', '1', 'yes', 'si', 'sì', 'on'}.contains(text)) {
      return true;
    }
    if (<String>{'false', '0', 'no', 'off'}.contains(text)) {
      return false;
    }
    return null;
  }

  String valore(double? value, {int decimali = 1}) {
    if (value == null) return '–';
    return value.toStringAsFixed(decimali).replaceAll('.', ',');
  }

  String get statoPh {
    if (ph != null && phValid != false) {
      return ph!.toStringAsFixed(2).replaceAll('.', ',');
    }
    if (phCalibrated == false) return 'Non calibrato';
    if (phStable == false) return 'In stabilizzazione';
    if (phValid == false) return 'Non valido';
    return 'Non disponibile';
  }

  String get descrizionePh {
    if (ph != null && phValid != false) {
      if (ph! < 5.5) return 'pH inferiore alla fascia consigliata';
      if (ph! > 6.8) return 'pH superiore alla fascia consigliata';
      return 'Valore pH disponibile';
    }
    if (phCalibrated == false) return 'La sonda pH deve essere calibrata';
    if (phStable == false) {
      return phAdcRange == null
          ? 'Segnale della sonda in stabilizzazione'
          : 'Segnale variabile, intervallo ADC $phAdcRange';
    }
    if (phValid == false) {
      return 'La lettura non supera i controlli di validità';
    }
    return 'Lettura pH non disponibile';
  }

  String get letturaVocalePh {
    if (ph != null && phValid != false) {
      return 'Il pH è ${ph!.toStringAsFixed(2).replaceAll('.', ',')}.';
    }
    if (phCalibrated == false) {
      return 'Il valore del pH non è disponibile perché la sonda non è calibrata.';
    }
    if (phStable == false) {
      return 'Il valore del pH non è ancora disponibile perché il segnale è in stabilizzazione.';
    }
    if (phValid == false) return 'La lettura del pH non è valida.';
    return 'Il valore del pH non è disponibile.';
  }

  String letturaCompleta() {
    final List<String> parti = <String>[];

    if (temperatura != null) {
      parti.add('Temperatura ${valore(temperatura)} gradi Celsius.');
    }
    if (umiditaAria != null) {
      parti.add('Umidità dell’aria ${valore(umiditaAria)} per cento.');
    }
    if (umiditaTerreno != null) {
      parti.add(
        'Umidità del terreno ${valore(umiditaTerreno, decimali: 0)} per cento.',
      );
    }
    if (luce != null) parti.add('Luce ${valore(luce)} lux.');
    if (tds != null) {
      parti.add('T D S ${valore(tds, decimali: 0)} parti per milione.');
    }

    parti.add(letturaVocalePh);

    if (acquaPresente == true) {
      parti.add('Il livello dell’acqua è buono.');
    } else if (acquaPresente == false) {
      parti.add('Il livello dell’acqua è basso. Aggiungere acqua.');
    }

    if (pompaAttiva == true) {
      parti.add('La pompa è accesa.');
    } else if (pompaAttiva == false) {
      parti.add('La pompa è spenta.');
    }

    if (secondiPompaOra != null) {
      parti.add(
        'La pompa ha funzionato per ${valore(secondiPompaOra)} secondi.',
      );
    }
    if (irrigazioniOra != null) {
      parti.add('Cicli di irrigazione: $irrigazioniOra.');
    }
    if (bloccoPompa != null && bloccoPompa!.trim().isNotEmpty) {
      parti.add('Blocco di sicurezza: $bloccoPompa.');
    }

    return parti.join(' ');
  }
}
