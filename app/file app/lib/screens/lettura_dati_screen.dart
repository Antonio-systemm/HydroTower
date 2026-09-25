import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/tts_service.dart';

/// Schermata di lettura dati: mostra il testo grande, lo legge subito ad
/// alta voce, e offre solo due zone in basso — Rileggi e Torna indietro —
/// come nel disegno originale. Qui basta un tocco singolo: sono azioni
/// sicure (ripetere non fa danni, tornare indietro è sempre reversibile),
/// quindi non serve il doppio tocco di conferma usato altrove.
class LetturaDatiScreen extends StatefulWidget {
  final String testo;
  const LetturaDatiScreen({super.key, required this.testo});

  @override
  State<LetturaDatiScreen> createState() => _LetturaDatiScreenState();
}

class _LetturaDatiScreenState extends State<LetturaDatiScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TtsService.leggi(widget.testo);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    widget.testo,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: HydroColors.text,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => TtsService.leggi(widget.testo),
                    child: Semantics(
                      button: true,
                      label: 'Rileggi',
                      child: Container(
                        color: HydroColors.bg2,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay,
                              size: 32,
                              color: HydroColors.accent,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Rileggi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Semantics(
                      button: true,
                      label: 'Torna indietro',
                      child: Container(
                        color: HydroColors.bg3,
                        padding: const EdgeInsets.all(24),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back,
                              size: 32,
                              color: HydroColors.text2,
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Indietro',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
