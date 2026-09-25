import 'package:flutter/services.dart';

abstract final class WireGuardService {
  static const MethodChannel _channel = MethodChannel('hydrotower/wireguard');

  static Future<bool> connect(String configuration) async {
    try {
      return await _channel.invokeMethod<bool>('connect', <String, Object>{
            'config': configuration,
          }) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> disconnect() async {
    try {
      await _channel.invokeMethod<bool>('disconnect');
    } on PlatformException {
      // Il tunnel potrebbe essere già disconnesso.
    } on MissingPluginException {
      // Flutter potrebbe essere già in fase di chiusura.
    }
  }

  static Future<bool> isConnected() async {
    try {
      return await _channel.invokeMethod<bool>('status') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
