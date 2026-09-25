# Configurazione HydroTower App

## Apertura

1. Estrarre completamente la cartella o lo ZIP.
2. Aprire Android Studio.
3. Selezionare Open.
4. Aprire la cartella che contiene pubspec.yaml.
5. Aprire il terminale.
6. Eseguire flutter pub get.

## Backend

L'indirizzo predefinito è configurato in:

lib/config/app_config.dart

Il valore può anche essere cambiato dalla schermata Impostazioni.

Esempio LAN:

http://192.168.1.100:5000

Esempio WireGuard:

http://10.0.0.1:5000

## Firebase

La copia privata può contenere la configurazione Firebase corrente.

Per creare un'installazione indipendente, sostituire:

android/app/google-services.json
lib/firebase_options.dart

usando un nuovo progetto Firebase.

## WireGuard

Il progetto contiene il codice per gestire WireGuard, ma non contiene
profili o chiavi.

Ogni persona deve importare il proprio profilo WireGuard.

## Firma Android

Il progetto non contiene il keystore di produzione.

Per eseguire una build di prova:

flutter build apk --debug

Per pubblicare l'app è necessario creare un proprio keystore.
