import 'dart:async';
import 'package:vibration/vibration.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme.dart';
import 'ai_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'storico_screen.dart';

class SimplifiedScreen extends StatefulWidget {
  const SimplifiedScreen({super.key});

  @override
  State<SimplifiedScreen> createState() => _SimplifiedScreenState();
}

class _SimplifiedScreenState extends State<SimplifiedScreen> {
  Map<String, dynamic>? _dati;
  bool _raggiungibile = true;
  bool _caricamento = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _carica();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carica());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carica() async {
    if (_caricamento) return;
    _caricamento = true;

    try {
      final dati = await ApiService.sensoriAttuali();
      if (!mounted) return;

      setState(() {
        _raggiungibile = dati != null;
        if (dati != null) _dati = dati;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _raggiungibile = false);
      }
    } finally {
      _caricamento = false;
    }
  }

  String _valore(String chiave, {String? alternativa}) {
    final valore =
        _dati?[chiave] ?? (alternativa == null ? null : _dati?[alternativa]);

    if (valore == null) return '–';
    if (valore is num) return valore.toStringAsFixed(1);
    return valore.toString();
  }

  Future<void> _apri(Widget schermata) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => schermata),
    );
    if (mounted) await _carica();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HydroColors.bg,
      appBar: AppBar(
        title: const Text('HydroTower · Semplificata'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _carica,
          child: LayoutBuilder(
            builder: (context, vincoli) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: vincoli.maxHeight - 24,
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SimplifiedButton(
                              label: 'Analisi AI',
                              icon: Icons.psychology_outlined,
                              color: HydroColors.accent,
                              onTap: () => _apri(const AiScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SimplifiedButton(
                              label: 'Report',
                              icon: Icons.menu_book_outlined,
                              color: HydroColors.accent,
                              onTap: () => _apri(const ReportScreen()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HydroColors.bg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: HydroColors.border),
                        ),
                        child: Column(
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  _raggiungibile
                                      ? Icons.cloud_done_outlined
                                      : Icons.wifi_off,
                                  color: _raggiungibile
                                      ? HydroColors.accent
                                      : HydroColors.danger,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _raggiungibile
                                      ? 'Server collegato'
                                      : 'Server non raggiungibile',
                                  style: TextStyle(
                                    color: _raggiungibile
                                        ? HydroColors.accent
                                        : HydroColors.danger,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.thermostat,
                                    label: 'Temperatura',
                                    val: '${_valore('temperatura')} °C',
                                  ),
                                ),
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.water_drop_outlined,
                                    label: 'Umidità aria',
                                    val:
                                        '${_valore('umidita_aria', alternativa: 'umidita')} %',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                              height: 32,
                              color: HydroColors.border,
                            ),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.grass,
                                    label: 'Umidità terreno',
                                    val: '${_valore('umidita_terreno')} %',
                                  ),
                                ),
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.waves,
                                    label: 'Livello acqua',
                                    val: '${_valore('livello_acqua')} %',
                                  ),
                                ),
                              ],
                            ),
                            const Divider(
                              height: 32,
                              color: HydroColors.border,
                            ),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.science_outlined,
                                    label: 'TDS',
                                    val:
                                        '${_valore('tds', alternativa: 'tds_ppm')} ppm',
                                  ),
                                ),
                                Expanded(
                                  child: _BigMetric(
                                    icon: Icons.wb_sunny_outlined,
                                    label: 'Luce',
                                    val: '${_valore('luce')} lux',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _SimplifiedButton(
                              label: 'Storico',
                              icon: Icons.bar_chart_outlined,
                              color: HydroColors.accent,
                              onTap: () => _apri(const StoricoScreen()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _SimplifiedButton(
                              label: 'Impostazioni',
                              icon: Icons.settings_outlined,
                              color: HydroColors.text2,
                              onTap: () => _apri(const SettingsScreen()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SimplifiedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SimplifiedButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  Future<void> _gestisciPressione() async {
    try {
      final bool hasVibrator = await Vibration.hasVibrator();

      if (hasVibrator) {
        final bool hasAmplitudeControl = await Vibration.hasAmplitudeControl();

        if (hasAmplitudeControl) {
          await Vibration.vibrate(
            pattern: <int>[0, 120, 60, 160],
            intensities: <int>[0, 255, 0, 255],
          );
        } else {
          await Vibration.vibrate(duration: 160);
        }
      }
    } catch (_) {
      // La navigazione continua anche se la vibrazione
      // non è disponibile sul dispositivo.
    }

    onTap();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95,
      decoration: BoxDecoration(
        color: HydroColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HydroColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _gestisciPressione,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 34, color: color),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: HydroColors.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String val;

  const _BigMetric({
    required this.icon,
    required this.label,
    required this.val,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, color: HydroColors.accent, size: 28),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: sectionTitleStyle()),
        const SizedBox(height: 4),
        Text(val, textAlign: TextAlign.center, style: metricValueStyle),
      ],
    );
  }
}
