/// Configurazione globale dell'app.
///
/// Contiene le costanti usate in tutta l'applicazione.
/// Se cambi indirizzo IP del Raspberry Pi, modificalo SOLO qui.
class AppConfig {
  /// URL di base del backend (Raspberry Pi).
  ///
  /// Nota: l'utente può comunque sovrascriverlo a runtime dalla
  /// schermata Impostazioni (viene salvato in SharedPreferences).
  /// Questo valore è solo il default usato al primo avvio.
  static const String backendBaseUrl = 'http://192.168.1.120:5000';
}
