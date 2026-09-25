import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';

import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _dati;
  Map<String, dynamic>? _automazione;
  Timer? _timer;
  bool _online = true;
  bool _caricamento = true;
  bool _aggiornamentoInCorso = false;

  @override
  void initState() {
    super.initState();
    unawaited(_carica());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_carica());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carica() async {
    if (_aggiornamentoInCorso) return;
    _aggiornamentoInCorso = true;

    try {
      final List<Map<String, dynamic>?> risultati =
          await Future.wait<Map<String, dynamic>?>(
            <Future<Map<String, dynamic>?>>[
              ApiService.sensoriAttuali(),
              ApiService.statoAutomazione(),
            ],
          );

      if (!mounted) return;

      setState(() {
        if (risultati[0] != null) _dati = risultati[0];
        if (risultati[1] != null) _automazione = risultati[1];
        _online = risultati[0] != null;
        _caricamento = false;
      });
    } finally {
      _aggiornamentoInCorso = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> merged = <String, dynamic>{
      ...?_dati,
      ...?_automazione,
    };
    final SensorSnapshot sensori = SensorSnapshot.fromJson(merged);
    final bool acquaBassa = sensori.acquaPresente == false;
    final bool pompaBloccata =
        sensori.bloccoPompa != null && sensori.bloccoPompa!.trim().isNotEmpty;

    return RefreshIndicator(
      onRefresh: _carica,
      color: HydroColors.accent,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        children: <Widget>[
          if (!_online) ...<Widget>[
            _avvisoOffline(),
            const SizedBox(height: 18),
          ],
          Text('Dashboard', style: sectionTitleStyle()),
          const SizedBox(height: 16),
          if (_caricamento && _dati == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: CircularProgressIndicator(color: HydroColors.accent),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.13,
              children: <Widget>[
                _schedaDato(
                  icon: TablerIcons.thermometer,
                  label: 'Temperatura',
                  value: sensori.valore(sensori.temperatura),
                  unit: '°C',
                ),
                _schedaDato(
                  icon: TablerIcons.droplet,
                  label: 'Umidità aria',
                  value: sensori.valore(sensori.umiditaAria),
                  unit: '%',
                ),
                _schedaDato(
                  icon: TablerIcons.plant,
                  label: 'Terreno',
                  value: sensori.valore(sensori.umiditaTerreno, decimali: 0),
                  unit: '%',
                ),
                _schedaDato(
                  icon: TablerIcons.sun,
                  label: 'Luce',
                  value: sensori.valore(sensori.luce),
                  unit: 'lux',
                ),
                _schedaDato(
                  icon: TablerIcons.flask,
                  label: 'pH',
                  value: sensori.statoPh,
                  subtitle: sensori.descrizionePh,
                  statoPericolo:
                      sensori.phValid == false && sensori.phStable != false,
                  statoAttivo: sensori.ph != null && sensori.phValid != false,
                ),
                _schedaDato(
                  icon: TablerIcons.bolt,
                  label: 'TDS',
                  value: sensori.valore(sensori.tds, decimali: 0),
                  unit: 'ppm',
                ),
                _schedaDato(
                  icon: TablerIcons.droplet,
                  label: 'Livello acqua',
                  value: sensori.acquaPresente == true
                      ? 'Buono'
                      : sensori.acquaPresente == false
                      ? 'Basso'
                      : 'Non disponibile',
                  subtitle: sensori.messaggioAcqua,
                  statoPericolo: acquaBassa,
                ),
                _schedaDato(
                  icon: TablerIcons.settings_automation,
                  label: 'Pompa',
                  value: sensori.pompaAttiva == true ? 'Accesa' : 'Spenta',
                  subtitle:
                      sensori.bloccoPompa ??
                      sensori.motivoUltimoArresto ??
                      (sensori.pompaAttiva == true
                          ? 'Irrigazione in corso'
                          : 'Pompa inattiva'),
                  statoPericolo: pompaBloccata,
                  statoAttivo: sensori.pompaAttiva == true,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _avvisoOffline() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HydroColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HydroColors.danger.withValues(alpha: 0.55)),
      ),
      child: const Row(
        children: <Widget>[
          Icon(TablerIcons.wifi_off, color: HydroColors.danger, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Raspberry Pi non raggiungibile. Controlla la VPN e la connessione.',
              style: TextStyle(color: HydroColors.danger, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _schedaDato({
    required IconData icon,
    required String label,
    required String value,
    String unit = '',
    String? subtitle,
    bool statoPericolo = false,
    bool statoAttivo = false,
  }) {
    final String valoreCompleto = unit.isEmpty ? value : '$value $unit';
    final Color coloreIcona = statoPericolo
        ? HydroColors.danger
        : statoAttivo
        ? HydroColors.accent
        : HydroColors.text2;
    final Color coloreBordo = statoPericolo
        ? HydroColors.danger.withValues(alpha: 0.72)
        : statoAttivo
        ? HydroColors.accent.withValues(alpha: 0.70)
        : HydroColors.border;

    return Semantics(
      label: <String>[
        '$label: $valoreCompleto.',
        if (subtitle != null && subtitle.trim().isNotEmpty) subtitle,
      ].join(' '),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HydroColors.bg2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: coloreBordo, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 25, color: coloreIcona),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statoPericolo
                          ? HydroColors.danger
                          : HydroColors.text2,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valoreCompleto,
                  maxLines: 1,
                  style: const TextStyle(
                    color: HydroColors.text,
                    fontSize: 30,
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
            if (subtitle != null && subtitle.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: statoPericolo
                      ? HydroColors.danger
                      : statoAttivo
                      ? HydroColors.accent
                      : HydroColors.text2,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
