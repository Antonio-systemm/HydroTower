import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract final class WireGuardConfigService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _configKey = 'hydrotower_wireguard_config_v1';

  static Future<void> save(String configuration) async {
    final String validated = validate(configuration);
    await _storage.write(key: _configKey, value: validated);
  }

  static Future<String?> read() async {
    final String? value = await _storage.read(key: _configKey);
    final String cleaned = value?.trim() ?? '';
    return cleaned.isEmpty ? null : cleaned;
  }

  static Future<void> delete() async {
    await _storage.delete(key: _configKey);
  }

  static Future<bool> hasConfig() async => await read() != null;

  static String validate(String configuration) {
    final String text = configuration
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    if (text.isEmpty) {
      throw const FormatException('La configurazione WireGuard e vuota.');
    }
    if (text.length > 65536) {
      throw const FormatException(
        'La configurazione WireGuard e troppo grande.',
      );
    }
    if (text.contains('<br') ||
        text.contains('&gt;') ||
        text.contains('&lt;')) {
      throw const FormatException('La configurazione contiene testo HTML.');
    }

    final int interfaces = RegExp(
      r'^\s*\[Interface\]\s*$',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(text).length;
    final int peers = RegExp(
      r'^\s*\[Peer\]\s*$',
      multiLine: true,
      caseSensitive: false,
    ).allMatches(text).length;

    if (interfaces != 1) {
      throw const FormatException('Deve esserci una sola sezione [Interface].');
    }
    if (peers < 1) {
      throw const FormatException('Manca la sezione [Peer].');
    }

    for (final String field in <String>[
      'PrivateKey',
      'Address',
      'PublicKey',
      'Endpoint',
      'AllowedIPs',
    ]) {
      final RegExp expression = RegExp(
        '^\\s*${RegExp.escape(field)}\\s*=\\s*\\S+',
        multiLine: true,
        caseSensitive: false,
      );
      if (!expression.hasMatch(text)) {
        throw FormatException('Campo WireGuard mancante: $field');
      }
    }
    return text;
  }

  static String? addressOf(String configuration) =>
      _extractValue(configuration, 'Address');

  static String? endpointOf(String configuration) =>
      _extractValue(configuration, 'Endpoint');

  static String? allowedIpsOf(String configuration) =>
      _extractValue(configuration, 'AllowedIPs');

  static String? _extractValue(String configuration, String key) {
    final RegExpMatch? match = RegExp(
      '^\\s*${RegExp.escape(key)}\\s*=\\s*([^\\n#]+)',
      multiLine: true,
      caseSensitive: false,
    ).firstMatch(configuration);
    return match?.group(1)?.trim();
  }
}
