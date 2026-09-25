import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_service.dart';

abstract final class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _canaleAllarmi =
      AndroidNotificationChannel(
        'hydrotower_allarmi',
        'Allarmi HydroTower',
        description: 'Notifiche per sensori fuori dalle soglie consigliate.',
        importance: Importance.high,
      );

  static const AndroidNotificationChannel _canaleReport =
      AndroidNotificationChannel(
        'hydrotower_report',
        'Report HydroTower',
        description: 'Notifiche relative ai report giornalieri.',
        importance: Importance.high,
      );

  static StreamSubscription<RemoteMessage>? _messaggiSubscription;
  static StreamSubscription<String>? _tokenSubscription;
  static bool _inizializzato = false;

  static Future<void> inizializza() async {
    if (_inizializzato) return;

    const InitializationSettings impostazioni = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings: impostazioni,
      onDidReceiveNotificationResponse: _notificaSelezionata,
    );

    final AndroidFlutterLocalNotificationsPlugin? android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.createNotificationChannel(_canaleAllarmi);
    await android?.createNotificationChannel(_canaleReport);
    await android?.requestNotificationsPermission();

    final NotificationSettings permesso = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('Permesso notifiche: ${permesso.authorizationStatus}');

    final String? tokenCorrente = await _messaging.getToken();
    if (tokenCorrente != null && tokenCorrente.trim().isNotEmpty) {
      await _registraToken(tokenCorrente);
    } else {
      debugPrint('FCM_TOKEN_NON_DISPONIBILE');
    }

    await _messaggiSubscription?.cancel();
    _messaggiSubscription = FirebaseMessaging.onMessage.listen(
      _gestisciMessaggioInPrimoPiano,
    );

    await _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((String nuovoToken) {
      unawaited(_registraToken(nuovoToken));
    });

    _inizializzato = true;
  }

  static Future<void> _registraToken(String token) async {
    final String tokenPulito = token.trim();
    if (tokenPulito.isEmpty || tokenPulito.contains(RegExp(r'\s'))) {
      debugPrint('TOKEN FCM non valido localmente.');
      return;
    }

    debugPrint('FCM_TOKEN_INIZIO');
    debugPrint(tokenPulito, wrapWidth: 2048);
    debugPrint('FCM_TOKEN_FINE');

    final bool registrato = await ApiService.registraTokenFcm(tokenPulito);
    debugPrint(
      registrato
          ? 'Token FCM registrato sul Raspberry Pi.'
          : 'Registrazione token FCM sul Raspberry Pi fallita.',
    );
  }

  static Future<String?> stampaToken() async {
    final String? tokenFcm = await _messaging.getToken();
    if (tokenFcm == null || tokenFcm.trim().isEmpty) {
      debugPrint('FCM_TOKEN_NON_DISPONIBILE');
      return null;
    }

    final String pulito = tokenFcm.trim();
    debugPrint('FCM_TOKEN_INIZIO');
    debugPrint(pulito, wrapWidth: 2048);
    debugPrint('FCM_TOKEN_FINE');
    return pulito;
  }

  static void _notificaSelezionata(NotificationResponse risposta) {
    debugPrint('Notifica aperta. Payload: ${risposta.payload}');
  }

  static Future<void> _gestisciMessaggioInPrimoPiano(
    RemoteMessage messaggio,
  ) async {
    final RemoteNotification? notifica = messaggio.notification;
    await mostraNotificaLocale(
      id: messaggio.messageId?.hashCode ?? messaggio.hashCode,
      titolo:
          notifica?.title ??
          messaggio.data['title']?.toString() ??
          'HydroTower',
      corpo:
          notifica?.body ??
          messaggio.data['body']?.toString() ??
          'Nuovo aggiornamento disponibile.',
      tipo: messaggio.data['type']?.toString() ?? 'alarm',
    );
  }

  static Future<void> mostraNotificaLocale({
    int? id,
    required String titolo,
    required String corpo,
    String tipo = 'alarm',
  }) async {
    if (!_inizializzato) await inizializza();

    final AndroidNotificationChannel canale = tipo == 'report'
        ? _canaleReport
        : _canaleAllarmi;

    await _localNotifications.show(
      id: id ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: titolo,
      body: corpo,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canale.id,
          canale.name,
          channelDescription: canale.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: tipo,
    );
  }

  static Future<String?> token() => _messaging.getToken();

  static Future<void> dispose() async {
    await _messaggiSubscription?.cancel();
    await _tokenSubscription?.cancel();
    _messaggiSubscription = null;
    _tokenSubscription = null;
    _inizializzato = false;
  }
}
