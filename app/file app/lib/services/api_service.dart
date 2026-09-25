import 'dart:convert';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _keyServerUrl = 'server_url';
  static const String serverUrl = AppConfig.backendBaseUrl;

  static Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyServerUrl)?.trim();
    return saved != null && saved.isNotEmpty
        ? saved.replaceFirst(RegExp(r'/+$'), '')
        : serverUrl;
  }

  static Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyServerUrl,
      url.trim().replaceFirst(RegExp(r'/+$'), ''),
    );
  }

  static dynamic _decode(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _httpError(
    http.Response response,
    dynamic decoded,
  ) {
    if (decoded is Map) {
      final data = Map<String, dynamic>.from(decoded);
      return <String, dynamic>{
        'ok': false,
        'error':
            data['error']?.toString() ??
            data['details']?.toString() ??
            'Errore HTTP ${response.statusCode}',
        if (data['retryable'] != null) 'retryable': data['retryable'],
      };
    }
    return <String, dynamic>{
      'ok': false,
      'error': 'Risposta non valida dal server (HTTP ${response.statusCode})',
    };
  }

  static Future<Map<String, dynamic>?> sensoriAttuali() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/sensori/attuali'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));
      final decoded = _decode(response);
      return response.statusCode == 200 && decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  static Future<List<dynamic>> storico() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/storico'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final decoded = _decode(response);
      return response.statusCode == 200 && decoded is List
          ? decoded
          : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  static Future<Map<String, dynamic>?> statoAutomazione() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/automazione/stato'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final decoded = _decode(response);
      if (response.statusCode != 200 || decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);
      final state = data['stato'];
      return state is Map ? Map<String, dynamic>.from(state) : data;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> avviaPompa({double secondi = 5}) {
    return _postJson('/api/pompa/avvia', {'seconds': secondi});
  }

  static Future<Map<String, dynamic>> fermaPompa() {
    return _postJson('/api/pompa/ferma', const {});
  }

  static Future<Map<String, dynamic>> resetSicurezzaPompa() {
    return _postJson('/api/pompa/reset-sicurezza', const {});
  }

  static Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final base = await getServerUrl();
      final response = await http
          .post(
            Uri.parse('$base$path'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final decoded = _decode(response);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return _httpError(response, decoded);
    } catch (error) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Connessione al Raspberry Pi non riuscita: $error',
      };
    }
  }

  static Future<Map<String, dynamic>?> impostazioni() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/impostazioni'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final decoded = _decode(response);
      return response.statusCode == 200 && decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> salvaImpostazioni(
    Map<String, dynamic> modifiche,
  ) async {
    final current = await impostazioni() ?? <String, dynamic>{};
    return _postJson('/api/impostazioni', {...current, ...modifiche});
  }

  static Future<Map<String, dynamic>?> analizza(
    Map<String, dynamic> sensori,
    String? fotoBase64,
  ) async {
    try {
      final base = await getServerUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/analizza'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'sensori': sensori,
              if (fotoBase64 != null && fotoBase64.trim().isNotEmpty)
                'foto': fotoBase64,
            }),
          )
          .timeout(const Duration(seconds: 60));
      final decoded = _decode(response);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{'error': 'Risposta non valida dal Raspberry Pi'};
    } catch (error) {
      return <String, dynamic>{
        'error': 'Connessione al Raspberry Pi non riuscita: $error',
      };
    }
  }

  static Future<List<dynamic>> reportDates() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/report/dates'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final decoded = _decode(response);
      return response.statusCode == 200 && decoded is List
          ? decoded
          : <dynamic>[];
    } catch (_) {
      return <dynamic>[];
    }
  }

  static Future<Map<String, dynamic>?> reportDettaglio(String data) async {
    try {
      final base = await getServerUrl();
      final response = await http
          .get(
            Uri.parse('$base/api/report/$data'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 8));
      final decoded = _decode(response);
      return response.statusCode == 200 && decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _normalizeReport(Map<String, dynamic> response) {
    if (response['ok'] != true) {
      return <String, dynamic>{
        'ok': false,
        'error':
            response['error']?.toString() ??
            response['details']?.toString() ??
            'Il report non e stato completato.',
        if (response['retryable'] != null) 'retryable': response['retryable'],
      };
    }

    final rawAnalysis = response['analisi'];
    if (rawAnalysis is! Map) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Il report non contiene il blocco analisi.',
      };
    }

    final analysis = Map<String, dynamic>.from(rawAnalysis);
    final rawSensors = response['sensori'];
    final sensors = rawSensors is Map
        ? Map<String, dynamic>.from(rawSensors)
        : <String, dynamic>{};

    return <String, dynamic>{
      'ok': true,
      ...analysis,
      'analisi': analysis,
      'sensori': sensors,
      'id': response['id'],
      'data': response['data'],
      'creato_il': response['creato_il'],
      'foto': response['foto'],
      'sorgente_foto': response['sorgente_foto'],
      'salvato_database': response['salvato_database'] == true,
      'report_aggiornato': response['report_aggiornato'] == true,
      'aggiornamento_soglie': response['aggiornamento_soglie'],
      'analisi_eliminata': response['analisi_eliminata'],
    };
  }

  static Future<Map<String, dynamic>> avviaRoutineRaspberry() async {
    try {
      final base = await getServerUrl();
      final response = await http
          .post(
            Uri.parse('$base/api/analisi-routine/raspberry'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 120));
      final decoded = _decode(response);
      if (decoded is! Map) {
        return <String, dynamic>{
          'ok': false,
          'error': 'Il Raspberry ha restituito una risposta non valida.',
        };
      }
      final data = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response, data);
      }
      return _normalizeReport(data);
    } catch (error) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Connessione al Raspberry Pi non riuscita: $error',
      };
    }
  }

  static Future<Map<String, dynamic>> avviaRoutineTelefono(
    String percorsoFoto,
  ) async {
    try {
      final base = await getServerUrl();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$base/api/analisi-routine/telefono'),
      );
      request.headers['Accept'] = 'application/json';
      request.files.add(
        await http.MultipartFile.fromPath('foto', percorsoFoto),
      );
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response);
      if (decoded is! Map) {
        return <String, dynamic>{
          'ok': false,
          'error': 'Il Raspberry ha restituito una risposta non valida.',
        };
      }
      final data = Map<String, dynamic>.from(decoded);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _httpError(response, data);
      }
      return _normalizeReport(data);
    } catch (error) {
      return <String, dynamic>{
        'ok': false,
        'error': 'Invio della fotografia non riuscito: $error',
      };
    }
  }

  static Future<Map<String, dynamic>> analizzaConFotocameraRaspberry() {
    return avviaRoutineRaspberry();
  }

  static Future<bool> registraTokenFcm(String token) async {
    final clean = token.trim();
    if (clean.isEmpty || clean.contains(RegExp(r'\s'))) return false;
    final response = await _postJson('/api/notifiche/token', {
      'token': clean,
      'platform': 'android',
    });
    return response['ok'] != false;
  }
}
