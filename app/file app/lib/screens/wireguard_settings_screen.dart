import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/wireguard_config_service.dart';
import '../services/wireguard_service.dart';
import 'wireguard_qr_scanner_screen.dart';

class WireGuardSettingsScreen extends StatefulWidget {
  const WireGuardSettingsScreen({super.key});

  @override
  State<WireGuardSettingsScreen> createState() =>
      _WireGuardSettingsScreenState();
}

class _WireGuardSettingsScreenState extends State<WireGuardSettingsScreen> {
  String? _configuration;
  bool _connected = false;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final String? configuration = await WireGuardConfigService.read();
      final bool connected = await WireGuardService.isConnected();

      if (!mounted) {
        return;
      }

      setState(() {
        _configuration = configuration;
        _connected = connected;
        _busy = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = 'Impossibile leggere la configurazione: $error';
      });
    }
  }

  Future<void> _saveConfiguration(String rawConfiguration) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await WireGuardConfigService.save(rawConfiguration);
      final String? configuration = await WireGuardConfigService.read();

      if (!mounted) {
        return;
      }

      setState(() {
        _configuration = configuration;
      });

      _showMessage('Profilo WireGuard importato.');
    } on FormatException catch (error) {
      if (mounted) {
        setState(() => _error = error.message);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Importazione non riuscita: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _scanQr() async {
    final String? result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const WireGuardQrScannerScreen(),
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      await _saveConfiguration(result);
    }
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['conf'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final PlatformFile selectedFile = result.files.single;
      List<int>? bytes = selectedFile.bytes;

      if (bytes == null && selectedFile.path != null) {
        bytes = await File(selectedFile.path!).readAsBytes();
      }

      if (bytes == null) {
        throw const FileSystemException('Impossibile leggere il file.');
      }

      final String configuration = utf8.decode(bytes, allowMalformed: false);
      await _saveConfiguration(configuration);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Lettura del file non riuscita: $error');
      }
    }
  }

  Future<void> _connect() async {
    final String? configuration = _configuration;
    if (configuration == null) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final bool connected = await WireGuardService.connect(configuration);
      if (!mounted) {
        return;
      }
      setState(() => _connected = connected);
      if (connected) {
        _showMessage('VPN WireGuard collegata.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Connessione VPN non riuscita: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await WireGuardService.disconnect();
      if (!mounted) {
        return;
      }
      setState(() => _connected = false);
      _showMessage('VPN WireGuard scollegata.');
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Disconnessione non riuscita: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _deleteConfiguration() async {
    if (_connected) {
      await _disconnect();
    }
    await WireGuardConfigService.delete();

    if (!mounted) {
      return;
    }

    setState(() {
      _configuration = null;
      _connected = false;
      _error = null;
    });
    _showMessage('Configurazione WireGuard eliminata.');
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String? address = _configuration == null
        ? null
        : WireGuardConfigService.addressOf(_configuration!);
    final String? endpoint = _configuration == null
        ? null
        : WireGuardConfigService.endpointOf(_configuration!);
    final String? allowedIps = _configuration == null
        ? null
        : WireGuardConfigService.allowedIpsOf(_configuration!);

    return Scaffold(
      appBar: AppBar(title: const Text('VPN WireGuard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _connected ? Icons.vpn_lock : Icons.vpn_key_off,
                    ),
                    title: Text(
                      _connected
                          ? 'VPN collegata'
                          : _configuration == null
                          ? 'VPN non configurata'
                          : 'VPN scollegata',
                    ),
                    subtitle: Text(
                      <String>[
                        if (address != null) 'Indirizzo: $address',
                        if (endpoint != null) 'Endpoint: $endpoint',
                        if (allowedIps != null) 'Reti: $allowedIps',
                      ].join('\n'),
                    ),
                  ),
                  if (_busy) ...<Widget>[
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy || _configuration == null
                        ? null
                        : _connected
                        ? _disconnect
                        : _connect,
                    icon: Icon(_connected ? Icons.link_off : Icons.link),
                    label: Text(_connected ? 'Scollega' : 'Collega'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _busy ? null : _scanQr,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scansiona QR'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(Icons.file_open),
            label: const Text('Importa file .conf'),
          ),
          if (_configuration != null) ...<Widget>[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _busy ? null : _deleteConfiguration,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Elimina configurazione'),
            ),
          ],
          const SizedBox(height: 20),
          const Text(
            'Usa un profilo PiVPN diverso per ogni dispositivo. '
            'Il file contiene una chiave privata e non deve essere condiviso.',
          ),
        ],
      ),
    );
  }
}
