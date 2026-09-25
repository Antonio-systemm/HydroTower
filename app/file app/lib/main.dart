import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/ai_screen.dart';
import 'screens/home_screen.dart';
import 'screens/menu_semplificato_screen.dart';
import 'screens/menu_super_semplificato_screen.dart';
import 'screens/report_screen.dart';
import 'screens/scelta_modalita_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/storico_screen.dart';
import 'screens/wireguard_settings_screen.dart';
import 'services/api_service.dart';
import 'services/app_settings.dart';
import 'services/modalita_app_service.dart';
import 'services/notification_service.dart';
import 'services/wireguard_config_service.dart';
import 'services/wireguard_service.dart';
import 'theme.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Messaggio FCM in background: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await ModalitaAppService.inizializza();
  await NotificationService.inizializza();

  runApp(const HydroTowerApp());
}

class HydroTowerApp extends StatelessWidget {
  const HydroTowerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroTower',
      debugShowCheckedModeBanner: false,
      theme: hydroDarkTheme(),
      home: const AvvioSicuroApp(),
    );
  }
}

class AvvioSicuroApp extends StatefulWidget {
  const AvvioSicuroApp({super.key});

  @override
  State<AvvioSicuroApp> createState() => _AvvioSicuroAppState();
}

class _AvvioSicuroAppState extends State<AvvioSicuroApp>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _hasConfig = false;
  bool _connected = false;
  bool _connecting = false;
  bool _disconnecting = false;
  bool _appInForeground = true;

  String? _error;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeConnection());
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(WireGuardService.disconnect());
    super.dispose();
  }

  Future<void> _initializeConnection() async {
    if (_connecting || _disconnecting || !_appInForeground) {
      return;
    }

    _connecting = true;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final String? configuration = await WireGuardConfigService.read();

      if (!_appInForeground) {
        return;
      }

      if (configuration == null || configuration.trim().isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _hasConfig = false;
          _connected = false;
          _loading = false;
        });
        return;
      }

      bool connected = await WireGuardService.isConnected();

      if (!_appInForeground) {
        return;
      }

      if (!connected) {
        connected = await WireGuardService.connect(configuration);
      }

      if (!mounted || !_appInForeground) {
        if (!_appInForeground && connected) {
          unawaited(WireGuardService.disconnect());
        }
        return;
      }

      setState(() {
        _hasConfig = true;
        _connected = connected;
        _loading = false;

        if (!connected) {
          _error = 'Non è stato possibile attivare la VPN.';
        }
      });

      if (connected) {
        await _registerNotificationToken();
      }
    } catch (error) {
      if (!mounted || !_appInForeground) {
        return;
      }

      setState(() {
        _connected = false;
        _loading = false;
        _error = 'Connessione VPN non riuscita: $error';
      });
    } finally {
      _connecting = false;
    }
  }

  Future<void> _registerNotificationToken() async {
    try {
      final String? token = await NotificationService.token();

      if (token != null && token.trim().isNotEmpty) {
        await ApiService.registraTokenFcm(token.trim());
      }
    } catch (_) {
      // La registrazione FCM non deve bloccare l'app.
    }
  }

  Future<void> _openVpnSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const WireGuardSettingsScreen()),
    );

    if (mounted && _appInForeground) {
      await _initializeConnection();
    }
  }

  Future<void> _disconnect() async {
    if (_disconnecting) {
      return;
    }

    _disconnecting = true;

    try {
      await WireGuardService.disconnect();
    } catch (_) {
      // Il lato Android potrebbe avere già disconnesso il tunnel.
    } finally {
      _disconnecting = false;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _connected = false;
      _loading = false;
    });
  }

  Future<void> _reconnectAfterResume() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted || !_appInForeground) {
      return;
    }

    for (int attempt = 0; attempt < 15 && _disconnecting; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));

      if (!mounted || !_appInForeground) {
        return;
      }
    }

    await _initializeConnection();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _appInForeground = true;
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(milliseconds: 250), () {
          unawaited(_reconnectAfterResume());
        });
        break;

      case AppLifecycleState.inactive:
        // Stato transitorio. La disconnessione viene eseguita
        // quando l'app diventa hidden, paused o detached.
        break;

      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _appInForeground = false;
        _reconnectTimer?.cancel();
        unawaited(_disconnect());
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: HydroColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: HydroColors.accent),
        ),
      );
    }

    if (!_hasConfig) {
      return Scaffold(
        backgroundColor: HydroColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.vpn_key_outlined, size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Configura la connessione sicura',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scansiona il QR PiVPN oppure importa il file .conf. '
                      'Questa operazione viene richiesta una sola volta.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        unawaited(_openVpnSettings());
                      },
                      icon: const Icon(Icons.security_outlined),
                      label: const Text('Configura VPN WireGuard'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (!_connected) {
      return Scaffold(
        backgroundColor: HydroColors.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.vpn_key_off_outlined, size: 60),
                    const SizedBox(height: 20),
                    Text(_error ?? 'VPN non collegata'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        unawaited(_initializeConnection());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Riprova'),
                    ),
                    TextButton(
                      onPressed: () {
                        unawaited(_openVpnSettings());
                      },
                      child: const Text('Gestisci configurazione'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return const AvvioApp();
  }
}

class AvvioApp extends StatefulWidget {
  const AvvioApp({super.key});

  @override
  State<AvvioApp> createState() => _AvvioAppState();
}

class _AvvioAppState extends State<AvvioApp> {
  bool? _onboardingCompleted;
  bool _choiceRunning = false;

  @override
  void initState() {
    super.initState();
    unawaited(_checkOnboarding());
  }

  Future<void> _checkOnboarding() async {
    final bool completed = await AppSettings.getOnboardingCompletato();

    if (!mounted) {
      return;
    }

    setState(() {
      _onboardingCompleted = completed;
    });
  }

  void _onChoice(ModalitaInterfaccia mode) {
    if (_choiceRunning) {
      return;
    }

    _choiceRunning = true;
    unawaited(_saveChoice(mode));
  }

  Future<void> _saveChoice(ModalitaInterfaccia mode) async {
    try {
      await ModalitaAppService.imposta(mode);

      if (mounted) {
        setState(() {
          _onboardingCompleted = true;
        });
      }
    } finally {
      _choiceRunning = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingCompleted == null) {
      return const Scaffold(
        backgroundColor: HydroColors.bg,
        body: Center(
          child: CircularProgressIndicator(color: HydroColors.accent),
        ),
      );
    }

    if (_onboardingCompleted == false) {
      return SceltaModalitaScreen(onScelto: _onChoice);
    }

    return ValueListenableBuilder<ModalitaInterfaccia>(
      valueListenable: ModalitaAppService.modalita,
      builder: (BuildContext context, ModalitaInterfaccia mode, Widget? child) {
        switch (mode) {
          case ModalitaInterfaccia.normale:
            return const RootShell();
          case ModalitaInterfaccia.semplificata:
            return const MenuSemplificatoScreen();
          case ModalitaInterfaccia.superSemplificata:
            return const MenuSuperSemplificatoScreen();
        }
      },
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  static const List<String> _titles = <String>[
    'Oggi',
    'Storico',
    'Analisi AI',
    'Report',
  ];

  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    StoricoScreen(),
    AiScreen(),
    ReportScreen(),
  ];

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('HydroTower · ${_titles[_index]}'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              unawaited(_openSettings());
            },
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (int value) {
          setState(() {
            _index = value;
          });
        },
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Oggi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Storico',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.psychology_outlined),
            label: 'Analisi AI',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
