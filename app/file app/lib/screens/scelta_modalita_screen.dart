import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../services/modalita_app_service.dart';
import '../services/tts_service.dart';
import '../theme.dart';

class SceltaModalitaScreen extends StatefulWidget {
  final ValueChanged<ModalitaInterfaccia> onScelto;

  const SceltaModalitaScreen({super.key, required this.onScelto});

  @override
  State<SceltaModalitaScreen> createState() => _SceltaModalitaScreenState();
}

class _SceltaModalitaScreenState extends State<SceltaModalitaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.leggi(
        'Benvenuto in HydroTower. Scegli una modalità. '
        'Normale, semplificata, oppure super semplificata con comandi vocali.',
      );
    });
  }

  Future<void> _scegli(ModalitaInterfaccia modalita) async {
    await ModalitaAppService.imposta(modalita);
    await AppSettings.setOnboardingCompletato(true);
    widget.onScelto(modalita);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HydroColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Scegli l’interfaccia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: HydroColors.text,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Potrai cambiarla in seguito dalle impostazioni.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HydroColors.text2),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _SchedaModalita(
                      icon: Icons.dashboard_outlined,
                      titolo: 'Interfaccia normale',
                      descrizione:
                          'Dashboard completa con menù, calendario, fotografie e controlli tradizionali.',
                      onTap: () => _scegli(ModalitaInterfaccia.normale),
                    ),
                    const SizedBox(height: 12),
                    _SchedaModalita(
                      icon: Icons.accessibility_new,
                      titolo: 'Interfaccia semplificata',
                      descrizione:
                          'Cinque grandi zone, tocco singolo per ascoltare e doppio tocco per confermare.',
                      onTap: () => _scegli(ModalitaInterfaccia.semplificata),
                    ),
                    const SizedBox(height: 12),
                    _SchedaModalita(
                      icon: Icons.record_voice_over,
                      titolo: 'Interfaccia super semplificata',
                      descrizione:
                          'Navigazione con sintesi vocale e riconoscimento di comandi come “Oggi”, “Report” e numeri.',
                      onTap: () =>
                          _scegli(ModalitaInterfaccia.superSemplificata),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedaModalita extends StatelessWidget {
  final IconData icon;
  final String titolo;
  final String descrizione;
  final VoidCallback onTap;

  const _SchedaModalita({
    required this.icon,
    required this.titolo,
    required this.descrizione,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$titolo. $descrizione',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: HydroColors.bg2,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HydroColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 42, color: HydroColors.accent),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      descrizione,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: HydroColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: HydroColors.text2),
            ],
          ),
        ),
      ),
    );
  }
}
