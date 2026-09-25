import 'package:flutter_tts/flutter_tts.dart';

abstract final class TtsService {
  static final FlutterTts _tts = FlutterTts();

  static Future<void>? _inizializzazione;
  static bool _pronto = false;

  static Future<void> inizializza() {
    if (_pronto) {
      return Future<void>.value();
    }

    return _inizializzazione ??= _configura();
  }

  static Future<void> _configura() async {
    try {
      await _tts.setLanguage('it-IT');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      _pronto = true;
    } catch (_) {
      _pronto = false;
      rethrow;
    } finally {
      _inizializzazione = null;
    }
  }

  static Future<void> leggi(String testo) async {
    final String testoPulito = testo.trim();

    if (testoPulito.isEmpty) {
      return;
    }

    await inizializza();
    await _tts.stop();
    await _tts.speak(testoPulito);
  }

  static Future<void> ferma() async {
    await _tts.stop();
  }

  static Future<void> impostaVelocita(double velocita) async {
    final double valore = velocita.clamp(0.0, 1.0).toDouble();

    await inizializza();
    await _tts.setSpeechRate(valore);
  }

  static Future<void> impostaTono(double tono) async {
    final double valore = tono.clamp(0.5, 2.0).toDouble();

    await inizializza();
    await _tts.setPitch(valore);
  }

  static Future<void> impostaVolume(double volume) async {
    final double valore = volume.clamp(0.0, 1.0).toDouble();

    await inizializza();
    await _tts.setVolume(valore);
  }

  static Future<void> reimposta() async {
    await _tts.stop();
    _pronto = false;
    _inizializzazione = null;
    await inizializza();
  }
}
