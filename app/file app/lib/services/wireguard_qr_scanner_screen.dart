import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class WireGuardQrScannerScreen extends StatefulWidget {
  const WireGuardQrScannerScreen({super.key});

  @override
  State<WireGuardQrScannerScreen> createState() =>
      _WireGuardQrScannerScreenState();
}

class _WireGuardQrScannerScreenState extends State<WireGuardQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _completed = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_completed) return;

    for (final Barcode barcode in capture.barcodes) {
      final String? value = barcode.rawValue;
      if (value == null || value.trim().isEmpty) continue;

      _completed = true;
      await _controller.stop();
      if (!mounted) return;
      Navigator.of(context).pop<String>(value);
      return;
    }
  }

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scansiona QR WireGuard')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (BarcodeCapture capture) {
          unawaited(_onDetect(capture));
        },
      ),
    );
  }
}
