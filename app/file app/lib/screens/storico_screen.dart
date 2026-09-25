import 'package:flutter/material.dart';
import '../models/sensor_snapshot.dart';
import '../services/api_service.dart';
import '../theme.dart';

class StoricoScreen extends StatefulWidget {
  const StoricoScreen({super.key});
  @override
  State<StoricoScreen> createState() => _StoricoScreenState();
}

class _StoricoScreenState extends State<StoricoScreen> {
  List<Map<String, dynamic>> righe = [];
  bool loading = true;
  int giorni = 7;
  @override
  void initState() {
    super.initState();
    carica();
  }

  Future<void> carica() async {
    final raw = await ApiService.storico();
    if (!mounted) return;
    setState(() {
      righe = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      loading = false;
    });
  }

  DateTime? dt(dynamic v) =>
      DateTime.tryParse((v?.toString() ?? '').replaceFirst(' ', 'T'));
  List<Map<String, dynamic>> get filtrate => righe.where((r) {
    final d = dt(r['timestamp']);
    return d != null &&
        d.isAfter(DateTime.now().subtract(Duration(days: giorni)));
  }).toList();
  @override
  Widget build(BuildContext c) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final rows = filtrate;
    return RefreshIndicator(
      onRefresh: carica,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(child: Text('Storico', style: sectionTitleStyle())),
              DropdownButton<int>(
                value: giorni,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('Oggi')),
                  DropdownMenuItem(value: 7, child: Text('7 giorni')),
                  DropdownMenuItem(value: 30, child: Text('30 giorni')),
                  DropdownMenuItem(value: 90, child: Text('90 giorni')),
                ],
                onChanged: (v) => setState(() => giorni = v ?? 7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text('Nessun dato disponibile')
          else
            ...rows.map(riga),
        ],
      ),
    );
  }

  Widget riga(Map<String, dynamic> r) {
    final s = SensorSnapshot.fromJson(r);
    return Card(
      child: ExpansionTile(
        title: Text(r['timestamp']?.toString() ?? 'Data non disponibile'),
        subtitle: Text(
          '${s.valore(s.temperatura)} °C, terreno ${s.valore(s.umiditaTerreno)}%, acqua ${s.acquaPresente == true
              ? 'buona'
              : s.acquaPresente == false
              ? 'bassa'
              : 'non disponibile'}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              dato('Temperatura', s.valore(s.temperatura), '°C'),
              dato('Umidità aria', s.valore(s.umiditaAria), '%'),
              dato('Terreno', s.valore(s.umiditaTerreno), '%'),
              dato('Luce', s.valore(s.luce), 'lux'),
              dato('TDS', s.valore(s.tds, decimali: 0), 'ppm'),
              dato('pH', s.valore(s.ph), ''),
              dato(
                'Acqua',
                s.acquaPresente == true
                    ? 'Buono'
                    : s.acquaPresente == false
                    ? 'Basso'
                    : '—',
                '',
              ),
              dato('Pompa', s.pompaAttiva == true ? 'Accesa' : 'Spenta', ''),
              dato(
                'Tempo pompa',
                s.valore(s.secondiPompaOra, decimali: 0),
                's',
              ),
              dato('Irrigazioni', s.irrigazioniOra?.toString() ?? '—', ''),
            ],
          ),
          if (s.motivoUltimoArresto != null)
            ListTile(
              title: const Text('Ultimo arresto'),
              subtitle: Text(s.motivoUltimoArresto!),
            ),
          if (s.bloccoPompa != null)
            ListTile(
              leading: const Icon(Icons.warning_amber),
              title: const Text('Blocco sicurezza'),
              subtitle: Text(s.bloccoPompa!),
            ),
        ],
      ),
    );
  }

  Widget dato(String l, String v, String u) =>
      SizedBox(width: 150, child: Text('$l: $v${u.isEmpty ? '' : ' $u'}'));
}
