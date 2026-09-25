import 'package:flutter/material.dart';
import '../services/api_service.dart';

class IrrigazioneScreen extends StatefulWidget {
  const IrrigazioneScreen({super.key});
  @override
  State<IrrigazioneScreen> createState() => _State();
}

class _State extends State<IrrigazioneScreen> {
  Map<String, dynamic>? stato;
  Map<String, dynamic>? settings;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Future.wait([
      ApiService.statoAutomazione(),
      ApiService.impostazioni(),
    ]);
    if (mounted)
      setState(() {
        stato = r[0];
        settings = r[1];
      });
  }

  Future<void> action(Future<Map<String, dynamic>> Function() f) async {
    setState(() => busy = true);
    final r = await f();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(r['error']?.toString() ?? 'Comando inviato')),
      );
      setState(() => busy = false);
      await load();
    }
  }

  @override
  Widget build(BuildContext c) {
    final acqua = stato?['acqua_presente'] == true;
    final pompa = stato?['pump_on'] == true;
    final blocco = stato?['lockout'];
    final enabled = settings?['irrigationEnabled'] == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Stato irrigazione')),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              title: const Text('Irrigazione automatica'),
              subtitle: const Text('Attivare solo dopo il collaudo'),
              value: enabled,
              onChanged: busy
                  ? null
                  : (v) async {
                      await ApiService.salvaImpostazioni({
                        'irrigationEnabled': v,
                      });
                      await load();
                    },
            ),
            ListTile(
              leading: Icon(
                acqua ? Icons.water_drop : Icons.warning,
                color: acqua ? Colors.blue : Colors.red,
              ),
              title: Text(
                acqua ? 'Livello acqua buono' : 'Livello acqua basso',
              ),
              subtitle: Text(stato?['messaggio_acqua']?.toString() ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.water),
              title: Text('Pompa ${pompa ? 'accesa' : 'spenta'}'),
              subtitle: Text(
                blocco == null ? 'Nessun blocco' : 'Blocco: $blocco',
              ),
            ),
            ListTile(
              title: const Text('Irrigazioni oggi'),
              trailing: Text('${stato?['starts_today'] ?? 0}'),
            ),
            ListTile(
              title: const Text('Tempo pompa oggi'),
              trailing: Text('${stato?['daily_runtime_seconds'] ?? 0} s'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy || !acqua
                  ? null
                  : () => action(() => ApiService.avviaPompa(secondi: 5)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Avvia per 5 secondi'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : () => action(ApiService.fermaPompa),
              icon: const Icon(Icons.stop),
              label: const Text('Arresto immediato'),
            ),
            OutlinedButton.icon(
              onPressed: busy || !acqua
                  ? null
                  : () => action(ApiService.resetSicurezzaPompa),
              icon: const Icon(Icons.lock_reset),
              label: const Text('Ripristina blocco sicurezza'),
            ),
          ],
        ),
      ),
    );
  }
}
